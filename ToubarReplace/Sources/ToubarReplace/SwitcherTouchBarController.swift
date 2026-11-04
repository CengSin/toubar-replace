import AppKit
import TouchBarPrivateAPI







@MainActor
final class SwitcherTouchBarController: NSObject, NSTouchBarDelegate {
    private enum ItemIdentifier {
        static let switcher = NSTouchBarItem.Identifier(
            "com.toubarreplace.switcher"
        )
    }



    private static let placement: Int64 = 0

    let touchBar = NSTouchBar()
    private let hostView = SwitcherTouchBarHostView()
    private lazy var recovery = TouchBarPresentationRecovery { [weak self] in
        guard let self, self.isPresented else { return true }
        guard self.hostView.window == nil else {
            self.suppressCloseBox()
            return true
        }
        TBRDismissSystemModalTouchBar(self.touchBar)
        TBRPresentSystemModalTouchBar(self.touchBar, Self.placement)
        self.suppressCloseBox()
        return self.hostView.window != nil
    }
    private(set) var isPresented = false
    var onToggleWorkspace: (() -> Void)?
    var onCollapse: (() -> Void)?


    override init() {
        super.init()
        touchBar.delegate = self
        touchBar.defaultItemIdentifiers = [ItemIdentifier.switcher]
        touchBar.customizationAllowedItemIdentifiers = []
        hostView.onToggle = { [weak self] in
            self?.onToggleWorkspace?()
        }
        hostView.onCollapse = { [weak self] in self?.onCollapse?() }
        hostView.onWindowAttachmentChanged = { [weak self] attached in
            self?.handleWindowAttachmentChanged(attached)
        }
    }

    func present() {
        guard !isPresented else {
            suppressCloseBox()
            return
        }
        guard TBRCanPresentSystemModalTouchBar() else { return }

        isPresented = true
        TBRSetSystemModalShowsCloseBoxWhenFrontMost(false)
        TBRPresentSystemModalTouchBar(touchBar, Self.placement)
        suppressCloseBox()
        recovery.schedule()
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        recovery.cancel()
        TBRDismissSystemModalTouchBar(touchBar)
        TBRSetSystemModalShowsCloseBoxWhenFrontMost(true)
    }



    func suppressCloseBox() {
        guard isPresented else { return }
        TBRSetSystemModalShowsCloseBoxWhenFrontMost(false)
        TBRHideSystemModalCloseButton()
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        guard identifier == ItemIdentifier.switcher else { return nil }

        let item = NSCustomTouchBarItem(identifier: identifier)
        item.customizationLabel = "Workspace"
        item.view = hostView
        return item
    }

    func reconcilePresentation() {
        guard isPresented else { return }
        recovery.schedule()
    }

    private func handleWindowAttachmentChanged(_ attached: Bool) {
        guard isPresented else { return }
        if attached { suppressCloseBox() }
        reconcilePresentation()
    }

}

@MainActor
private final class SwitcherTouchBarHostView: NSView {
    var onWindowAttachmentChanged: ((Bool) -> Void)?
    var onToggle: (() -> Void)?
    var onCollapse: (() -> Void)?

    private let button = NSButton()
    private let collapseButton = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        button.image = NSImage(
            systemSymbolName: "square.grid.2x2",
            accessibilityDescription: "打开 Workspace"
        )
        button.contentTintColor = NSColor.white
        button.isBordered = false
        button.bezelStyle = .texturedRounded
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageOnly
        button.toolTip = "点击打开 Workspace"
        button.setAccessibilityLabel("打开 Workspace")
        button.target = self
        button.action = #selector(toggle)
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        collapseButton.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "隐藏 ToubarReplace")
        collapseButton.contentTintColor = .white
        collapseButton.isBordered = false
        collapseButton.imagePosition = .imageOnly
        collapseButton.target = self
        collapseButton.action = #selector(collapse)
        collapseButton.setAccessibilityLabel("隐藏 ToubarReplace")
        collapseButton.setAccessibilityIdentifier("ToubarReplace.TouchBar.Collapse")
        collapseButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(collapseButton)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            collapseButton.leadingAnchor.constraint(equalTo: button.trailingAnchor, constant: 6),
            collapseButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            collapseButton.topAnchor.constraint(equalTo: topAnchor),
            collapseButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            collapseButton.widthAnchor.constraint(equalToConstant: WorkspaceTouchBarLayout.collapseButtonWidth),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.widthAnchor.constraint(equalToConstant: 44),
            button.heightAnchor.constraint(equalToConstant: 30),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowAttachmentChanged?(window != nil)
    }

    @objc
    private func toggle() {
        onToggle?()
    }

    @objc private func collapse() { onCollapse?() }
}
