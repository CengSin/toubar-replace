import CoreGraphics
import Foundation

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
    private var flood: [Int] = []
    private var protected: [UInt8] = []
    private var visited: [UInt8] = []
    private var chromeColumns: [Int] = []
    private let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    static let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
        | CGImageAlphaInfo.premultipliedLast.rawValue

    func render(_ image: CGImage, appearance: MirrorGlassAppearance = .light) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0, width <= 16_384, height <= 4_096 else { return nil }
        let count = width * height
        if pixels.count != count * 4 { pixels = [UInt8](repeating: 0, count: count * 4) }
        flood.removeAll(keepingCapacity: true)
        flood.reserveCapacity(count)
        let rendered = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: width * 4,
                space: colorSpace, bitmapInfo: Self.bitmapInfo
            ) else { return false }
            context.setBlendMode(.copy)
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            let rgba = buffer.bindMemory(to: UInt8.self)
            if chromeColumns.count != width { chromeColumns = [Int](repeating: -1, count: width) }
            else { for x in 0..<width { chromeColumns[x] = -1 } }
            for x in 0..<width {
                let top = x * 4
                let bottom = ((height - 1) * width + x) * 4
                let values = [Int(rgba[top]), Int(rgba[top + 1]), Int(rgba[top + 2]),
                              Int(rgba[bottom]), Int(rgba[bottom + 1]), Int(rgba[bottom + 2])]
                if rgba[top + 3] == 255 && rgba[bottom + 3] == 255,
                   let low = values.min(), let high = values.max(),
                   low > 4 && high <= 88 && high - low <= 8 {
                    chromeColumns[x] = values.reduce(0, +) / values.count
                }
            }
            var start = 0
            while start < width {
                guard chromeColumns[start] >= 0 else { start += 1; continue }
                var end = start + 1
                while end < width && chromeColumns[end] >= 0
                    && abs(chromeColumns[end] - chromeColumns[start]) <= 8 { end += 1 }
                if end - start < max(8, height / 3) {
                    for x in start..<end { chromeColumns[x] = -1 }
                }
                start = end
            }
            let hasChrome = chromeColumns.contains { $0 >= 0 }
            if hasChrome {
                let edgeColumns = chromeColumns
                for x in 0..<width where chromeColumns[x] < 0 {
                    let radius = max(1, height / 4)
                    for distance in 1...radius {
                        let left = x - distance
                        let right = x + distance
                        if left >= 0 && edgeColumns[left] >= 0 {
                            chromeColumns[x] = edgeColumns[left]; break
                        }
                        if right < width && edgeColumns[right] >= 0 {
                            chromeColumns[x] = edgeColumns[right]; break
                        }
                    }
                }

                if protected.count != count {
                    protected = [UInt8](repeating: 0, count: count)
                    visited = [UInt8](repeating: 0, count: count)
                } else {
                    for index in 0..<count { protected[index] = 0; visited[index] = 0 }
                }
                func isColored(_ index: Int) -> Bool {
                    let offset = index * 4
                    let r = Int(rgba[offset]), g = Int(rgba[offset + 1]), b = Int(rgba[offset + 2])
                    return rgba[offset + 3] > 0 && max(r, g, b) >= 64 && max(r, g, b) - min(r, g, b) > 16
                }
                for index in 0..<count where chromeColumns[index % width] >= 0
                    && visited[index] == 0 && isColored(index) {
                    flood.removeAll(keepingCapacity: true)
                    flood.append(index)
                    visited[index] = 1
                    var minX = index % width, maxX = minX, minY = index / width, maxY = minY
                    var cursor = 0
                    func visit(_ neighbor: Int) {
                        if visited[neighbor] == 0 && isColored(neighbor) {
                            visited[neighbor] = 1; flood.append(neighbor)
                        }
                    }
                    while cursor < flood.count {
                        let pixel = flood[cursor]; cursor += 1
                        let x = pixel % width, y = pixel / width
                        minX = min(minX, x); maxX = max(maxX, x)
                        minY = min(minY, y); maxY = max(maxY, y)
                        if x > 0 { visit(pixel - 1) }
                        if x + 1 < width { visit(pixel + 1) }
                        if y > 0 { visit(pixel - width) }
                        if y + 1 < height { visit(pixel + width) }
                    }
                    guard flood.count >= 4 else { continue }
                    minX = max(0, minX - 2); maxX = min(width - 1, maxX + 2)
                    minY = max(0, minY - 2); maxY = min(height - 1, maxY + 2)
                    for y in minY...maxY {
                        for x in minX...maxX { protected[y * width + x] = 1 }
                    }
                    flood.removeAll(keepingCapacity: true)
                    func exposeBackground(_ pixel: Int) {
                        let offset = pixel * 4, x = pixel % width
                        let base = max(0, chromeColumns[x])
                        guard protected[pixel] == 1,
                              abs(Int(rgba[offset]) - base) <= 8,
                              abs(Int(rgba[offset + 1]) - base) <= 8,
                              abs(Int(rgba[offset + 2]) - base) <= 8 else { return }
                        protected[pixel] = 0; flood.append(pixel)
                    }
                    for x in minX...maxX {
                        exposeBackground(minY * width + x); exposeBackground(maxY * width + x)
                    }
                    for y in minY...maxY {
                        exposeBackground(y * width + minX); exposeBackground(y * width + maxX)
                    }
                    cursor = 0
                    while cursor < flood.count {
                        let pixel = flood[cursor]; cursor += 1
                        let x = pixel % width, y = pixel / width
                        if x > minX { exposeBackground(pixel - 1) }
                        if x < maxX { exposeBackground(pixel + 1) }
                        if y > minY { exposeBackground(pixel - width) }
                        if y < maxY { exposeBackground(pixel + width) }
                    }
                }
            }
            flood.removeAll(keepingCapacity: true)
            func enqueue(_ index: Int) {
                let offset = index * 4
                guard rgba[offset + 3] == 255,
                      rgba[offset] <= 4, rgba[offset + 1] <= 4, rgba[offset + 2] <= 4
                else { return }
                rgba[offset] = 0
                rgba[offset + 1] = 0
                rgba[offset + 2] = 0
                rgba[offset + 3] = 0
                flood.append(index)
            }
            for x in 0..<width {
                enqueue(x)
                enqueue((height - 1) * width + x)
            }
            for y in 0..<height {
                enqueue(y * width)
                enqueue(y * width + width - 1)
            }
            var cursor = 0
            while cursor < flood.count {
                let index = flood[cursor]
                cursor += 1
                let x = index % width
                if x > 0 { enqueue(index - 1) }
                if x + 1 < width { enqueue(index + 1) }
                if index >= width { enqueue(index - width) }
                if index + width < count { enqueue(index + width) }
            }
            if hasChrome {
                for index in 0..<count where protected[index] == 0 {
                    let base = chromeColumns[index % width]
                    let offset = index * 4
                    guard base >= 0 && rgba[offset + 3] == 255 else { continue }
                    let r = Int(rgba[offset]), g = Int(rgba[offset + 1]), b = Int(rgba[offset + 2])
                    guard max(r, g, b) - min(r, g, b) <= 16 else { continue }
                    let luminance = (r + g + b) / 3
                    let alpha = luminance <= base + 8 ? 0
                        : max(0, min(255, (luminance - base) * 255 / max(1, 255 - base)))
                    let foreground = UInt8(Int(appearance.foreground) * alpha / 255)
                    rgba[offset] = foreground; rgba[offset + 1] = foreground; rgba[offset + 2] = foreground
                    rgba[offset + 3] = UInt8(alpha)
                }
            }
            return true
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
            let frame = renderer.render(work.image, appearance: work.appearance) ?? work.image
            scheduleDelivery(frame, token: work.token)
        }
    }
}
