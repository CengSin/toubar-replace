import AppKit

enum BarScene {
    case mirror
    case workspace
}

@MainActor
final class WorkspaceFloatingSwitcherView: NSView {
    enum Gesture {
        static let maximumClickDuration: TimeInterval = 0.35
        static let dragThreshold: CGFloat = 4

        static func shouldToggle(
            duration: TimeInterval,
            distance: CGFloat
        ) -> Bool {
            duration < maximumClickDuration && distance < dragThreshold
        }
    }

    private let imageView = NSImageView()
    private(set) var scene: BarScene = .mirror

    var onMouseDown: (() -> Void)?
    var onToggleScene: (() -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = WorkspaceTouchBarStyle.itemBackground.cgColor
        layer?.cornerRadius = WorkspaceTouchBarStyle.cornerRadius
        layer?.borderWidth = 0

        imageView.imageScaling = .scaleProportionallyDown
        imageView.contentTintColor = .white
        addSubview(imageView)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
        updateAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds.insetBy(dx: 13, dy: 8)
    }

    override func mouseDown(with event: NSEvent) {
        guard let window else {
            onMouseDown?()
            onToggleScene?()
            return
        }
        let initialMouseLocation = NSEvent.mouseLocation
        let originalOrigin = window.frame.origin
        var maximumDistance: CGFloat = 0
        var didDrag = false
        var mouseUpTimestamp = event.timestamp

        while let nextEvent = window.nextEvent(
            matching: [.leftMouseDragged, .leftMouseUp],
            until: .distantFuture,
            inMode: .eventTracking,
            dequeue: true
        ) {
            let mouseLocation = NSEvent.mouseLocation
            let deltaX = mouseLocation.x - initialMouseLocation.x
            let deltaY = mouseLocation.y - initialMouseLocation.y
            let distance = hypot(deltaX, deltaY)
            maximumDistance = max(maximumDistance, distance)

            if nextEvent.type == .leftMouseUp {
                mouseUpTimestamp = nextEvent.timestamp
                break
            }

            let duration = nextEvent.timestamp - event.timestamp
            if distance >= Gesture.dragThreshold
                || duration >= Gesture.maximumClickDuration
            {
                didDrag = true
            }
            if didDrag {
                window.setFrameOrigin(
                    NSPoint(
                        x: originalOrigin.x + deltaX,
                        y: originalOrigin.y + deltaY
                    )
                )
            }
        }

        let duration = mouseUpTimestamp - event.timestamp
        if !didDrag && Gesture.shouldToggle(
            duration: duration,
            distance: maximumDistance
        ) {
            onMouseDown?()
            onToggleScene?()
        }
    }

    override func accessibilityPerformPress() -> Bool {
        onMouseDown?()
        onToggleScene?()
        return true
    }

    func setScene(_ scene: BarScene) {
        self.scene = scene
        updateAppearance()
    }

    private func updateAppearance() {
        switch scene {
        case .mirror:
            imageView.image = NSImage(
                systemSymbolName: "square.grid.2x2",
                accessibilityDescription: "打开 Workspace"
            )
            toolTip = "点击打开 Workspace；长按拖动可调整位置"
            setAccessibilityLabel("打开 Workspace")
        case .workspace:
            imageView.image = NSImage(
                systemSymbolName: "rectangle.on.rectangle.slash",
                accessibilityDescription: "返回 Touch Bar 镜像"
            )
            toolTip = "点击返回 Touch Bar 镜像；长按拖动可调整位置"
            setAccessibilityLabel("返回 Touch Bar 镜像")
        }
    }
}

@MainActor
final class WorkspaceSwitcherWindowController: NSWindowController {
    static let size = NSSize(width: 48, height: 36)

    let switcherView: WorkspaceFloatingSwitcherView
    private(set) var hasRestoredFrame = false

    init() {
        switcherView = WorkspaceFloatingSwitcherView(
            frame: NSRect(origin: .zero, size: Self.size)
        )
        let panel = NSPanel(
            contentRect: switcherView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .none
        panel.contentView = switcherView
        panel.setFrameAutosaveName("ToubarReplaceWorkspaceSwitcherWindow")
        hasRestoredFrame = panel.setFrameUsingName(
            "ToubarReplaceWorkspaceSwitcherWindow"
        )
        panel.setContentSize(Self.size)
        super.init(window: panel)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func positionBesideMirror(_ mirrorWindow: NSWindow) {
        guard let window else { return }
        let gap: CGFloat = 8
        var origin = NSPoint(
            x: mirrorWindow.frame.minX - window.frame.width - gap,
            y: mirrorWindow.frame.midY - window.frame.height / 2
        )
        if origin.x < (mirrorWindow.screen?.visibleFrame.minX ?? 0) {
            origin.x = mirrorWindow.frame.maxX + gap
        }
        window.setFrameOrigin(origin)
    }
}

@MainActor
final class WorkspaceBarView: NSView {
    private let switcherButton = WorkspaceChromeButton()
    private let trayView = NSView()
    private let quotaPlate = QuotaPlateView()
    private let customAppsView = WorkspaceCustomAppsView()
    private let zoneDivider = NSView()

    var onToggleWorkspace: (() -> Void)?
    var onOpenSettings: (() -> Void)? {
        didSet { customAppsView.onOpenSettings = onOpenSettings }
    }
    var onOpenCustomApp: ((CustomWorkspaceApp) -> Void)? {
        didSet { customAppsView.onOpenCustomApp = onOpenCustomApp }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        switcherButton.image = NSImage(
            systemSymbolName: "chevron.backward",
            accessibilityDescription: "返回 Touch Bar 镜像"
        )
        switcherButton.contentTintColor = .white
        switcherButton.imageScaling = .scaleProportionallyDown
        switcherButton.imagePosition = .imageOnly
        switcherButton.target = self
        switcherButton.action = #selector(toggleWorkspace)
        switcherButton.toolTip = "点击返回 Touch Bar 镜像"
        switcherButton.setAccessibilityLabel("返回 Touch Bar 镜像")
        addSubview(switcherButton)

        trayView.wantsLayer = true
        trayView.layer?.backgroundColor =
            WorkspaceTouchBarStyle.trayBackground.cgColor
        trayView.layer?.cornerRadius = WorkspaceTouchBarStyle.trayCornerRadius
        addSubview(trayView)

        addSubview(quotaPlate)

        customAppsView.onOpenSettings = { [weak self] in
            self?.onOpenSettings?()
        }
        customAppsView.onOpenCustomApp = { [weak self] app in
            self?.onOpenCustomApp?(app)
        }
        addSubview(customAppsView)

        zoneDivider.wantsLayer = true
        zoneDivider.layer?.backgroundColor = WorkspaceTouchBarStyle
            .dividerColor.cgColor
        addSubview(zoneDivider)
        reloadCustomAppsFromPreferences()
        showQuota(.empty)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    func reloadCustomAppsFromPreferences() {
        customAppsView.display(apps: WorkspacePreferences.customApps)
        needsLayout = true
    }

    func showQuota(_ state: QuotaBoardState) {
        quotaPlate.display(state)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard bounds.width > 1, bounds.height > 1 else { return }

        let scale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        trayView.layer?.contentsScale = scale

        let strip = WorkspaceTouchBarLayout.stripFrames(in: bounds)
        switcherButton.frame = strip.switcher
        trayView.frame = strip.tray
        let quotaInner = WorkspaceTouchBarLayout.zoneContentRect(strip.quota)
        let plateHeight = max(
            strip.tray.height - WorkspaceTouchBarLayout.slotVerticalInset * 2,
            22
        )
        quotaPlate.frame = NSRect(
            x: quotaInner.minX,
            y: strip.tray.midY - plateHeight / 2,
            width: quotaInner.width,
            height: plateHeight
        )

        let appsInner = WorkspaceTouchBarLayout.zoneContentRect(strip.apps)
        customAppsView.frame = NSRect(
            x: appsInner.minX,
            y: strip.tray.minY,
            width: appsInner.width,
            height: strip.tray.height
        )

        let dividerHeight: CGFloat = 18
        zoneDivider.frame = NSRect(
            x: floor(
                strip.apps.minX
                    - WorkspaceTouchBarLayout.zoneDividerWidth / 2
            ),
            y: floor(strip.tray.midY - dividerHeight / 2),
            width: WorkspaceTouchBarLayout.zoneDividerWidth,
            height: dividerHeight
        )
    }

    @objc private func toggleWorkspace() {
        onToggleWorkspace?()
    }
}

@MainActor
final class TouchBarRootView: NSView {
    let surfaceView: TouchBarSurfaceView
    let workspaceView: WorkspaceBarView

    private let transitionCoverView = NSView(frame: .zero)
    private var transitionCoverTask: Task<Void, Never>?
    private(set) var scene: BarScene = .mirror
    private(set) var showsWorkspaceFallback = false

    override init(frame frameRect: NSRect) {
        surfaceView = TouchBarSurfaceView(frame: .zero)
        workspaceView = WorkspaceBarView(frame: .zero)
        super.init(frame: frameRect)
        autoresizingMask = [.width, .height]
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        surfaceView.autoresizingMask = [.width, .height]
        addSubview(surfaceView)
        workspaceView.autoresizingMask = [.width, .height]
        workspaceView.isHidden = true
        addSubview(workspaceView)

        transitionCoverView.wantsLayer = true
        transitionCoverView.layer?.contentsGravity = .resizeAspect
        transitionCoverView.layer?.backgroundColor = NSColor.black.cgColor
        transitionCoverView.autoresizingMask = [.width, .height]
        transitionCoverView.isHidden = true
        addSubview(transitionCoverView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func layout() {
        super.layout()
        let contentFrame = bounds
        surfaceView.frame = contentFrame
        workspaceView.frame = contentFrame
        transitionCoverView.frame = contentFrame
    }


    func beginSceneTransitionCover() {
        transitionCoverTask?.cancel()
        transitionCoverTask = nil
        transitionCoverView.layer?.removeAllAnimations()
        if let contents = surfaceView.currentFrameContents {
            transitionCoverView.layer?.contents = contents
        } else {
            transitionCoverView.layer?.contents = nil
        }
        transitionCoverView.alphaValue = 1
        transitionCoverView.isHidden = false

        addSubview(transitionCoverView, positioned: .above, relativeTo: nil)
    }


    func scheduleSceneTransitionCoverFade(
        settle: Duration = MirrorSceneTransition.settleDuration,
        fadeDuration: TimeInterval = MirrorSceneTransition.fadeDuration
    ) {
        transitionCoverTask?.cancel()
        transitionCoverTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: settle)
            guard !Task.isCancelled, let self else { return }
            guard !self.transitionCoverView.isHidden else { return }

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                NSAnimationContext.runAnimationGroup({ context in
                    context.duration = fadeDuration
                    context.allowsImplicitAnimation = true
                    self.transitionCoverView.animator().alphaValue = 0
                }, completionHandler: {
                    continuation.resume()
                })
            }

            guard !Task.isCancelled else { return }
            self.transitionCoverView.isHidden = true
            self.transitionCoverView.layer?.contents = nil
            self.transitionCoverView.alphaValue = 1
            self.transitionCoverTask = nil
        }
    }

    var mirrorViewportSize: CGSize {
        CGSize(
            width: max(bounds.width, 1),
            height: max(bounds.height, 1)
        )
    }

    func setScene(_ scene: BarScene) {
        self.scene = scene
        updateContentVisibility()
    }

    func setWorkspaceFallbackVisible(_ visible: Bool) {
        showsWorkspaceFallback = visible
        updateContentVisibility()
    }

    private func updateContentVisibility() {
        let showFallback = scene == .workspace && showsWorkspaceFallback
        surfaceView.isHidden = showFallback
        workspaceView.isHidden = !showFallback
    }
}
