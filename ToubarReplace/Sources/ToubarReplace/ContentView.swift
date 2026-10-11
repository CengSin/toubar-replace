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
    private(set) var latestOriginalFrame: CGImage?
    private var displayedFrame: CGImage?
    private(set) var desktopTheme: DesktopTheme = .black
    private var frameGeneration: UInt64 = 0
    private var frameSequence: UInt64 = 0
    private var deliveredSequence: UInt64 = 0
    private var renderingEnabled = true
    private var latestFrameIsComposed = false
    var onGlassFrameDisplayed: (() -> Void)?
    var hasVisibleDiagnostic: Bool { !statusLabel.isHidden }
    private lazy var glassPipeline = MirrorGlassFramePipeline { [weak self] image, token in
        guard let self, self.desktopTheme == .glass,
              token.canDeliver(currentGeneration: self.frameGeneration,
                               deliveredSequence: self.deliveredSequence) else { return }
        self.deliveredSequence = token.sequence
        self.replaceFrameContents(image)
        self.onGlassFrameDisplayed?()
    }

    override init(frame frameRect: NSRect) {
        statusLabel = NSTextField(labelWithString: "正在读取 Touch Bar…")
        imageView = NSView(frame: .zero)
        super.init(frame: frameRect)

        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        imageView.wantsLayer = true
        imageView.layer?.contentsGravity = .resizeAspect
        imageView.layer?.minificationFilter = .trilinear
        imageView.layer?.magnificationFilter = .linear
        updateContentsScale()
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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateContentsScale()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateContentsScale()
    }

    private func updateContentsScale() {
        imageView.layer?.contentsScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
    }

    private func replaceFrameContents(_ image: CGImage?) {
        displayedFrame = image
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        imageView.layer?.contents = image
        CATransaction.commit()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        guard desktopTheme == .glass else { return }
        frameGeneration &+= 1
        glassPipeline.discardPending()
        if let image = latestOriginalFrame { display(image: image, alreadyComposed: latestFrameIsComposed, keepsDiagnostic: true) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func display(image: CGImage, alreadyComposed: Bool = false, keepsDiagnostic: Bool = false) {
        latestOriginalFrame = image
        latestFrameIsComposed = alreadyComposed
        frameSequence &+= 1
        if desktopTheme == .glass && keepsDiagnostic && hasVisibleDiagnostic {
            imageView.isHidden = true
            return
        }
        imageView.isHidden = false
        if !keepsDiagnostic { statusLabel.isHidden = true }
        guard renderingEnabled else { return }
        if desktopTheme == .glass && !alreadyComposed {
            glassPipeline.submit(image, token: MirrorGlassFrameToken(
                generation: frameGeneration, sequence: frameSequence
            ), appearance: effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light)
        } else {
            replaceFrameContents(image)
            deliveredSequence = frameSequence
        }
    }

    func apply(theme: DesktopTheme) {
        guard desktopTheme != theme else { return }
        desktopTheme = theme
        frameGeneration &+= 1
        glassPipeline.discardPending()
        layer?.backgroundColor = (theme == .glass ? NSColor.clear : .black).cgColor
        statusLabel.textColor = theme == .glass ? .labelColor : .white
        replaceFrameContents(nil)
        if let image = latestOriginalFrame { display(image: image, alreadyComposed: latestFrameIsComposed, keepsDiagnostic: true) }
    }

    func setRenderingEnabled(_ enabled: Bool, reprocessRetainedFrame: Bool = true) {
        guard renderingEnabled != enabled else { return }
        renderingEnabled = enabled
        frameGeneration &+= 1
        glassPipeline.discardPending()
        replaceFrameContents(nil)
        if enabled && reprocessRetainedFrame, let image = latestOriginalFrame {
            display(image: image, alreadyComposed: latestFrameIsComposed, keepsDiagnostic: true)
        }
    }

    func clearFrame() {
        frameGeneration &+= 1
        glassPipeline.discardPending()
        latestOriginalFrame = nil
        latestFrameIsComposed = false
        replaceFrameContents(nil)
        imageView.isHidden = true
        statusLabel.isHidden = true
    }

    func restoreFrame(original: CGImage?, rendered: CGImage?) {
        clearFrame()
        guard let original else { return }
        latestOriginalFrame = original
        if desktopTheme == .glass, let rendered {
            replaceFrameContents(rendered)
            imageView.isHidden = false
        } else {
            display(image: original)
        }
    }


    var currentFrameContents: CGImage? {
        displayedFrame
    }

    private func hideGlassImageForDiagnostic() {
        guard desktopTheme == .glass else { return }
        frameGeneration &+= 1
        glassPipeline.discardPending()
        replaceFrameContents(nil)
        imageView.isHidden = true
    }

    func display(notice: TouchBarCaptureNotice) {
        statusLabel.font = .systemFont(ofSize: 10, weight: .medium)
        statusLabel.stringValue = notice.description
        statusLabel.toolTip = notice.description
        statusLabel.isHidden = false
        hideGlassImageForDiagnostic()
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
        hideGlassImageForDiagnostic()
        addSubview(statusLabel, positioned: .above, relativeTo: imageView)
    }


    func displaySoftwareWorkspaceIdle() {
        clearFrame()
        statusLabel.font = .systemFont(ofSize: 11, weight: .medium)
        statusLabel.stringValue = """
        当前 Mac 无物理 Touch Bar
        从状态栏菜单打开 Workspace，查看额度并启动应用
        """
        statusLabel.toolTip = statusLabel.stringValue
        statusLabel.isHidden = false
        addSubview(statusLabel, positioned: .above, relativeTo: imageView)
    }
}

@MainActor
final class TouchBarWindowController: NSWindowController, NSWindowDelegate {
    private let rootView: TouchBarRootView
    private let desktopHost: DesktopGlassHostView
    private let capture: TouchBarCapture
    private let capsuleView: DesktopCapsuleView
    private let capsuleController: DesktopCapsuleController
    private let functionKeyMonitor: TouchBarFunctionKeyMonitor
    private let quotaStore = QuotaSnapshotStore()
    private let workspaceTouchBarController = WorkspaceTouchBarController()
    private let switcherTouchBarController = SwitcherTouchBarController()
    private let wakeTouchBarController = DesktopWakeTouchBarController()
    private var isSynchronizingTouchBar = false

    private var hasRestoredFrame = false
    private var workspaceObservers: [NSObjectProtocol] = []
    private var resumeToWorkspace = false


    private var isHardwareSessionPaused = false
    private var isRunning = false
    private var workspaceGeneration: UInt64 = 0
    private var quotaRefreshTask: Task<Void, Never>?
    private var physicalWorkspacePresentationTask: Task<Void, Never>?


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
        capsuleView = DesktopCapsuleView(content: rootView)
        desktopHost = DesktopGlassHostView(content: capsuleView, usesCapsuleShape: true)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialMirrorSize),
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


        panel.isMovableByWindowBackground = false
        panel.ignoresMouseEvents = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.minSize = DesktopCapsuleLayout.minimumSize
        panel.animationBehavior = .none
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.contentView = desktopHost

        panel.setFrameAutosaveName(TouchBarPreferences.mirrorWindowAutosaveName)
        var restoredFrame = false
        if TouchBarPreferences.displayPosition.restoresAutosavedFrame {
            restoredFrame = panel.setFrameUsingName(
                TouchBarPreferences.mirrorWindowAutosaveName
            )
        }
        panel.setContentSize(initialMirrorSize)

        capsuleController = DesktopCapsuleController(window: panel, view: capsuleView)
        let functionKeyMonitor = TouchBarFunctionKeyMonitor { [weak rootView] isPressed in
            rootView?.setFunctionKeyPressed(isPressed)
        }
        self.functionKeyMonitor = functionKeyMonitor
        let frameDelivery = TouchBarFrameDeliveryCoalescer {
            [weak rootView, weak functionKeyMonitor] image in
            functionKeyMonitor?.refresh()
            rootView?.displayCapture(image: image)
        }
        capture = TouchBarCapture(
            onFrame: { image in
                frameDelivery.submit(image)
            },
            onNotice: { [weak rootView] notice in
                Task { @MainActor in
                    rootView?.displayCapture(notice: notice)
                }
            },
            onError: { [weak rootView] error in
                Task { @MainActor in
                    rootView?.displayCapture(error: error)
                }
            }
        )

        super.init(window: panel)
        hasRestoredFrame = restoredFrame
        panel.delegate = self
        capsuleController.onExpansionChanged = { [weak self] _ in self?.synchronizePhysicalTouchBar() }
        capsuleController.onAnimationStarted = { [weak self] in self?.synchronizePhysicalTouchBar() }
        capsuleController.onAnimationCompleted = { [weak self] in self?.synchronizePhysicalTouchBar() }
        wakeTouchBarController.onWake = { [weak self] in
            guard let self, self.isRunning, !self.capsuleController.isExpanded else { return }
            self.capsuleController.show()
        }
        wakeTouchBarController.onTouchReleased = { [weak self] in self?.synchronizePhysicalTouchBar() }
        wakeTouchBarController.onPresentationInterrupted = { [weak self] in self?.synchronizePhysicalTouchBar() }
        installWorkspaceActions()
        configureDesktopCapsule()
        installWorkspaceObservers()
        persistCurrentPixelSize()
        reloadDesktopTheme()
    }

    func reloadDesktopTheme() {
        let theme = DesktopThemePolicy.current
        window?.backgroundColor = .clear
        desktopHost.apply(theme: theme)
        rootView.apply(theme: theme)
        capsuleView.apply(theme: theme)
        configureDesktopCapsule()
        updateFunctionKeyMonitoring()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        if workspaceObservers.isEmpty { installWorkspaceObservers() }

        if !(displayPosition.restoresAutosavedFrame && hasRestoredFrame) {
            positionWindow()
        }
        configureDesktopCapsule()
        capsuleController.start()

        let enterWorkspace =
            SoftwareWorkspaceLaunchPolicy.shouldEnterWorkspaceAtLaunch(
                usesSoftwareWorkspace: usesSoftwareWorkspace,
                preferredScene: WorkspacePreferences.startupScene
            )
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
            updateDesktopInteraction()
        }
        configureDesktopCapsule()
        synchronizePhysicalTouchBar()
    }

    func stop() {
        isRunning = false
        cancelWorkspaceAsyncWork(invalidateSession: true)
        workspaceTouchBarController.dismiss()
        switcherTouchBarController.dismiss()
        wakeTouchBarController.dismiss()
        capsuleController.stop()
        functionKeyMonitor.stop()
        capture.stop()
        let center = NSWorkspace.shared.notificationCenter
        workspaceObservers.forEach(center.removeObserver)
        workspaceObservers.removeAll()
    }

    func setDisplayPosition(_ position: TouchBarDisplayPosition) {
        displayPosition = position
        TouchBarPreferences.displayPosition = position
        if position.restoresAutosavedFrame, let window,
           window.setFrameUsingName(TouchBarPreferences.mirrorWindowAutosaveName) {
            hasRestoredFrame = true
            capsuleController.setExpanded(capsuleController.isExpanded, animated: false)
            return
        }
        hasRestoredFrame = false
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
        if wakeTouchBarController.isPresented { wakeTouchBarController.present() }
        else { switcherTouchBarController.suppressCloseBox() }
    }


    func ensurePhysicalSwitcherPresented() {
        synchronizePhysicalTouchBar()
        suppressPhysicalSwitcherCloseBox()
    }

    func toggleDesktopCapsule() {
        capsuleController.toggle()
    }

    var mirrorPixelSize: CGSize { TouchBarPreferences.mirrorPixelSize }

    func setMirrorPixelSize(_ pixelSize: CGSize) {
        TouchBarPreferences.mirrorPixelSize = CGSize(
            width: max(pixelSize.width.rounded(), 1),
            height: max(pixelSize.height.rounded(), 1)
        )
        configureDesktopCapsule()
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
        configureDesktopCapsule()
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

    func windowDidChangeScreen(_ notification: Notification) {
        configureDesktopCapsule()
    }

    func positionWindow() {
        guard let window else { return }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let visibleFrame = screen.visibleFrame
        let frame = window.frame
        let mirrorSize = capsuleView.expandedSize
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
        let mirrorX = visibleFrame.midX - mirrorPointSize.width / 2
        let bottomY = screen?.frame.minY ?? 0
        return CGPoint(x: mirrorX, y: bottomY + mirrorPointSize.height)
    }

    private func persistCurrentPixelSize() {
        let pixelSize = mirrorPixelSize
        TouchBarPreferences.mirrorPixelSize = pixelSize
        onPixelSizeChanged?(pixelSize)
    }

    private func installWorkspaceActions() {
        rootView.workspaceView.onCollapse = { [weak self] in self?.capsuleController.setExpanded(false) }
        workspaceTouchBarController.onCollapse = { [weak self] in self?.capsuleController.setExpanded(false) }
        switcherTouchBarController.onCollapse = { [weak self] in self?.capsuleController.setExpanded(false) }
        workspaceTouchBarController.onQuotaScrollStateChanged = { [weak self] state in
            self?.rootView.workspaceView.mirrorQuotaScrollState(state)
        }
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
        if !usesSoftwareWorkspace { return .touchBar }
        return SoftwareWorkspaceLaunchPolicy.effectiveSwitcherDisplayMode(
            usesSoftwareWorkspace: usesSoftwareWorkspace,
            preferred: WorkspacePreferences.switcherDisplayMode,
            scene: rootView.scene
        )
    }

    private func updateDesktopInteraction() {
        let softwareControls = (usesSoftwareWorkspace || forceFloatingSwitcher)
            && (rootView.scene == .mirror || rootView.showsWorkspaceFallback)
        let ignores = DesktopTouchBarPolicy.ignoresPointer(expanded: capsuleController.isExpanded,
            animating: capsuleController.isAnimating, softwareControls: softwareControls)
        window?.ignoresMouseEvents = ignores
        capsuleView.contentAcceptsMouseEvents = !ignores
        updateFunctionKeyMonitoring()
    }

    private func updateFunctionKeyMonitoring() {
        if isRunning && !isHardwareSessionPaused && !usesSoftwareWorkspace
            && desktopTouchBarPresentation == .scene
            && rootView.scene == .workspace
            && !rootView.showsWorkspaceFallback {
            functionKeyMonitor.start()
        } else {
            functionKeyMonitor.stop()
        }
    }

    private func configureDesktopCapsule() {
        let leftAnchor = window.map {
            CGPoint(x: $0.frame.minX + 1, y: $0.frame.minY + 1)
        }
        let screen = leftAnchor.flatMap { point in NSScreen.screens.first { $0.frame.contains(point) } }
            ?? window?.screen ?? NSScreen.main
        capsuleController.configure(
            pixelSize: TouchBarPreferences.mirrorPixelSize,
            backingScaleFactor: screen?.backingScaleFactor ?? 2
        )
    }

    private var desktopTouchBarPresentation: DesktopTouchBarPresentation {
        DesktopTouchBarPolicy.presentation(running: isRunning, paused: isHardwareSessionPaused,
            expanded: capsuleController.isExpanded, animating: capsuleController.isAnimating,
            trackingWakeTouch: wakeTouchBarController.isTrackingTouch)
    }

    private func synchronizePhysicalTouchBar() {
        guard !isSynchronizingTouchBar else { return }
        isSynchronizingTouchBar = true
        defer {
            isSynchronizingTouchBar = false
            updateDesktopInteraction()
        }
        guard !usesSoftwareWorkspace else { return }
        switch desktopTouchBarPresentation {
        case .inactive:
            wakeTouchBarController.dismiss()
            workspaceTouchBarController.dismiss()
            switcherTouchBarController.dismiss()
            capture.stop()
        case .wake:
            physicalWorkspacePresentationTask?.cancel()
            physicalWorkspacePresentationTask = nil
            rootView.suppressesCapture = true
            capture.pause()
            workspaceTouchBarController.dismiss()
            switcherTouchBarController.dismiss()
            wakeTouchBarController.present()
        case .scene:
            wakeTouchBarController.dismiss()
            if rootView.scene == .workspace {
                if !workspaceTouchBarController.isPresented {
                    completeHardwareWorkspacePresentation(isLaunch: true)
                }
            } else {
                presentPhysicalSwitcherIfNeeded()
            }
            rootView.suppressesCapture = false
            capture.start()
        }
    }

    private func presentPhysicalSwitcherIfNeeded() {
        guard isRunning, rootView.scene == .mirror else { return }
        guard desktopTouchBarPresentation == .scene else { synchronizePhysicalTouchBar(); return }
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
        switcherTouchBarController.dismiss()
        rootView.setWorkspaceFallbackVisible(true)
        updateDesktopInteraction()

        refreshQuotaDisplay()
        configureDesktopCapsule()
        if !isLaunch {
            rootView.scheduleSceneTransitionCoverFade()
        }
    }

    func toggleWorkspace() {
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
        let generation = beginWorkspaceSession()
        if !isLaunch {
            rootView.beginSceneTransitionCover()
        }
        rootView.setScene(.workspace)
        switcherTouchBarController.dismiss()
        guard desktopTouchBarPresentation == .scene else {
            rootView.setWorkspaceFallbackVisible(true)
            refreshQuotaDisplay()
            configureDesktopCapsule()
            synchronizePhysicalTouchBar()
            return
        }

        if rootView.desktopTheme == .glass {
            rootView.setWorkspaceFallbackVisible(false)
            updateDesktopInteraction()
            configureDesktopCapsule()
            physicalWorkspacePresentationTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(17))
                guard !Task.isCancelled, let self,
                      self.canUpdateWorkspace(from: generation) else { return }
                self.physicalWorkspacePresentationTask = nil
                self.completeHardwareWorkspacePresentation(isLaunch: isLaunch)
            }
        } else {
            completeHardwareWorkspacePresentation(isLaunch: isLaunch)
        }
    }

    private func completeHardwareWorkspacePresentation(isLaunch: Bool) {
        guard desktopTouchBarPresentation == .scene else { return }
        do {
            try workspaceTouchBarController.present()
            forceFloatingSwitcher = false
            rootView.setWorkspaceFallbackVisible(false)
            updateDesktopInteraction()
        } catch {
            forceFloatingSwitcher = true
            rootView.setWorkspaceFallbackVisible(true)
            updateDesktopInteraction()
            configureDesktopCapsule()
            refreshQuotaDisplay()
            if !isLaunch {
                rootView.scheduleSceneTransitionCoverFade()
            }
            return
        }

        refreshQuotaDisplay()
        rootView.suppressesCapture = false
        capture.start()
        configureDesktopCapsule()
        if !isLaunch {
            rootView.scheduleSceneTransitionCoverFade()
        }
    }

    private func closeWorkspace() {
        cancelWorkspaceAsyncWork(invalidateSession: true)
        rootView.beginSceneTransitionCover()
        if rootView.desktopTheme == .glass {
            rootView.setWorkspaceFallbackVisible(false)
            rootView.setScene(.mirror)
        }
        if !usesSoftwareWorkspace {
            workspaceTouchBarController.dismiss()
        }
        rootView.setWorkspaceFallbackVisible(false)
        rootView.setScene(.mirror)
        if usesSoftwareWorkspace {
            rootView.surfaceView.displaySoftwareWorkspaceIdle()
        }
        updateDesktopInteraction()
        forceFloatingSwitcher = false
        configureDesktopCapsule()
        presentPhysicalSwitcherIfNeeded()
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
        presentPhysicalSwitcherIfNeeded()
        updateDesktopInteraction()
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
        physicalWorkspacePresentationTask?.cancel()
        physicalWorkspacePresentationTask = nil
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
                        self.wakeTouchBarController.dismiss()
                        self.updateFunctionKeyMonitoring()
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
                        self.rootView.suppressesCapture = true
                        self.capture.pause()
                        self.wakeTouchBarController.dismiss()
                        self.workspaceTouchBarController.dismiss()
                        self.switcherTouchBarController.dismiss()
                        self.isHardwareSessionPaused = false
                        if self.usesSoftwareWorkspace {
                            if self.rootView.scene != .workspace {
                                self.enterSoftwareWorkspace(isLaunch: true)
                            }
                        } else if self.resumeToWorkspace && self.rootView.scene != .workspace {
                            self.enterHardwareWorkspace(isLaunch: true)
                        }
                        self.resumeToWorkspace = false
                        self.synchronizePhysicalTouchBar()
                    }
                }
            )
        }

    }
}
