import AppKit
import TouchBarPrivateAPI

enum DesktopTouchBarPresentation: Equatable {
    case inactive
    case wake
    case scene
}

enum DesktopTouchBarPolicy {
    static func presentation(running: Bool, paused: Bool, expanded: Bool,
                             animating: Bool, trackingWakeTouch: Bool) -> DesktopTouchBarPresentation {
        guard running && !paused else { return .inactive }
        return expanded && !animating && !trackingWakeTouch ? .scene : .wake
    }

    static func ignoresPointer(expanded: Bool, animating: Bool, softwareControls: Bool) -> Bool {
        !expanded || animating || !softwareControls
    }
}

@MainActor
final class DesktopWakeButton: NSButton {
    var onTrackingChanged: ((Bool) -> Void)?

    override func mouseDown(with event: NSEvent) {
        onTrackingChanged?(true)
        super.mouseDown(with: event)
        onTrackingChanged?(false)
    }
}

@MainActor
final class DesktopWakeRegionView: NSView {
    let button = DesktopWakeButton()
    var onWake: (() -> Void)?
    var onTrackingChanged: ((Bool) -> Void)?
    var onWindowAttachmentChanged: ((Bool) -> Void)?

    init(width: CGFloat, showsTitle: Bool) {
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 30))
        button.title = showsTitle ? "轻触任意位置显示 ToubarReplace" : ""
        button.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: "展开 ToubarReplace")
        button.imagePosition = showsTitle ? .imageLeading : .imageOnly
        button.contentTintColor = .white
        button.isBordered = false
        button.setButtonType(.momentaryChange)
        button.target = self
        button.action = #selector(wake)
        button.setAccessibilityLabel("轻触任意位置显示 ToubarReplace")
        button.setAccessibilityIdentifier("ToubarReplace.TouchBar.Wake")
        button.onTrackingChanged = { [weak self] tracking in self?.onTrackingChanged?(tracking) }
        addSubview(button)
        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        heightAnchor.constraint(equalToConstant: 30).isActive = true
        let preferred = widthAnchor.constraint(equalToConstant: width)
        preferred.priority = .defaultHigh
        preferred.isActive = true
        widthAnchor.constraint(lessThanOrEqualToConstant: width).isActive = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layout() {
        super.layout()
        button.frame = bounds
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(convert(point, from: superview)) ? button : nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowAttachmentChanged?(window != nil)
    }

    @objc private func wake() { onWake?() }
}

@MainActor
final class DesktopWakeTouchBarController: NSObject, NSTouchBarDelegate {
    static let placement: Int64 = 1
    static let presentationMode = "app"
    static let wakeIdentifier = NSTouchBarItem.Identifier("com.toubarreplace.desktop.wake")
    static let escapeIdentifier = NSTouchBarItem.Identifier("com.toubarreplace.desktop.wake.escape")
    let touchBar = NSTouchBar()
    let wakeView = DesktopWakeRegionView(width: WorkspaceTouchBarLayout.maximumContentWidth
        - WorkspaceTouchBarLayout.switcherWidth - WorkspaceTouchBarLayout.switcherContentGap, showsTitle: true)
    let escapeView = DesktopWakeRegionView(width: WorkspaceTouchBarLayout.switcherWidth, showsTitle: false)
    private var previousMode: String?
    private var previousInactiveStatus: Int32?
    private var attached = false
    private var trackingRegions: [ObjectIdentifier: Int] = [:]
    private var repairTask: Task<Void, Never>?
    private(set) var isPresented = false
    var isTrackingTouch: Bool { !trackingRegions.isEmpty }
    var onWake: (() -> Void)?
    var onTouchReleased: (() -> Void)?
    var onPresentationInterrupted: (() -> Void)?

    override init() {
        super.init()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [Self.wakeIdentifier]
        touchBar.principalItemIdentifier = Self.wakeIdentifier
        touchBar.escapeKeyReplacementItemIdentifier = Self.escapeIdentifier
        touchBar.customizationAllowedItemIdentifiers = []
        for region in [wakeView, escapeView] {
            let identity = ObjectIdentifier(region)
            region.onWake = { [weak self] in self?.onWake?() }
            region.onTrackingChanged = { [weak self] tracking in
                guard let self else { return }
                if tracking { self.trackingRegions[identity, default: 0] += 1 }
                else {
                    let remaining = self.trackingRegions[identity, default: 0] - 1
                    if remaining > 0 { self.trackingRegions[identity] = remaining }
                    else { self.trackingRegions.removeValue(forKey: identity) }
                    if !self.isTrackingTouch { self.onTouchReleased?() }
                }
            }
            region.onWindowAttachmentChanged = { [weak self] attached in self?.attachmentChanged(attached) }
        }
    }

    func present() {
        guard !isPresented else { TBRSetSystemModalShowsCloseBoxWhenFrontMost(false); return }
        guard TBRCanPresentSystemModalTouchBar() else { return }
        previousMode = TouchBarPresentationPreferences.currentMode
        let status = TBRGetTouchBarStatus()
        if status >= 0 && status & 1 == 0 {
            previousInactiveStatus = status
            TBRSetTouchBarStatus(status | 1)
        }
        repairTask?.cancel()
        attached = false
        isPresented = true
        TBRSetSystemModalShowsCloseBoxWhenFrontMost(false)
        TBRPresentSystemModalTouchBar(touchBar, Self.placement)
        TouchBarPresentationPreferences.setCurrentMode(Self.presentationMode)
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        repairTask?.cancel()
        repairTask = nil
        if TouchBarPresentationPreferences.currentMode == Self.presentationMode {
            TouchBarPresentationPreferences.setCurrentMode(previousMode)
        }
        TBRDismissSystemModalTouchBar(touchBar)
        TBRSetSystemModalShowsCloseBoxWhenFrontMost(true)
        if let previousInactiveStatus { TBRSetTouchBarStatus(previousInactiveStatus) }
        previousInactiveStatus = nil
        previousMode = nil
        attached = false
        trackingRegions.removeAll()
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        guard identifier == Self.wakeIdentifier || identifier == Self.escapeIdentifier else { return nil }
        let item = NSCustomTouchBarItem(identifier: identifier)
        item.customizationLabel = "展开 ToubarReplace"
        item.view = identifier == Self.wakeIdentifier ? wakeView : escapeView
        return item
    }

    private func attachmentChanged(_ isAttached: Bool) {
        repairTask?.cancel()
        if isAttached { attached = true; return }
        guard isPresented && attached else { return }
        repairTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self, self.isPresented,
                  self.wakeView.window == nil && self.escapeView.window == nil else { return }
            self.dismiss()
            self.onPresentationInterrupted?()
        }
    }
}
