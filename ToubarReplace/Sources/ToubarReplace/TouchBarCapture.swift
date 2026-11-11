import CoreGraphics
import CoreImage
import Foundation
import IOSurface
import MirrorFrameProcessing
import OSLog
import TouchBarPrivateAPI

enum ToubarReplaceAppInfo {
    static var version: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "开发版"
    }
    static let recoveryCommands = """
    defaults delete com.apple.controlstrip FullCustomized
    defaults delete com.apple.controlstrip MiniCustomized
    killall ControlStrip
    """
}

enum TouchBarCaptureError: LocalizedError, Equatable {
    case streamUnavailable
    case streamStartFailed(Int32)
    case streamStopFailed(Int32)
    case invalidSurface
    case controlStripEmpty
    case blackFrame
    case streamStopped
    case streamStartupTimedOut

    var errorDescription: String? {
        switch self {
        case .streamUnavailable:
            return "无法创建 Touch Bar 显示流；当前 macOS 可能已不支持此接口"
        case let .streamStartFailed(code):
            return "Touch Bar 显示流启动失败（错误码 \(code)）"
        case let .streamStopFailed(code):
            return "Touch Bar 显示流停止失败（错误码 \(code)），正在重试…"
        case .invalidSurface:
            return "TouchBarServer 返回了无效画面"
        case .controlStripEmpty:
            return "Control Strip 没有任何按钮；请先在系统设置中恢复默认布局"
        case .blackFrame:
            return "TouchBarServer 只返回黑画面；请重启 ControlStrip 和 TouchBarServer"
        case .streamStopped:
            return "Touch Bar 显示流已中断，正在自动重连…"
        case .streamStartupTimedOut:
            return "Touch Bar 显示流启动后没有返回画面，正在自动重连…"
        }
    }
}

enum TouchBarCaptureNotice: Equatable {
    case contextualContentUnavailable

    var description: String {
        switch self {
        case .contextualContentUnavailable:
            return """
            当前触控栏模式暂时没有可显示的内容
            切换到支持触控栏的 App，或启用一个快速操作后会自动恢复
            """
        }
    }
}

enum TouchBarPresentationPreferences {
    private static let applicationIdentifier =
        "com.apple.touchbar.agent"
    private static let presentationModeKey =
        "PresentationModeGlobal"

    static var currentMode: String? {
        CFPreferencesAppSynchronize(applicationIdentifier as CFString)
        return CFPreferencesCopyAppValue(
            presentationModeKey as CFString,
            applicationIdentifier as CFString
        ) as? String
    }

    static func setCurrentMode(_ mode: String?) {
        guard currentMode != mode else { return }
        if let mode {
            CFPreferencesSetAppValue(
                presentationModeKey as CFString,
                mode as CFString,
                applicationIdentifier as CFString
            )
        } else {
            CFPreferencesSetAppValue(
                presentationModeKey as CFString,
                nil,
                applicationIdentifier as CFString
            )
        }
        CFPreferencesAppSynchronize(applicationIdentifier as CFString)
    }
}

enum TouchBarPresentationModeGuard {
    static let pendingKey = "ToubarReplace.systemPresentationMode.pendingRestore"
    static let savedModeKey = "ToubarReplace.systemPresentationMode.saved"

    static func beginOverride(currentMode: String?, overrideMode: String,
                              defaults: UserDefaults = .standard) -> String? {
        if defaults.bool(forKey: pendingKey), currentMode == overrideMode {
            return defaults.string(forKey: savedModeKey)
        }
        if let currentMode { defaults.set(currentMode, forKey: savedModeKey) }
        else { defaults.removeObject(forKey: savedModeKey) }
        defaults.set(true, forKey: pendingKey)
        return currentMode
    }

    static func endOverride(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: pendingKey)
        defaults.removeObject(forKey: savedModeKey)
    }

    static func restoreAfterUnexpectedExit(overrideMode: String, defaults: UserDefaults = .standard) {
        guard defaults.bool(forKey: pendingKey) else { return }
        if TouchBarPresentationPreferences.currentMode == overrideMode {
            TouchBarPresentationPreferences.setCurrentMode(defaults.string(forKey: savedModeKey))
        }
        endOverride(defaults: defaults)
    }
}

enum TouchBarSystemState {
    private static let contextualPresentationModes: Set<String> = [
        "app",
        "appWithControlStrip",
        "quickActions",
        "quickActionsWithControlStrip",
        "workflows",
        "workflowsWithControlStrip",
    ]

    static func isControlStripExplicitlyEmpty(
        fullCustomized: [Any]?,
        miniCustomized: [Any]?
    ) -> Bool {
        guard let fullCustomized, let miniCustomized else {
            return false
        }
        return fullCustomized.isEmpty && miniCustomized.isEmpty
    }

    static var isControlStripExplicitlyEmpty: Bool {
        let defaults = UserDefaults(suiteName: "com.apple.controlstrip")
        return isControlStripExplicitlyEmpty(
            fullCustomized: defaults?.array(forKey: "FullCustomized"),
            miniCustomized: defaults?.array(forKey: "MiniCustomized")
        )
    }

    static func allowsEmptyContent(presentationMode: String?) -> Bool {
        guard let presentationMode else { return false }
        return contextualPresentationModes.contains(presentationMode)
    }

    static var presentationMode: String? {
        TouchBarPresentationPreferences.currentMode
    }
}





final class TouchBarCapture: @unchecked Sendable {
    typealias FrameHandler = @Sendable (CGImage) -> Void
    typealias NoticeHandler = @Sendable (TouchBarCaptureNotice) -> Void
    typealias ErrorHandler = @Sendable (TouchBarCaptureError) -> Void

    private struct StreamToken: Equatable, Sendable {
        let generation: UInt64
        let identifier: UInt64
        let runIdentifier: UInt64
    }

    private struct ActiveStream: Sendable {
        var token: StreamToken
        let value: any TouchBarDisplayStream
        var isStopping = false
        var isSuspended = false
        var isShuttingDown = false
    }

    private enum SurfaceReadout {
        case blank
        case image(CGImage)
        case needsCoreImage
    }

    private static let minimumBlankFrameCount = 2
    private static let minimumBlankFrameDuration: UInt64 = 500_000_000
    private static let streamStartupTimeout: DispatchTimeInterval = .seconds(5)
    private static let stopConfirmationTimeout: DispatchTimeInterval = .seconds(3)
    private static let bgraPixelFormat: OSType = 0x4247_5241
    private let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
    private static let logger = Logger(
        subsystem: "com.toubarreplace.app",
        category: "TouchBarDisplayStream"
    )

    private let workerQueue: DispatchQueue
    private let dependencies: TouchBarCaptureDependencies
    private var imageContext: CIContext?
    private let onFrame: FrameHandler
    private let onNotice: NoticeHandler
    private let onError: ErrorHandler
    private var stream: ActiveStream?
    private var stopped = true
    private var generation: UInt64 = 0
    private var nextStreamIdentifier: UInt64 = 0
    private var nextRunIdentifier: UInt64 = 0
    private var retryIdentifier: UInt64 = 0
    private var retryScheduled = false
    private var lastError: TouchBarCaptureError?
    private var lastNotice: TouchBarCaptureNotice?
    private var consecutiveBlackFrames = 0
    private var firstBlankFrameAt: UInt64?
    private var hasReceivedStreamActivity = false
    private var hasLoggedFirstFrame = false
    private var keysLuminance = false

    init(
        onFrame: @escaping FrameHandler,
        onNotice: @escaping NoticeHandler,
        onError: @escaping ErrorHandler,
        dependencies: TouchBarCaptureDependencies = .live,
        workerQueue: DispatchQueue = DispatchQueue(
            label: "com.toubarreplace.display-stream",
            qos: .userInteractive,
            autoreleaseFrequency: .workItem
        )
    ) {
        self.onFrame = onFrame
        self.onNotice = onNotice
        self.onError = onError
        self.dependencies = dependencies
        self.workerQueue = workerQueue
    }

    deinit {
        let remainingStream = stream?.value
        workerQueue.async {
            _ = remainingStream?.shutdown()
        }
    }

    func start() {
        workerQueue.async { [weak self] in
            guard let self, self.stopped else { return }
            self.stopped = false
            self.generation &+= 1
            self.cancelRetry()
            self.lastError = nil
            self.lastNotice = nil
            self.startStream(generation: self.generation)
        }
    }

    func stop() {
        workerQueue.async { [weak self] in
            guard let self else { return }
            self.stopped = true
            self.generation &+= 1
            self.cancelRetry()
            self.stopStream()
        }
    }

    func pause() {
        workerQueue.async { [weak self] in
            guard let self else { return }
            self.stopped = true
            self.generation &+= 1
            self.cancelRetry()
            self.stopStream()
        }
    }

    func shutdown() {
        workerQueue.async { [weak self] in
            guard let self else { return }
            self.stopped = true
            self.generation &+= 1
            self.cancelRetry()
            self.stopStream(shuttingDown: true)
        }
    }

    func setLuminanceKeyed(_ enabled: Bool) {
        workerQueue.async { [weak self] in self?.keysLuminance = enabled }
    }

    func restart() {
        workerQueue.async { [weak self] in
            guard let self else { return }
            self.stopped = false
            self.generation &+= 1
            self.cancelRetry()
            self.lastError = nil
            self.lastNotice = nil
            self.stopStream(shuttingDown: true)
            self.startStream(generation: self.generation)
        }
    }

    private func startStream(generation: UInt64) {
        guard !stopped, generation == self.generation else { return }
        if let stream, !stream.isSuspended { return }

        let isResuming = stream != nil
        nextRunIdentifier &+= 1
        if stream == nil {
            nextStreamIdentifier &+= 1
            let identifier = nextStreamIdentifier
            guard let newStream = dependencies.makeStream(
                workerQueue,
                { [weak self] status, surface in
                    self?.handleFrame(status: status, surface: surface, identifier: identifier)
                }
            ) else {
                report(.streamUnavailable)
                scheduleRetry(generation: generation)
                return
            }
            stream = ActiveStream(
                token: StreamToken(generation: generation, identifier: identifier,
                                   runIdentifier: nextRunIdentifier),
                value: newStream
            )
        }
        guard let current = stream else { return }
        let token = StreamToken(generation: generation, identifier: current.token.identifier,
                                runIdentifier: nextRunIdentifier)
        stream?.token = token
        stream?.isSuspended = false
        resetFrameDeliveryState()
        let result = current.value.start()
        guard result == .success else {
            if isResuming { stream?.isSuspended = true }
            else { stream = nil }
            report(.streamStartFailed(result.rawValue))
            scheduleRetry(generation: generation)
            return
        }
        scheduleStartupHealthCheck(token: token)
        debugTrace("display stream started")
    }

    private func handleFrame(
        status: CGDisplayStreamFrameStatus,
        surface: IOSurfaceRef?,
        identifier: UInt64
    ) {
        if status == .stopped {
            handleStoppedStream(identifier: identifier)
            return
        }
        guard acceptsFrames(from: identifier) else { return }

        switch status {
        case .frameComplete:
            hasReceivedStreamActivity = true
            guard let surface else {
                report(.invalidSurface)
                return
            }
            autoreleasepool { process(surface) }

        case .frameBlank:
            hasReceivedStreamActivity = true
            handleBlankFrame()

        case .stopped:
            break

        case .frameIdle:
            hasReceivedStreamActivity = true
            break

        @unknown default:
            break
        }
    }

    private func acceptsFrames(from identifier: UInt64) -> Bool {
        !stopped && stream?.token.identifier == identifier
            && stream?.token.generation == generation
            && stream?.isStopping == false && stream?.isSuspended == false
    }

    private func handleStoppedStream(identifier: UInt64) {
        guard let stream, stream.token.identifier == identifier else { return }
        self.stream = nil
        resetFrameDeliveryState()
        imageContext?.clearCaches()
        debugTrace("display stream stopped")
        guard !stopped else { return }
        if stream.isStopping || stream.isSuspended {
            if !retryScheduled { startStream(generation: generation) }
        } else {
            report(.streamStopped)
            scheduleRetry(generation: generation)
        }
    }

    private func handleBlankFrame() {
        let timestamp = DispatchTime.now().uptimeNanoseconds
        consecutiveBlackFrames += 1
        if firstBlankFrameAt == nil {
            firstBlankFrameAt = timestamp
        }
        guard
            consecutiveBlackFrames >= Self.minimumBlankFrameCount,
            let firstBlankFrameAt,
            timestamp - firstBlankFrameAt >= Self.minimumBlankFrameDuration
        else {
            return
        }

        if TouchBarSystemState.allowsEmptyContent(
            presentationMode: TouchBarSystemState.presentationMode
        ) {
            reportNotice(.contextualContentUnavailable)
            return
        }

        report(
            TouchBarSystemState.isControlStripExplicitlyEmpty
                ? .controlStripEmpty
                : .blackFrame
        )
    }

    private func process(_ surface: IOSurfaceRef) {
        let image: CGImage
        switch readSurface(surface) {
        case .blank:
            handleBlankFrame()
            return
        case let .image(copied):
            image = copied
        case .needsCoreImage:
            guard let converted = makeImageWithCoreImage(from: surface) else {
                consecutiveBlackFrames = 0
                firstBlankFrameAt = nil
                report(.invalidSurface)
                return
            }
            image = converted
        }
        consecutiveBlackFrames = 0
        firstBlankFrameAt = nil
        deliver(image)
    }

    private func deliver(_ image: CGImage) {
        lastError = nil
        lastNotice = nil
        onFrame(image)
        if !hasLoggedFirstFrame {
            hasLoggedFirstFrame = true
            Self.logger.info(
                "Received Touch Bar frame: \(image.width)x\(image.height)"
            )
            debugTrace(
                "received Touch Bar frame \(image.width)x\(image.height)"
            )
        }
    }

    private func readSurface(_ surface: IOSurfaceRef) -> SurfaceReadout {
        var seed: UInt32 = 0
        guard IOSurfaceLock(surface, .readOnly, &seed) == kIOReturnSuccess else {
            return .needsCoreImage
        }
        defer { IOSurfaceUnlock(surface, .readOnly, &seed) }

        let width = IOSurfaceGetWidth(surface)
        let height = IOSurfaceGetHeight(surface)
        guard width > 0, height > 0 else { return .needsCoreImage }
        let baseAddress = IOSurfaceGetBaseAddress(surface)
        let bytesPerRow = IOSurfaceGetBytesPerRow(surface)
        let bytesPerElement = max(IOSurfaceGetBytesPerElement(surface), 1)
        if Self.isNearlyBlack(baseAddress, width: width, height: height,
                              bytesPerRow: bytesPerRow, bytesPerElement: bytesPerElement) {
            return .blank
        }
        guard IOSurfaceGetPixelFormat(surface) == Self.bgraPixelFormat, bytesPerElement == 4,
              let image = makeImageByCopying(baseAddress, width: width, height: height,
                                             bytesPerRow: bytesPerRow) else {
            return .needsCoreImage
        }
        return .image(image)
    }

    private func makeImageByCopying(
        _ baseAddress: UnsafeMutableRawPointer, width: Int, height: Int, bytesPerRow: Int
    ) -> CGImage? {
        let rowBytes = width * 4
        let size = rowBytes * height
        guard bytesPerRow >= rowBytes, let buffer = malloc(size) else { return nil }
        if bytesPerRow == rowBytes {
            memcpy(buffer, baseAddress, size)
        } else {
            for row in 0..<height {
                memcpy(buffer + row * rowBytes, baseAddress + row * bytesPerRow, rowBytes)
            }
        }
        let keyed = keysLuminance
        if keyed {
            TBRMirrorFrameApplyLuminanceAlpha(buffer.assumingMemoryBound(to: UInt8.self), width, height, rowBytes)
        }
        guard let provider = CGDataProvider(
            dataInfo: nil, data: buffer, size: size,
            releaseData: { _, data, _ in free(UnsafeMutableRawPointer(mutating: data)) }
        ) else {
            free(buffer)
            return nil
        }
        let alpha: CGImageAlphaInfo = keyed ? .premultipliedFirst : .noneSkipFirst
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: rowBytes, space: sRGB,
            bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | alpha.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent
        )
    }

    private func makeImageWithCoreImage(from surface: IOSurfaceRef) -> CGImage? {
        let image = CIImage(ioSurface: surface)
        guard !image.extent.isEmpty, !image.extent.isInfinite else {
            return nil
        }
        let context: CIContext
        if let imageContext { context = imageContext }
        else {
            context = CIContext(options: [.cacheIntermediates: false])
            imageContext = context
        }
        guard let converted = context.createCGImage(image, from: image.extent) else { return nil }
        guard keysLuminance else { return converted }
        return MirrorSmokeFrameKeyer.keyed(converted) ?? converted
    }

    private static func isNearlyBlack(
        _ baseAddress: UnsafeMutableRawPointer, width: Int, height: Int,
        bytesPerRow: Int, bytesPerElement: Int
    ) -> Bool {
        let colorBytes = min(bytesPerElement, 3)
        let bytes = baseAddress.assumingMemoryBound(to: UInt8.self)
        let horizontalStep = max(width / 160, 1)
        let verticalStep = max(height / 8, 1)
        var visibleSamples = 0

        for y in stride(from: 0, to: height, by: verticalStep) {
            for x in stride(from: 0, to: width, by: horizontalStep) {
                let pixelOffset = y * bytesPerRow + x * bytesPerElement
                var brightest: UInt8 = 0
                for channel in 0..<colorBytes {
                    brightest = max(brightest, bytes[pixelOffset + channel])
                }
                if brightest > 32 {
                    visibleSamples += 1
                    if visibleSamples >= 2 {
                        return false
                    }
                }
            }
        }
        return true
    }

    private func stopStream(shuttingDown: Bool = false) {
        if shuttingDown { stream?.isShuttingDown = true }
        if let stream, !stream.isStopping, !stream.isSuspended || shuttingDown {
            self.stream?.isStopping = true
            self.stream?.isSuspended = false
            requestStreamStop(token: stream.token)
        }
        resetFrameDeliveryState()


    }

    private func requestStreamStop(token: StreamToken) {
        guard let stream, stream.token == token, stream.isStopping else { return }
        let result = stream.isShuttingDown ? stream.value.shutdown() : stream.value.stop()
        guard self.stream?.token == token else { return }
        if result == .success {
            if !stream.isShuttingDown, stream.value.stopBehavior == .retainForReuse {
                imageContext?.clearCaches()
                self.stream?.isStopping = false
                self.stream?.isSuspended = true
                if !stopped, !retryScheduled { startStream(generation: generation) }
                return
            }
            scheduleStopConfirmationTimeout(token: token)
            return
        }
        report(.streamStopFailed(result.rawValue))
        dependencies.schedule(workerQueue, .seconds(1)) { [weak self] in
            self?.requestStreamStop(token: token)
        }
    }

    private func scheduleStopConfirmationTimeout(token: StreamToken) {
        dependencies.schedule(workerQueue, Self.stopConfirmationTimeout) { [weak self] in
            guard let self, let stream = self.stream, stream.token == token, stream.isStopping else { return }
            Self.logger.error("Touch Bar display stream did not confirm stop; replacing it")
            self.debugTrace("display stream stop unconfirmed; abandoning")
            stream.value.abandon()
            self.handleStoppedStream(identifier: token.identifier)
        }
    }

    private func resetFrameDeliveryState() {
        consecutiveBlackFrames = 0
        firstBlankFrameAt = nil
        hasReceivedStreamActivity = false
    }

    private func scheduleRetry(generation: UInt64) {
        guard !stopped, generation == self.generation, !retryScheduled else { return }
        retryIdentifier &+= 1
        let identifier = retryIdentifier
        retryScheduled = true
        dependencies.schedule(workerQueue, .seconds(1)) { [weak self] in
            guard let self, !self.stopped, generation == self.generation,
                  self.retryScheduled, identifier == self.retryIdentifier else { return }
            self.retryScheduled = false
            self.startStream(generation: generation)
        }
    }

    private func cancelRetry() {
        retryIdentifier &+= 1
        retryScheduled = false
    }

    private func scheduleStartupHealthCheck(token: StreamToken) {
        dependencies.schedule(workerQueue, Self.streamStartupTimeout) { [weak self] in
            guard
                let self,
                self.stream?.token == token,
                self.acceptsFrames(from: token.identifier),
                !self.hasReceivedStreamActivity
            else {
                return
            }
            self.report(.streamStartupTimedOut)
            self.scheduleRetry(generation: self.generation)
            self.stopStream(shuttingDown: true)
        }
    }

    private func report(_ error: TouchBarCaptureError) {
        guard lastError != error else { return }
        lastError = error
        lastNotice = nil
        Self.logger.error("\(error.localizedDescription, privacy: .public)")
        debugTrace("error: \(error.localizedDescription)")
        onError(error)
    }

    private func reportNotice(_ notice: TouchBarCaptureNotice) {
        guard lastNotice != notice else { return }
        lastNotice = notice
        lastError = nil
        Self.logger.info("\(notice.description, privacy: .public)")
        debugTrace("notice: \(notice.description)")
        onNotice(notice)
    }

    private func debugTrace(_ message: String) {
        #if DEBUG
        FileHandle.standardError.write(
            Data("[ToubarReplace] \(message)\n".utf8)
        )
        #endif
    }
}
