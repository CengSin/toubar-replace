import AppKit

enum DesktopTheme: Equatable, Sendable {
    case black
    case glass
}

enum DesktopThemePolicy {
    static var supportsGlass: Bool {
        if #available(macOS 26, *) { return true }
        return false
    }

    static func effectiveTheme(enabled: Bool, supportsGlass: Bool) -> DesktopTheme {
        enabled && supportsGlass ? .glass : .black
    }

    static var current: DesktopTheme {
        effectiveTheme(enabled: TouchBarPreferences.glassThemeEnabled, supportsGlass: supportsGlass)
    }

    static func targetAlpha(theme: DesktopTheme, isMouseInside: Bool, overlapsOtherApp: Bool) -> CGFloat {
        theme == .glass ? 1 : TouchBarHoverOpacity.targetAlpha(
            isMouseInside: isMouseInside, overlapsOtherApp: overlapsOtherApp
        )
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

    init(content: NSView) {
        hostedContent = content
        super.init(frame: content.frame)
        autoresizingMask = [.width, .height]
        content.autoresizingMask = [.width, .height]
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
                glass.autoresizingMask = [.width, .height]
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

    override func layout() {
        super.layout()
        glassView?.frame = bounds
        hostedContent.frame = bounds
        if #available(macOS 26, *), let glass = glassView as? NSGlassEffectView {
            glass.cornerRadius = min(bounds.height / 2, 18)
        }
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
