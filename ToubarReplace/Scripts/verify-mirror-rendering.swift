import CoreGraphics
import Foundation
import ImageIO

@main
struct MirrorRenderingVerification {
    static func main() throws {
        let width = 2_300, height = 70
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: MirrorGlassFrameRenderer.bitmapInfo)!
        if CommandLine.arguments.count > 2,
           let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[2]) as CFURL, nil),
           let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        } else {
            context.setFillColor(CGColor(gray: 0, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            for index in 0..<12 {
                let plate = CGRect(x: index * 180 + 10, y: 6, width: 160, height: 58)
                context.setFillColor(CGColor(gray: 0.21, alpha: 1))
                context.addPath(CGPath(roundedRect: plate, cornerWidth: 10, cornerHeight: 10, transform: nil))
                context.fillPath()
                context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1))
                context.fillEllipse(in: CGRect(x: index * 180 + 30, y: 15, width: 40, height: 40))
                context.setFillColor(CGColor(gray: 1, alpha: 1))
                context.fillEllipse(in: CGRect(x: index * 180 + 95, y: 20, width: 30, height: 30))
            }
        }
        let image = context.makeImage()!
        let renderer = MirrorGlassFrameRenderer()
        var times: [Double] = []
        for index in 0..<120 {
            let start = DispatchTime.now().uptimeNanoseconds
            guard let rendered = renderer.render(image) else { fatalError("Mirror composition failed") }
            precondition(rendered.width == width && rendered.height == height)
            let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            if index >= 20 { times.append(elapsed) }
        }
        times.sort()
        let report: [String: Any] = ["width": width, "height": height, "measured_frames": times.count,
            "median_ms": times[50], "p95_ms": times[95], "maximum_ms": times.last!]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
        print(String(format: "Mirror 2300×70, 100 measured frames: median %.3fms, P95 %.3fms, max %.3fms",
                     times[50], times[95], times.last!))
    }
}
