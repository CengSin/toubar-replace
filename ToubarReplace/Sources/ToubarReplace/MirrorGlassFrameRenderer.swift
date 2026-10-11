import CoreGraphics
import Foundation
import MirrorFrameProcessing

struct TouchBarFrameSignature: Equatable {
    private let pixels: [UInt8]

    init?(image: CGImage) {
        var pixels = [UInt8](repeating: 0, count: 64 * 4 * 4)
        let drew = pixels.withUnsafeMutableBytes { buffer in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: buffer.baseAddress, width: 64, height: 4,
                    bitsPerComponent: 8, bytesPerRow: 64 * 4, space: space,
                    bitmapInfo: MirrorGlassFrameRenderer.bitmapInfo) else { return false }
            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: 64, height: 4))
            return true
        }
        guard drew else { return nil }
        self.pixels = pixels
    }

    func resembles(_ other: Self) -> Bool {
        var matching = 0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            if (0..<3).allSatisfy({ abs(Int(pixels[offset + $0]) - Int(other.pixels[offset + $0])) <= 12 }) {
                matching += 1
            }
        }
        return matching >= 230
    }
}

enum MirrorGlassAppearance: Sendable {
    case light
    case dark

    var foreground: UInt8 { self == .light ? 24 : 242 }
}

final class MirrorGlassFrameRenderer {
    private var pixels: [UInt8] = []
    private let processor = TBRMirrorFrameProcessorCreate()
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    static let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
        | CGImageAlphaInfo.premultipliedLast.rawValue

    deinit {
        TBRMirrorFrameProcessorDestroy(processor)
    }

    func render(_ image: CGImage, appearance: MirrorGlassAppearance = .light) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0, width <= 16_384, height <= 4_096,
              let processor else { return nil }
        let count = width * height * 4
        if pixels.count != count { pixels = [UInt8](repeating: 0, count: count) }
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: colorSpace, bitmapInfo: Self.bitmapInfo
            ), let address = buffer.bindMemory(to: UInt8.self).baseAddress else { return false }
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return TBRMirrorFrameProcess(processor, address, width, height, appearance.foreground)
        }
        guard rendered, let provider = CGDataProvider(data: Data(pixels) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8,
                       bitsPerPixel: 32, bytesPerRow: width * 4, space: colorSpace,
                       bitmapInfo: CGBitmapInfo(rawValue: Self.bitmapInfo), provider: provider,
                       decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

struct MirrorGlassFrameToken: Equatable, Sendable {
    let generation: UInt64
    let sequence: UInt64

    func canDeliver(currentGeneration: UInt64, deliveredSequence: UInt64) -> Bool {
        generation == currentGeneration && sequence >= deliveredSequence
    }
}

final class MirrorGlassFramePipeline: @unchecked Sendable {
    private struct Work {
        let image: CGImage
        let token: MirrorGlassFrameToken
        let appearance: MirrorGlassAppearance
    }

    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.toubarreplace.mirror-glass", qos: .userInteractive)
    private let renderer = MirrorGlassFrameRenderer()
    private let onFrame: @MainActor @Sendable (CGImage, MirrorGlassFrameToken) -> Void
    private var pending: Work?
    private var running = false
    private var awaitingDelivery: Work?
    private var deliveryScheduled = false

    init(onFrame: @escaping @MainActor @Sendable (CGImage, MirrorGlassFrameToken) -> Void) {
        self.onFrame = onFrame
    }

    func submit(_ image: CGImage, token: MirrorGlassFrameToken, appearance: MirrorGlassAppearance = .light) {
        lock.lock()
        pending = Work(image: image, token: token, appearance: appearance)
        let shouldStart = !running
        running = true
        lock.unlock()
        if shouldStart { queue.async { [weak self] in self?.process() } }
    }

    func discardPending() {
        lock.lock()
        pending = nil
        awaitingDelivery = nil
        lock.unlock()
    }

    private func scheduleDelivery(_ image: CGImage, token: MirrorGlassFrameToken) {
        lock.lock()
        awaitingDelivery = Work(image: image, token: token, appearance: .light)
        let shouldSchedule = !deliveryScheduled
        deliveryScheduled = true
        lock.unlock()
        if shouldSchedule {
            Task { @MainActor [weak self] in self?.deliverLatest() }
        }
    }

    @MainActor
    private func deliverLatest() {
        lock.lock()
        let work = awaitingDelivery
        awaitingDelivery = nil
        deliveryScheduled = false
        lock.unlock()
        if let work { onFrame(work.image, work.token) }
    }

    private func process() {
        while true {
            lock.lock()
            let work = pending
            pending = nil
            if work == nil { running = false }
            lock.unlock()
            guard let work else { return }
            guard let frame = renderer.render(work.image, appearance: work.appearance) else { continue }
            scheduleDelivery(frame, token: work.token)
        }
    }
}
