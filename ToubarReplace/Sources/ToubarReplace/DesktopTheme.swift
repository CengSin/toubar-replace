import AppKit
import MirrorFrameProcessing

enum DesktopTheme: String, CaseIterable, Equatable, Sendable {
    case black
    case smoke
    case glass

    var title: String {
        switch self {
        case .black: return "经典黑"
        case .smoke: return "烟晶（低功耗半透明）"
        case .glass: return "液态玻璃"
        }
    }

    var usesClearBackground: Bool { self != .black }
}

enum DesktopThemePolicy {
    static var supportsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    static func effectiveTheme(enabled: Bool, supportsGlass: Bool) -> DesktopTheme {
        enabled && supportsGlass ? .glass : .black
    }

    static func effectiveTheme(preferred: DesktopTheme, supportsGlass: Bool) -> DesktopTheme {
        preferred == .glass && !supportsGlass ? .black : preferred
    }

    static var current: DesktopTheme {
        effectiveTheme(preferred: TouchBarPreferences.desktopTheme, supportsGlass: supportsGlass)
    }
}

@MainActor
final class DesktopSmokeMaterialView: NSView {
    private let sheen = DesktopGradientView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        let base = DesktopGradientView(frame: bounds)
        base.autoresizingMask = [.width, .height]
        base.gradient.colors = [
            NSColor(srgbRed: 0.19, green: 0.20, blue: 0.24, alpha: 0.76).cgColor,
            NSColor(srgbRed: 0.06, green: 0.065, blue: 0.085, alpha: 0.86).cgColor,
        ]
        base.gradient.startPoint = CGPoint(x: 0.5, y: 1)
        base.gradient.endPoint = CGPoint(x: 0.5, y: 0)
        addSubview(base)
        sheen.frame = bounds
        sheen.autoresizingMask = [.width, .height]
        sheen.gradient.colors = [
            NSColor.white.withAlphaComponent(0.11).cgColor,
            NSColor.white.withAlphaComponent(0.02).cgColor,
            NSColor.white.withAlphaComponent(0).cgColor,
            NSColor.white.withAlphaComponent(0.035).cgColor,
        ]
        sheen.gradient.locations = [0, 0.42, 0.78, 1]
        sheen.gradient.startPoint = CGPoint(x: 0.5, y: 1)
        sheen.gradient.endPoint = CGPoint(x: 0.5, y: 0)
        addSubview(sheen)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

@MainActor
final class DesktopGradientView: NSView {
    var gradient: CAGradientLayer {
        if let layer = layer as? CAGradientLayer { return layer }
        let layer = CAGradientLayer()
        self.layer = layer
        return layer
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layerContentsRedrawPolicy = .never
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func makeBackingLayer() -> CALayer { CAGradientLayer() }
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {}
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

enum MirrorSmokeFrameKeyer {
    static func keyed(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0, width <= 16_384, height <= 4_096,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space,
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
              ) else { return nil }
        context.setBlendMode(.copy)
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixels = context.data else { return nil }
        TBRMirrorFrameApplyLuminanceAlpha(pixels.assumingMemoryBound(to: UInt8.self), width, height, context.bytesPerRow)
        return context.makeImage()
    }
}

@MainActor
enum DesktopThemeChrome {
    static func apply(to layer: CALayer?, theme: DesktopTheme, highlighted: Bool = false, enabled: Bool = true) {
        guard theme == .glass else {
            WorkspaceTouchBarStyle.applyItemChrome(to: layer, highlighted: highlighted, enabled: enabled)
            return
        }
        let pressed = highlighted && enabled
        layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(pressed ? 0.16 : 0.05).cgColor
        layer?.borderWidth = pressed ? 1 : 0
        layer?.borderColor = NSColor.labelColor.withAlphaComponent(0.2).cgColor
        layer?.cornerRadius = WorkspaceTouchBarStyle.cornerRadius
    }
}

@MainActor
final class DesktopGlassHostView: NSView {
    let hostedContent: NSView
    private(set) var theme: DesktopTheme = .black
    private var glassView: NSView?
    private let usesCapsuleShape: Bool

    init(content: NSView, usesCapsuleShape: Bool = false) {
        hostedContent = content
        self.usesCapsuleShape = usesCapsuleShape
        super.init(frame: content.frame)
        autoresizingMask = [.width, .height]
        content.autoresizingMask = []
        addSubview(content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(theme: DesktopTheme) {
        self.theme = theme
        if theme == .glass, #available(macOS 26, *) {
            if glassView == nil {
                let glass = NSGlassEffectView(frame: bounds)
                glass.style = .clear
                hostedContent.removeFromSuperview()
                glass.contentView = hostedContent
                addSubview(glass)
                glassView = glass
            }
        } else {
            if #available(macOS 26, *), let glass = glassView as? NSGlassEffectView {
                glass.contentView = nil
            }
            glassView?.removeFromSuperview()
            glassView = nil
            if hostedContent.superview !== self { addSubview(hostedContent) }
        }
        needsLayout = true
        layoutSubtreeIfNeeded()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        glassView?.frame = bounds
        hostedContent.frame = bounds
        if #available(macOS 26, *), let glass = glassView as? NSGlassEffectView {
            glass.cornerRadius = usesCapsuleShape ? min(bounds.width, bounds.height) / 2 : min(bounds.height / 2, 18)
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
