import AppKit
import CoreGraphics
import Foundation

struct TouchBarWindowMetrics {
    static let defaultSize = CGSize(width: 1_150, height: 35)
    static let minimumSize = CGSize(width: 240, height: 18)

    static func pointSize(
        forPixelSize pixelSize: CGSize,
        backingScaleFactor: CGFloat
    ) -> CGSize {
        let scale = max(backingScaleFactor, 1)
        return CGSize(
            width: pixelSize.width / scale,
            height: pixelSize.height / scale
        )
    }

    static func pixelSize(
        forPointSize pointSize: CGSize,
        backingScaleFactor: CGFloat
    ) -> CGSize {
        let scale = max(backingScaleFactor, 1)
        return CGSize(
            width: (pointSize.width * scale).rounded(),
            height: (pointSize.height * scale).rounded()
        )
    }


    static func rootSize(forMirrorSize mirrorSize: CGSize) -> CGSize {
        CGSize(
            width: max(mirrorSize.width, 1),
            height: max(mirrorSize.height, 1)
        )
    }
}


enum TouchBarHoverOpacity {
    static let normal: CGFloat = 1
    static let hovered: CGFloat = 0.3

    static func targetAlpha(isMouseInside: Bool) -> CGFloat {
        isMouseInside ? hovered : normal
    }

    static func isMouseInside(
        windowFrame: CGRect,
        mouseLocation: CGPoint
    ) -> Bool {
        windowFrame.contains(mouseLocation)
    }
}



enum MirrorSceneTransition {

    static let settleDuration: Duration = .milliseconds(221)

    static let fadeDuration: TimeInterval = 0.12
}

enum WorkspaceAsyncSessionPolicy {
    static func canUpdate(
        capturedGeneration: UInt64,
        currentGeneration: UInt64,
        scene: BarScene
    ) -> Bool {
        capturedGeneration == currentGeneration && scene == .workspace
    }
}

@MainActor
final class TouchBarHoverOpacityController {
    private static let mouseEventMask: NSEvent.EventTypeMask = [
        .mouseMoved,
        .leftMouseDragged,
        .rightMouseDragged,
        .otherMouseDragged,
        .leftMouseDown,
        .leftMouseUp,
    ]

    private weak var window: NSWindow?
    private var localMonitor: Any?
    private var globalMonitor: Any?

    init(window: NSWindow) {
        self.window = window
    }

    func start() {
        installMonitorsIfNeeded()
        refresh()
    }

    func stop() {
        removeMonitors()
        apply(TouchBarHoverOpacity.normal)
    }

    func refresh() {
        guard let window, window.isVisible else {
            apply(TouchBarHoverOpacity.normal)
            return
        }
        let inside = TouchBarHoverOpacity.isMouseInside(
            windowFrame: window.frame,
            mouseLocation: NSEvent.mouseLocation
        )
        apply(TouchBarHoverOpacity.targetAlpha(isMouseInside: inside))
    }

    private func installMonitorsIfNeeded() {
        guard localMonitor == nil, globalMonitor == nil else { return }
        localMonitor = NSEvent.addLocalMonitorForEvents(
            matching: Self.mouseEventMask
        ) { [weak self] event in
            self?.refresh()
            return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: Self.mouseEventMask
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    private func removeMonitors() {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
    }

    private func apply(_ alpha: CGFloat) {
        guard let window else { return }
        if window.alphaValue != alpha {
            window.alphaValue = alpha
        }
    }
}



final class TouchBarFrameDeliveryCoalescer: @unchecked Sendable {
    private let lock = NSLock()
    private let onFrame: @MainActor @Sendable (CGImage) -> Void
    private var latestImage: CGImage?
    private var isDeliveryScheduled = false

    @MainActor
    init(onFrame: @escaping @MainActor @Sendable (CGImage) -> Void) {
        self.onFrame = onFrame
    }

    func submit(_ image: CGImage) {
        lock.lock()
        latestImage = image
        guard !isDeliveryScheduled else {
            lock.unlock()
            return
        }
        isDeliveryScheduled = true
        lock.unlock()

        Task { @MainActor [weak self] in
            self?.deliverLatest()
        }
    }

    @MainActor
    private func deliverLatest() {
        lock.lock()
        let image = latestImage
        latestImage = nil
        isDeliveryScheduled = false
        lock.unlock()

        guard let image else { return }
        onFrame(image)
    }
}

@MainActor
final class TouchBarSurfaceView: NSView {
    private let statusLabel: NSTextField
    private let imageView: NSView

    override init(frame frameRect: NSRect) {
        statusLabel = NSTextField(labelWithString: "正在读取 Touch Bar…")
        imageView = NSView(frame: .zero)
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        imageView.wantsLayer = true
        imageView.layer?.contentsGravity = .resizeAspect
        addSubview(imageView)

        statusLabel.textColor = .white
        statusLabel.alignment = .center
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        statusLabel.maximumNumberOfLines = 0
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.wantsLayer = true
        statusLabel.layer?.zPosition = 1
        addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func display(image: CGImage) {
        imageView.layer?.contents = image
        imageView.isHidden = false
        statusLabel.isHidden = true
    }


    var currentFrameContents: Any? {
        imageView.layer?.contents
    }

    func display(notice: TouchBarCaptureNotice) {
        statusLabel.font = .systemFont(ofSize: 10, weight: .medium)
        statusLabel.stringValue = notice.description
        statusLabel.toolTip = notice.description
        statusLabel.isHidden = false
        addSubview(statusLabel, positioned: .above, relativeTo: imageView)
    }

    func display(error: TouchBarCaptureError) {
        statusLabel.font = .systemFont(ofSize: 8, weight: .medium)
        statusLabel.stringValue = """
        \(error.localizedDescription)

        恢复命令（终端）：
        \(ToubarReplaceAppInfo.recoveryCommands)
        """
        statusLabel.toolTip = statusLabel.stringValue
        statusLabel.isHidden = false
        addSubview(statusLabel, positioned: .above, relativeTo: imageView)
    }


    func displaySoftwareWorkspaceIdle() {
        imageView.layer?.contents = nil
        imageView.isHidden = true
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.stringValue = """
        当前 Mac 无物理 Touch Bar
        点击切换按钮打开 Workspace，查看额度并启动应用
        """
        statusLabel.toolTip = statusLabel.stringValue
        statusLabel.isHidden = false
        addSubview(statusLabel, positioned: .above, relativeTo: imageView)
    }
}

@MainActor
final class TouchBarWindowController: NSWindowController, NSWindowDelegate {
    private let rootView: TouchBarRootView
    private let capture: TouchBarCapture
    private let hoverOpacityController: TouchBarHoverOpacityController
    private let quotaStore = QuotaSnapshotStore()
    private let workspaceTouchBarController = WorkspaceTouchBarController()
    private let switcherTouchBarController = SwitcherTouchBarController()
    private var workspaceSwitcherWindowController:
        WorkspaceSwitcherWindowController?

    private var hasRestoredFrame = false
    private var workspaceObservers: [NSObjectProtocol] = []
    private var resumeToWorkspace = false


    private var isHardwareSessionPaused = false
    private var isRunning = false
    private var workspaceGeneration: UInt64 = 0
    private var quotaRefreshTask: Task<Void, Never>?


    private var forceFloatingSwitcher = false
    private(set) var displayPosition = TouchBarPreferences.displayPosition
    var onPixelSizeChanged: ((CGSize) -> Void)?
    var onCustomTopLeftChanged: ((CGPoint) -> Void)?

    var onOpenSettings: (() -> Void)?

    var onQuotaProvidersChanged: (() -> Void)?

    init() {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let initialMirrorSize = TouchBarWindowMetrics.pointSize(
            forPixelSize: TouchBarPreferences.mirrorPixelSize,
            backingScaleFactor: scale
        )

        let initialRootSize = TouchBarWindowMetrics.rootSize(
            forMirrorSize: initialMirrorSize
        )
        rootView = TouchBarRootView(
            frame: NSRect(origin: .zero, size: initialRootSize)
        )

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialRootSize),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .black
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false


        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true
        panel.acceptsMouseMovedEvents = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.minSize = TouchBarWindowMetrics.rootSize(
            forMirrorSize: TouchBarWindowMetrics.minimumSize
        )
        panel.animationBehavior = .none
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.contentView = rootView

        panel.setFrameAutosaveName(TouchBarPreferences.mirrorWindowAutosaveName)
        var restoredFrame = false
        if TouchBarPreferences.displayPosition.restoresAutosavedFrame {
            restoredFrame = panel.setFrameUsingName(
                TouchBarPreferences.mirrorWindowAutosaveName
            )
        }
        panel.setContentSize(initialRootSize)

        hoverOpacityController = TouchBarHoverOpacityController(window: panel)
        let frameDelivery = TouchBarFrameDeliveryCoalescer {
            [weak rootView] image in
            rootView?.surfaceView.display(image: image)
        }
        capture = TouchBarCapture(
            onFrame: { image in
                frameDelivery.submit(image)
            },
            onNotice: { [weak rootView] notice in
                Task { @MainActor in
                    rootView?.surfaceView.display(notice: notice)
                }
            },
            onError: { [weak rootView] error in
                Task { @MainActor in
                    rootView?.surfaceView.display(error: error)
                }
            }
        )

        super.init(window: panel)
        hasRestoredFrame = restoredFrame
        panel.delegate = self
        installWorkspaceActions()
        configureFloatingWorkspaceSwitcher()
        installWorkspaceObservers()
        persistCurrentPixelSize()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start() {
        isRunning = true

        if !(displayPosition.restoresAutosavedFrame && hasRestoredFrame) {
            positionWindow()
        }
        window?.orderFrontRegardless()
        configureFloatingWorkspaceSwitcher()
        showFloatingWorkspaceSwitcherIfNeeded()
        hoverOpacityController.start()

        let enterWorkspace =
            SoftwareWorkspaceLaunchPolicy.shouldEnterWorkspaceAtLaunch(
                usesSoftwareWorkspace: usesSoftwareWorkspace,
                preferredScene: WorkspacePreferences.startupScene
            )
        if SoftwareWorkspaceLaunchPolicy.shouldStartHardwareCapture(
            usesSoftwareWorkspace: usesSoftwareWorkspace
        ) {
            capture.start()
        }
        if enterWorkspace {
            if usesSoftwareWorkspace {
                enterSoftwareWorkspace(isLaunch: true)
            } else {
                enterHardwareWorkspace(isLaunch: true)
            }
        } else {
            if usesSoftwareWorkspace {
                rootView.surfaceView.displaySoftwareWorkspaceIdle()
            }
            presentPhysicalSwitcherIfNeeded()
            updateMirrorClickThrough()
        }
        hoverOpacityController.refresh()
        configureFloatingWorkspaceSwitcher()
        showFloatingWorkspaceSwitcherIfNeeded()
    }

    func stop() {
        isRunning = false
        cancelWorkspaceAsyncWork(invalidateSession: true)
        workspaceTouchBarController.dismiss()
        switcherTouchBarController.dismiss()
        workspaceSwitcherWindowController?.window?.orderOut(nil)
        hoverOpacityController.stop()
        capture.stop()
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(center.removeObserver)
        workspaceObservers.removeAll()
    }

    func setDisplayPosition(_ position: TouchBarDisplayPosition) {
        displayPosition = position
        TouchBarPreferences.displayPosition = position
        if position.restoresAutosavedFrame, let window {
            let restored = window.setFrameUsingName(
                TouchBarPreferences.mirrorWindowAutosaveName
            )
            hasRestoredFrame = restored
            if restored {
                let scale = window.screen?.backingScaleFactor
                    ?? NSScreen.main?.backingScaleFactor
                    ?? 2
                let mirrorPointSize = TouchBarWindowMetrics.pointSize(
                    forPixelSize: TouchBarPreferences.mirrorPixelSize,
                    backingScaleFactor: scale
                )
                window.setContentSize(
                    TouchBarWindowMetrics.rootSize(
                        forMirrorSize: mirrorPointSize
                    )
                )
                return
            }
        } else {
            hasRestoredFrame = false
        }
        positionWindow()
    }


    var customTopLeft: CGPoint {
        guard let window else {
            return TouchBarPreferences.hasCustomTopLeft
                ? TouchBarPreferences.customTopLeft
                : defaultCustomTopLeftFallback()
        }
        return CGPoint(x: window.frame.minX, y: window.frame.maxY)
    }

    func setCustomTopLeft(_ topLeft: CGPoint) {
        TouchBarPreferences.customTopLeft = topLeft
        onCustomTopLeftChanged?(topLeft)
        if displayPosition.usesCustomTopLeft {
            positionWindow()
        }
    }


    func suppressPhysicalSwitcherCloseBox() {
        switcherTouchBarController.suppressCloseBox()
    }


    func ensurePhysicalSwitcherPresented() {
        presentPhysicalSwitcherIfNeeded()
        suppressPhysicalSwitcherCloseBox()
    }

    var mirrorPixelSize: CGSize {
        guard let window else {
            return TouchBarPreferences.mirrorPixelSize
        }
        return TouchBarWindowMetrics.pixelSize(
            forPointSize: rootView.mirrorViewportSize,
            backingScaleFactor: window.screen?.backingScaleFactor
                ?? NSScreen.main?.backingScaleFactor
                ?? 2
        )
    }

    func setMirrorPixelSize(_ pixelSize: CGSize) {
        guard let window else { return }
        let constrainedPixelSize = CGSize(
            width: max(pixelSize.width.rounded(), 1),
            height: max(pixelSize.height.rounded(), 1)
        )
        let mirrorPointSize = TouchBarWindowMetrics.pointSize(
            forPixelSize: constrainedPixelSize,
            backingScaleFactor: window.screen?.backingScaleFactor
                ?? NSScreen.main?.backingScaleFactor
                ?? 2
        )
        let mirrorOriginX = currentMirrorOriginX
        window.setContentSize(
            TouchBarWindowMetrics.rootSize(forMirrorSize: mirrorPointSize)
        )
        setWindowOriginPreservingMirrorX(mirrorOriginX)
        persistCurrentPixelSize()
    }

    var workspaceSwitcherFloats: Bool {
        WorkspacePreferences.floatingSwitcher
    }

    var workspaceSwitcherDisplayMode: WorkspaceSwitcherDisplayMode {
        WorkspacePreferences.switcherDisplayMode
    }

    func setWorkspaceSwitcherFloats(_ floats: Bool) {
        setWorkspaceSwitcherDisplayMode(floats ? .floating : .touchBar)
    }

    func setWorkspaceSwitcherDisplayMode(_ mode: WorkspaceSwitcherDisplayMode) {


        let modeToStore: WorkspaceSwitcherDisplayMode
        if usesSoftwareWorkspace {
            modeToStore = .floating
        } else {
            modeToStore = mode
        }
        if modeToStore != WorkspacePreferences.switcherDisplayMode {
            WorkspacePreferences.switcherDisplayMode = modeToStore
        }
        configureFloatingWorkspaceSwitcher()
        showFloatingWorkspaceSwitcherIfNeeded()
        if effectiveSwitcherDisplayMode == .floating {
            switcherTouchBarController.dismiss()
        } else {
            presentPhysicalSwitcherIfNeeded()
        }
        persistCurrentPixelSize()
    }

    var workspaceStartupScene: WorkspaceStartupScene {
        WorkspacePreferences.startupScene
    }

    func setWorkspaceStartupScene(_ scene: WorkspaceStartupScene) {
        WorkspacePreferences.startupScene = scene
    }

    func windowDidResize(_ notification: Notification) {
        persistCurrentPixelSize()
        hoverOpacityController.refresh()
    }

    func windowDidMove(_ notification: Notification) {
        hoverOpacityController.refresh()
    }

    func windowDidChangeScreen(_ notification: Notification) {
        persistCurrentPixelSize()
        hoverOpacityController.refresh()
    }

    func windowDidChangeOcclusionState(_ notification: Notification) {
        hoverOpacityController.refresh()
    }

    func positionWindow() {
        guard let window else { return }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        let frame = window.frame
        let mirrorSize = rootView.mirrorViewportSize
        let mirrorX = visibleFrame.midX - mirrorSize.width / 2
        let origin: NSPoint
        switch displayPosition {
        case .bottom:
            origin = NSPoint(x: mirrorX, y: screen.frame.minY)
        case .top:
            origin = NSPoint(
                x: mirrorX,
                y: visibleFrame.maxY - frame.height - 18
            )
        case .center:
            origin = NSPoint(
                x: mirrorX,
                y: visibleFrame.midY - frame.height / 2
            )
        case .lastSaved:

            origin = NSPoint(x: mirrorX, y: screen.frame.minY)
        case .custom:
            let topLeft: CGPoint
            if TouchBarPreferences.hasCustomTopLeft {
                topLeft = TouchBarPreferences.customTopLeft
            } else {
                topLeft = CGPoint(
                    x: mirrorX,
                    y: screen.frame.minY + frame.height
                )
                TouchBarPreferences.customTopLeft = topLeft
                onCustomTopLeftChanged?(topLeft)
            }

            origin = NSPoint(x: topLeft.x, y: topLeft.y - frame.height)
        }
        window.setFrameOrigin(origin)
    }

    private func defaultCustomTopLeftFallback() -> CGPoint {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let visibleFrame = screen?.visibleFrame ?? .zero
        let scale = screen?.backingScaleFactor ?? 2
        let mirrorPointSize = TouchBarWindowMetrics.pointSize(
            forPixelSize: TouchBarPreferences.mirrorPixelSize,
            backingScaleFactor: scale
        )
        let rootSize = TouchBarWindowMetrics.rootSize(
            forMirrorSize: mirrorPointSize
        )
        let mirrorX = visibleFrame.midX - mirrorPointSize.width / 2
        let bottomY = screen?.frame.minY ?? 0
        return CGPoint(x: mirrorX, y: bottomY + rootSize.height)
    }

    private func persistCurrentPixelSize() {
        let pixelSize = mirrorPixelSize
        TouchBarPreferences.mirrorPixelSize = pixelSize
        onPixelSizeChanged?(pixelSize)
    }

    private var currentMirrorOriginX: CGFloat {
        guard let window else { return 0 }
        return window.frame.minX
    }

    private func setWindowOriginPreservingMirrorX(_ mirrorOriginX: CGFloat) {
        guard let window else { return }
        var origin = window.frame.origin
        origin.x = mirrorOriginX
        window.setFrameOrigin(origin)
    }

    private func installWorkspaceActions() {
        rootView.workspaceView.onToggleWorkspace = { [weak self] in
            self?.toggleWorkspace()
        }
        rootView.workspaceView.onOpenSettings = { [weak self] in
            self?.onOpenSettings?()
        }
        rootView.workspaceView.onOpenCustomApp = { [weak self] app in
            self?.openCustomWorkspaceApp(app)
        }
        workspaceTouchBarController.onOpenSettings = { [weak self] in
            self?.onOpenSettings?()
        }
        workspaceTouchBarController.onOpenCustomApp = { [weak self] app in
            self?.openCustomWorkspaceApp(app)
        }
        workspaceTouchBarController.onPresentationInterrupted = { [weak self] in
            self?.handleWorkspacePresentationInterrupted()
        }
        workspaceTouchBarController.onToggleWorkspace = { [weak self] in
            self?.toggleWorkspace()
        }
        switcherTouchBarController.onToggleWorkspace = { [weak self] in
            self?.toggleWorkspace()
        }
        switcherTouchBarController.onPresentationInterrupted = { [weak self] in

            self?.presentPhysicalSwitcherIfNeeded()
        }
    }

    private var usesSoftwareWorkspace: Bool {
        TouchBarHardwareCapability.usesSoftwareWorkspace
    }

    private var effectiveSwitcherDisplayMode: WorkspaceSwitcherDisplayMode {
        if forceFloatingSwitcher {
            return .floating
        }
        return SoftwareWorkspaceLaunchPolicy.effectiveSwitcherDisplayMode(
            usesSoftwareWorkspace: usesSoftwareWorkspace,
            preferred: WorkspacePreferences.switcherDisplayMode,
            scene: rootView.scene
        )
    }

    private func updateMirrorClickThrough() {
        window?.ignoresMouseEvents = MirrorClickThroughPolicy.ignoresMouseEvents(
            usesSoftwareWorkspace: usesSoftwareWorkspace,
            scene: rootView.scene,
            showsWorkspaceFallback: rootView.showsWorkspaceFallback
        )
        hoverOpacityController.refresh()
    }

    private func configureFloatingWorkspaceSwitcher() {
        guard effectiveSwitcherDisplayMode == .floating else {
            workspaceSwitcherWindowController?.window?.orderOut(nil)
            workspaceSwitcherWindowController = nil
            return
        }
        guard workspaceSwitcherWindowController == nil else {
            workspaceSwitcherWindowController?.switcherView.setScene(
                rootView.scene
            )
            return
        }
        let controller = WorkspaceSwitcherWindowController()
        controller.switcherView.onMouseDown = nil
        controller.switcherView.onToggleScene = { [weak self] in
            self?.toggleWorkspace()
        }
        controller.switcherView.setScene(rootView.scene)
        workspaceSwitcherWindowController = controller
    }

    private func showFloatingWorkspaceSwitcherIfNeeded() {
        guard
            isRunning,
            effectiveSwitcherDisplayMode == .floating,
            let controller = workspaceSwitcherWindowController,
            let mirrorWindow = window
        else {
            return
        }
        if !controller.hasRestoredFrame {
            controller.positionBesideMirror(mirrorWindow)
        }
        controller.window?.orderFrontRegardless()
    }

    private func presentPhysicalSwitcherIfNeeded() {
        guard isRunning, rootView.scene == .mirror else { return }
        guard !usesSoftwareWorkspace else {
            switcherTouchBarController.dismiss()
            return
        }
        guard effectiveSwitcherDisplayMode == .touchBar else {
            switcherTouchBarController.dismiss()
            return
        }
        TouchBarPresentationPreferences.clearWorkspaceAppModeIfPresent(
            workspaceMode: WorkspaceTouchBarLayout.presentationMode
        )
        switcherTouchBarController.present()
    }


    private func enterSoftwareWorkspace(isLaunch: Bool) {
        beginWorkspaceSession()
        if !isLaunch {
            rootView.beginSceneTransitionCover()
        }
        rootView.setScene(.workspace)
        workspaceSwitcherWindowController?.switcherView.setScene(.workspace)
        switcherTouchBarController.dismiss()
        rootView.setWorkspaceFallbackVisible(true)
        updateMirrorClickThrough()

        refreshQuotaDisplay()
        configureFloatingWorkspaceSwitcher()
        showFloatingWorkspaceSwitcherIfNeeded()
        if !isLaunch {
            rootView.scheduleSceneTransitionCoverFade()
        }
    }

    private func toggleWorkspace() {
        switch rootView.scene {
        case .mirror:
            if usesSoftwareWorkspace {
                enterSoftwareWorkspace(isLaunch: false)
                return
            }
            enterHardwareWorkspace(isLaunch: false)
        case .workspace:
            closeWorkspace()
        }
    }

    private func enterHardwareWorkspace(isLaunch: Bool) {
        beginWorkspaceSession()
        if !isLaunch {
            rootView.beginSceneTransitionCover()
        }
        rootView.setScene(.workspace)
        workspaceSwitcherWindowController?.switcherView.setScene(.workspace)
        switcherTouchBarController.dismiss()

        do {
            try workspaceTouchBarController.present()
            forceFloatingSwitcher = false
            rootView.setWorkspaceFallbackVisible(false)
            updateMirrorClickThrough()
        } catch {
            forceFloatingSwitcher = true
            rootView.setWorkspaceFallbackVisible(true)
            updateMirrorClickThrough()
            configureFloatingWorkspaceSwitcher()
            showFloatingWorkspaceSwitcherIfNeeded()
            refreshQuotaDisplay()
            if !isLaunch {
                rootView.scheduleSceneTransitionCoverFade()
            }
            return
        }

        refreshQuotaDisplay()
        configureFloatingWorkspaceSwitcher()
        showFloatingWorkspaceSwitcherIfNeeded()
        if !isLaunch {
            rootView.scheduleSceneTransitionCoverFade()
        }
    }

    private func closeWorkspace() {
        cancelWorkspaceAsyncWork(invalidateSession: true)
        rootView.beginSceneTransitionCover()
        if !usesSoftwareWorkspace {
            workspaceTouchBarController.dismiss()
        }
        rootView.setWorkspaceFallbackVisible(false)
        rootView.setScene(.mirror)
        workspaceSwitcherWindowController?.switcherView.setScene(.mirror)
        if usesSoftwareWorkspace {
            rootView.surfaceView.displaySoftwareWorkspaceIdle()
        }
        updateMirrorClickThrough()
        forceFloatingSwitcher = false
        configureFloatingWorkspaceSwitcher()
        showFloatingWorkspaceSwitcherIfNeeded()
        presentPhysicalSwitcherIfNeeded()
        hoverOpacityController.refresh()
        rootView.scheduleSceneTransitionCoverFade()
    }

    private func handleWorkspacePresentationInterrupted() {
        guard rootView.scene == .workspace else { return }

        guard !usesSoftwareWorkspace else { return }


        resumeToWorkspace = true
        cancelWorkspaceAsyncWork(invalidateSession: true)
        rootView.beginSceneTransitionCover()
        rootView.setWorkspaceFallbackVisible(false)
        rootView.setScene(.mirror)
        workspaceSwitcherWindowController?.switcherView.setScene(.mirror)
        presentPhysicalSwitcherIfNeeded()
        updateMirrorClickThrough()
        rootView.scheduleSceneTransitionCoverFade()
    }

    func reloadCustomAppsFromPreferences() {
        rootView.workspaceView.reloadCustomAppsFromPreferences()
        workspaceTouchBarController.reloadCustomAppsFromPreferences()
    }

    func quotaProviderChoices() -> [QuotaProviderChoice] {
        let live = quotaStore.providerChoices()
        return live.isEmpty ? WorkspacePreferences.seenQuotaProviders : live
    }

    func reloadWorkspaceRegionLayout() {
        rootView.workspaceView.needsLayout = true
        workspaceTouchBarController.reloadRegionLayout()
    }

    func reloadQuotaVisibilityFromPreferences() {
        applyQuotaPlate()
    }

    private func refreshQuotaDisplay() {
        applyQuotaPlate()
        startQuotaRefreshLoop()
    }

    private func applyQuotaPlate() {
        let state = quotaStore.boardState()
        rootView.workspaceView.showQuota(state)
        workspaceTouchBarController.showQuota(state)
    }

    private func startQuotaRefreshLoop() {
        quotaRefreshTask?.cancel()
        let generation = workspaceGeneration
        quotaRefreshTask = Task { @MainActor [weak self] in
            await self?.loadOpenUsageQuota(generation: generation)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(QuotaRefreshSchedule.interval))
                guard !Task.isCancelled else { return }
                await self?.loadOpenUsageQuota(generation: generation)
            }
        }
    }

    private func loadOpenUsageQuota(generation: UInt64) async {
        guard canUpdateWorkspace(from: generation) else { return }
        do {
            let pools = try await OpenUsageQuotaReader.fetch()
            guard canUpdateWorkspace(from: generation) else { return }
            quotaStore.replace(pools)
            WorkspacePreferences.rememberSeenQuotaProviders(pools)
            onQuotaProvidersChanged?()
        } catch {
            guard canUpdateWorkspace(from: generation) else { return }
        }
        applyQuotaPlate()
    }

    private func openCustomWorkspaceApp(_ app: CustomWorkspaceApp) {
        let generation = workspaceGeneration
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                try await CustomWorkspaceAppLauncher.open(app)
            } catch {
                guard self.canUpdateWorkspace(from: generation) else { return }
            }
        }
    }

    @discardableResult
    private func beginWorkspaceSession() -> UInt64 {
        cancelWorkspaceAsyncWork(invalidateSession: false)
        workspaceGeneration &+= 1
        return workspaceGeneration
    }

    private func cancelWorkspaceAsyncWork(invalidateSession: Bool) {
        quotaRefreshTask?.cancel()
        quotaRefreshTask = nil
        if invalidateSession {
            workspaceGeneration &+= 1
        }
    }

    private func canUpdateWorkspace(from generation: UInt64) -> Bool {
        WorkspaceAsyncSessionPolicy.canUpdate(
            capturedGeneration: generation,
            currentGeneration: workspaceGeneration,
            scene: rootView.scene
        )
    }

    private func installWorkspaceObservers() {
        let center = NSWorkspace.shared.notificationCenter
        let pauseNotifications: [Notification.Name] = [
            NSWorkspace.sessionDidResignActiveNotification,
            NSWorkspace.screensDidSleepNotification,
            NSWorkspace.willSleepNotification,
        ]
        let resumeNotifications: [Notification.Name] = [
            NSWorkspace.sessionDidBecomeActiveNotification,
            NSWorkspace.screensDidWakeNotification,
            NSWorkspace.didWakeNotification,
        ]

        for name in pauseNotifications {
            workspaceObservers.append(
                center.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self, self.isRunning else { return }
                        self.resumeToWorkspace =
                            WorkspaceSleepPausePolicy.latchedResumeToWorkspace(
                                alreadyPaused: self.isHardwareSessionPaused,
                                latchedResume: self.resumeToWorkspace,
                                sceneIsWorkspace: self.rootView.scene
                                    == .workspace
                            )
                        self.isHardwareSessionPaused = true
                        if self.rootView.scene == .workspace,
                           !self.usesSoftwareWorkspace
                        {



                            self.workspaceTouchBarController.dismiss()
                        }
                        self.switcherTouchBarController.dismiss()
                        self.capture.stop()
                    }
                }
            )
        }

        for name in resumeNotifications {
            workspaceObservers.append(
                center.addObserver(
                    forName: name,
                    object: nil,
                    queue: .main
                ) { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self, self.isRunning else { return }
                        self.isHardwareSessionPaused = false
                        switch TouchBarResumePolicy.action(
                            usesSoftwareWorkspace: self.usesSoftwareWorkspace,
                            restoreWorkspace: self.resumeToWorkspace
                        ) {
                        case .restoreSoftwareWorkspace:
                            if self.rootView.scene != .workspace {
                                self.enterSoftwareWorkspace(isLaunch: true)
                            }
                        case .restartHardwareCapture:
                            self.capture.restart()
                            self.presentPhysicalSwitcherIfNeeded()
                        case .restoreHardwareWorkspace:
                            self.capture.restart()
                            self.enterHardwareWorkspace(isLaunch: true)
                        }
                        self.resumeToWorkspace = false
                    }
                }
            )
        }

    }
}
