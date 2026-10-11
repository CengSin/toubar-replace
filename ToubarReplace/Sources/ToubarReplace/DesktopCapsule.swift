import AppKit

enum DesktopCapsuleLayout {
    static let initialRevealWidth: CGFloat = 48
    static let minimumSize = CGSize(width: 1, height: 1)

    static func expandedSize(pixelSize: CGSize, backingScaleFactor: CGFloat) -> CGSize {
        let points = TouchBarWindowMetrics.pointSize(
            forPixelSize: pixelSize, backingScaleFactor: backingScaleFactor
        )
        return CGSize(width: max(points.width, 1), height: max(points.height, 1))
    }

    static func contentFrame(expandedSize: CGSize) -> CGRect {
        CGRect(origin: .zero, size: expandedSize)
    }

    static func frame(origin: CGPoint, size: CGSize) -> CGRect {
        CGRect(origin: origin, size: size)
    }

    static func contentAlpha(width: CGFloat, expandedWidth: CGFloat) -> CGFloat {
        let initialWidth = min(initialRevealWidth, expandedWidth)
        let distance = expandedWidth - initialWidth
        guard distance > 0 else { return width >= expandedWidth ? 1 : 0 }
        let progress = min(max((width - initialWidth) / distance, 0), 1)
        let reveal = min(max((progress - 0.08) / 0.72, 0), 1)
        return reveal * reveal * (3 - 2 * reveal)
    }
}

struct DesktopCapsuleSpring {
    static let response: Double = 0.36
    static let dampingRatio: Double = 0.82
    private(set) var value: CGFloat
    private(set) var velocity: CGFloat = 0
    var target: CGFloat

    init(value: CGFloat) {
        self.value = value
        target = value
    }

    var isSettled: Bool { abs(value - target) < 0.1 && abs(velocity) < 0.5 }

    mutating func settle() {
        value = target
        velocity = 0
    }

    mutating func advance(by interval: TimeInterval) {
        let omega = 2 * Double.pi / Self.response
        let damping = Self.dampingRatio * omega
        let frequency = omega * sqrt(1 - Self.dampingRatio * Self.dampingRatio)
        let elapsed = max(interval, 0)
        let offset = Double(value - target)
        let sineCoefficient = (Double(velocity) + damping * offset) / frequency
        let envelope = exp(-damping * elapsed)
        let oscillation = offset * cos(frequency * elapsed) + sineCoefficient * sin(frequency * elapsed)
        value = target + CGFloat(envelope * oscillation)
        velocity = CGFloat(envelope * (
            -damping * oscillation - offset * frequency * sin(frequency * elapsed)
                + sineCoefficient * frequency * cos(frequency * elapsed)
        ))
        if isSettled { settle() }
    }
}

@MainActor
final class DesktopCapsuleButton: NSView {
    private let imageView = NSImageView()
    var onPress: (() -> Void)?
    var acceptsPointerInput = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        imageView.imageScaling = .scaleProportionallyDown
        addSubview(imageView)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: NSPoint) -> NSView? {
        acceptsPointerInput && super.hitTest(point) != nil ? self : nil
    }

    func apply(theme: DesktopTheme) {
        imageView.contentTintColor = theme == .glass ? .labelColor : .white
    }

    func setSymbol(_ symbol: String, label: String, tooltip: String) {
        imageView.image = NSImage(systemSymbolName: symbol, accessibilityDescription: label)
        toolTip = tooltip
        setAccessibilityLabel(label)
    }

    override func layout() {
        super.layout()
        let size = min(bounds.width, bounds.height) * 0.4
        imageView.frame = NSRect(x: bounds.midX - size / 2, y: bounds.midY - size / 2, width: size, height: size)
        layer?.cornerRadius = min(bounds.width, bounds.height) / 2
    }

    override func mouseUp(with event: NSEvent) {
        guard acceptsPointerInput, bounds.contains(convert(event.locationInWindow, from: nil)) else { return }
        onPress?()
    }

    override func accessibilityPerformPress() -> Bool {
        onPress?()
        return true
    }
}

@MainActor
final class DesktopCapsuleView: NSView {
    let content: NSView
    private let contentContainer = NSView()
    private(set) var isExpanded = false
    var expandedSize = DesktopCapsuleLayout.minimumSize
    var contentAcceptsMouseEvents = true

    init(content: NSView) {
        self.content = content
        super.init(frame: NSRect(origin: .zero, size: DesktopCapsuleLayout.minimumSize))
        wantsLayer = true
        layer?.masksToBounds = true
        contentContainer.wantsLayer = true
        contentContainer.addSubview(content)
        addSubview(contentContainer)
        setAccessibilityIdentifier("ToubarReplace.DesktopCapsule")
        setExpanded(false)
        apply(theme: .black)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func apply(theme: DesktopTheme) {
        layer?.backgroundColor = (theme == .glass ? NSColor.clear : .black).cgColor
    }

    func setExpanded(_ expanded: Bool) {
        isExpanded = expanded
    }

    func updateReveal(width: CGFloat) {
        let alpha = isExpanded ? DesktopCapsuleLayout.contentAlpha(width: width, expandedWidth: expandedSize.width) : 0
        contentContainer.alphaValue = alpha
        contentContainer.isHidden = alpha <= 0
    }

    override func layout() {
        super.layout()
        layer?.cornerRadius = min(bounds.width, bounds.height) / 2
        var contentFrame = DesktopCapsuleLayout.contentFrame(expandedSize: expandedSize)
        contentFrame.origin.y = bounds.midY - contentFrame.height / 2
        contentContainer.frame = contentFrame
        content.frame = contentContainer.bounds
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard contentAcceptsMouseEvents, isExpanded, let hit = super.hitTest(point),
              hit.isDescendant(of: contentContainer) else { return nil }
        return hit
    }
}

@MainActor
final class DesktopCapsuleController {
    private weak var window: NSWindow?
    let view: DesktopCapsuleView
    private var width = DesktopCapsuleSpring(value: 1)
    private var height = DesktopCapsuleSpring(value: 1)
    private var animationTimer: Timer?
    private var lastFrameTime: TimeInterval = 0
    private(set) var isExpanded = false
    var isAnimating: Bool { animationTimer != nil || !width.isSettled || !height.isSettled }
    var onExpansionChanged: ((Bool) -> Void)?
    var onAnimationStarted: (() -> Void)?
    var onAnimationCompleted: (() -> Void)?

    init(window: NSWindow, view: DesktopCapsuleView) {
        self.window = window
        self.view = view
        applyFrame()
    }

    func start() {
        setExpanded(true, animated: false)
    }

    func stop() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    func configure(pixelSize: CGSize, backingScaleFactor: CGFloat) {
        view.expandedSize = DesktopCapsuleLayout.expandedSize(pixelSize: pixelSize, backingScaleFactor: backingScaleFactor)
        view.needsLayout = true
        setExpanded(isExpanded)
    }

    func show() {
        setExpanded(true)
    }

    func toggle() {
        setExpanded(!isExpanded)
    }

    func setExpanded(_ expanded: Bool, animated: Bool = true) {
        let changed = isExpanded != expanded
        let wasAnimating = isAnimating
        isExpanded = expanded
        view.setExpanded(expanded)
        let target = view.expandedSize
        if !expanded {
            window?.orderOut(nil)
            animationTimer?.invalidate()
            animationTimer = nil
            width.target = target.width
            height.target = target.height
            width.settle()
            height.settle()
            applyFrame()
            if changed { onExpansionChanged?(false) }
            if changed || wasAnimating { onAnimationCompleted?() }
            return
        }
        if changed && animated && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            width = DesktopCapsuleSpring(value: min(DesktopCapsuleLayout.initialRevealWidth, target.width))
            height = DesktopCapsuleSpring(value: target.height)
        }
        width.target = target.width
        height.target = target.height
        let shouldNotifyCompletion = changed || wasAnimating || !width.isSettled || !height.isSettled
        if !animated || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            width.settle()
            height.settle()
            animationTimer?.invalidate()
            animationTimer = nil
            applyFrame()
            window?.orderFrontRegardless()
            if changed { onExpansionChanged?(true) }
            if shouldNotifyCompletion { onAnimationCompleted?() }
            return
        }
        applyFrame()
        window?.orderFrontRegardless()
        if changed { onExpansionChanged?(true) }
        guard animationTimer == nil else { return }
        guard !width.isSettled || !height.isSettled else {
            applyFrame()
            if shouldNotifyCompletion { onAnimationCompleted?() }
            return
        }
        onAnimationStarted?()
        lastFrameTime = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1 / 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advanceAnimation() }
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    private func advanceAnimation() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = min(now - lastFrameTime, 0.05)
        lastFrameTime = now
        width.advance(by: elapsed)
        height.advance(by: elapsed)
        applyFrame()
        if width.isSettled && height.isSettled {
            animationTimer?.invalidate()
            animationTimer = nil
            onAnimationCompleted?()
        }
    }

    private func applyFrame() {
        guard let window else { return }
        let size = CGSize(width: max(width.value, 1), height: max(height.value, 1))
        window.setFrame(DesktopCapsuleLayout.frame(origin: window.frame.origin, size: size), display: true)
        view.updateReveal(width: size.width)
        view.needsLayout = true
        window.contentView?.layoutSubtreeIfNeeded()
    }
}
