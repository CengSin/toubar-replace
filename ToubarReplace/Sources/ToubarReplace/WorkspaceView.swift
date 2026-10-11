import AppKit

enum BarScene {
    case mirror
    case workspace
}

@MainActor
final class WorkspaceBarView: NSView {
    private let switcherButton = WorkspaceChromeButton()
    private let collapseButton = DesktopCapsuleButton(frame: .zero)
    private let trayView = NSView()
    private let quotaPlate = QuotaPlateView()
    private let customAppsView = WorkspaceCustomAppsView()
    private let zoneDivider = NSView()
    private(set) var desktopTheme: DesktopTheme = .black

    private var physicalQuotaScrollState: QuotaScrollState?
    private var mirrorsPhysicalQuotaScroll = false

    func apply(theme: DesktopTheme) {
        desktopTheme = theme
        layer?.backgroundColor = (theme == .glass ? NSColor.clear : .black).cgColor
        trayView.layer?.backgroundColor = (theme == .glass ? NSColor.clear : WorkspaceTouchBarStyle.trayBackground).cgColor
        switcherButton.desktopTheme = theme
        collapseButton.apply(theme: theme)
        quotaPlate.setDesktopTheme(theme)
        customAppsView.setDesktopTheme(theme)
        effectiveAppearance.performAsCurrentDrawingAppearance {
            zoneDivider.layer?.backgroundColor = (theme == .glass ? NSColor.separatorColor : WorkspaceTouchBarStyle.dividerColor).cgColor
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance { apply(theme: desktopTheme) }
    }

    var onToggleWorkspace: (() -> Void)?
    var onCollapse: (() -> Void)?
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
        collapseButton.setSymbol("chevron.down", label: "隐藏 ToubarReplace", tooltip: "使用 Touch Bar 隐藏键或状态栏菜单")
        collapseButton.onPress = { [weak self] in self?.onCollapse?() }
        addSubview(collapseButton)

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
        customAppsView.setDesktopTheme(desktopTheme)
        needsLayout = true
    }

    func showQuota(_ state: QuotaBoardState) {
        quotaPlate.display(state)
        quotaPlate.setDesktopTheme(desktopTheme)
        needsLayout = true
    }

    func mirrorQuotaScrollState(_ state: QuotaScrollState) {
        physicalQuotaScrollState = state
        if mirrorsPhysicalQuotaScroll { quotaPlate.mirrorScrollState(state) }
    }

    func setMirrorsPhysicalQuotaScroll(_ enabled: Bool) {
        guard mirrorsPhysicalQuotaScroll != enabled else { return }
        mirrorsPhysicalQuotaScroll = enabled
        quotaPlate.mirrorScrollState(enabled ? physicalQuotaScrollState : nil)
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
        collapseButton.frame = strip.collapse
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

    private let transitionCoverView = TouchBarSurfaceView(frame: .zero)
    private var transitionCoverTask: Task<Void, Never>?
    private var transitionOriginalFrame: CGImage?
    private var mirrorReturnTask: Task<Void, Never>?
    private var retainedMirrorOriginal: CGImage?
    private var retainedMirrorRendered: CGImage?
    private var retainedMirrorAppearance: NSAppearance.Name?
    private var retainedMirrorSignature: TouchBarFrameSignature?
    private var workspaceCaptureSignature: TouchBarFrameSignature?
    private var lastWorkspaceFrameSignature: TouchBarFrameSignature?
    private var functionKeyFrameSignature: TouchBarFrameSignature?
    private var functionKeyOriginalFrame: CGImage?
    private var mirrorCaptureGuardUntil: ContinuousClock.Instant?
    private var pendingMirrorCapture: CGImage?
    private(set) var isWaitingForMirrorCapture = false
    private(set) var scene: BarScene = .mirror
    private(set) var showsWorkspaceFallback = false
    private(set) var desktopTheme: DesktopTheme = .black
    private(set) var hasCaptureDiagnostic = false
    private(set) var isFunctionKeyPressed = false
    private(set) var showsFunctionKeyCapture = false
    var suppressesCapture = false

    func displayCapture(image: CGImage) {
        guard !suppressesCapture else { return }
        if scene == .workspace && !showsWorkspaceFallback,
           let signature = TouchBarFrameSignature(image: image) {
            if isFunctionKeyPressed {
                let isOldWorkspace = lastWorkspaceFrameSignature.map { signature.resembles($0) } == true
                if desktopTheme == .glass && isOldWorkspace {
                    if hasCaptureDiagnostic {
                        hasCaptureDiagnostic = false
                        surfaceView.clearFrame()
                        updateContentVisibility()
                    }
                    return
                }
                if !isOldWorkspace {
                    functionKeyOriginalFrame = image
                    functionKeyFrameSignature = signature
                }
            } else if functionKeyFrameSignature.map({ !signature.resembles($0) }) ?? true {
                lastWorkspaceFrameSignature = signature
                if desktopTheme == .glass,
                   retainedMirrorSignature.map({ !signature.resembles($0) }) ?? true {
                    workspaceCaptureSignature = signature
                }
            }
        }
        if desktopTheme == .glass && scene == .mirror
            && (isWaitingForMirrorCapture || workspaceCaptureSignature != nil) {
            if let deadline = mirrorCaptureGuardUntil, ContinuousClock.now >= deadline {
                workspaceCaptureSignature = nil
                mirrorCaptureGuardUntil = nil
            }
            if let signature = TouchBarFrameSignature(image: image),
               workspaceCaptureSignature.map({ signature.resembles($0) }) == true { return }
            if isWaitingForMirrorCapture {
                pendingMirrorCapture = image
                return
            }
        }
        hasCaptureDiagnostic = false
        surfaceView.display(image: image)
        updateContentVisibility()
    }

    func displayCapture(notice: TouchBarCaptureNotice) {
        guard !suppressesCapture else { return }
        cancelMirrorReturn()
        hasCaptureDiagnostic = true
        showsFunctionKeyCapture = false
        updateContentVisibility()
        surfaceView.display(notice: notice)
    }

    func displayCapture(error: TouchBarCaptureError) {
        guard !suppressesCapture else { return }
        cancelMirrorReturn()
        hasCaptureDiagnostic = true
        showsFunctionKeyCapture = false
        updateContentVisibility()
        surfaceView.display(error: error)
    }

    private func cancelMirrorReturn() {
        mirrorReturnTask?.cancel()
        mirrorReturnTask = nil
        isWaitingForMirrorCapture = false
        pendingMirrorCapture = nil
    }

    func apply(theme: DesktopTheme) {
        let changed = desktopTheme != theme
        desktopTheme = theme
        if changed {
            showsFunctionKeyCapture = false
            if theme == .glass && scene == .workspace && !showsWorkspaceFallback {
                surfaceView.setRenderingEnabled(false)
            }
        }
        layer?.backgroundColor = (theme == .glass ? NSColor.clear : .black).cgColor
        surfaceView.apply(theme: theme)
        workspaceView.apply(theme: theme)
        transitionCoverView.apply(theme: theme)
        if changed { retainedMirrorRendered = nil }
        if theme == .glass {
            clearSceneTransitionCover()
        } else {
            mirrorReturnTask?.cancel()
            mirrorReturnTask = nil
            isWaitingForMirrorCapture = false
            workspaceCaptureSignature = nil
            mirrorCaptureGuardUntil = nil
            if let image = pendingMirrorCapture { surfaceView.display(image: image) }
            pendingMirrorCapture = nil
            if !transitionCoverView.isHidden { updateTransitionFrame() }
        }
        updateContentVisibility()
    }

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
        surfaceView.onGlassFrameDisplayed = { [weak self] in
            self?.handleGlassFrameDisplayed()
        }
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
        mirrorReturnTask?.cancel()
        mirrorReturnTask = nil
        pendingMirrorCapture = nil
        isWaitingForMirrorCapture = false
        if desktopTheme == .glass {
            clearSceneTransitionCover()
            if scene == .mirror {
                retainedMirrorOriginal = surfaceView.latestOriginalFrame
                retainedMirrorRendered = surfaceView.currentFrameContents
                retainedMirrorAppearance = surfaceView.effectiveAppearance.name
                retainedMirrorSignature = retainedMirrorOriginal.flatMap(TouchBarFrameSignature.init(image:))
                workspaceCaptureSignature = nil
                mirrorCaptureGuardUntil = nil
            } else {
                isWaitingForMirrorCapture = !showsWorkspaceFallback && !hasCaptureDiagnostic
                mirrorCaptureGuardUntil = ContinuousClock.now.advanced(by: .seconds(1))
            }
            return
        }
        transitionCoverTask?.cancel()
        transitionCoverTask = nil
        transitionCoverView.layer?.removeAllAnimations()
        transitionOriginalFrame = surfaceView.latestOriginalFrame
        updateTransitionFrame()
        transitionCoverView.alphaValue = 1
        transitionCoverView.isHidden = false
        addSubview(transitionCoverView, positioned: .above, relativeTo: nil)
    }

    private func updateTransitionFrame() {
        if let image = transitionOriginalFrame { transitionCoverView.display(image: image) }
        else { transitionCoverView.clearFrame() }
    }

    private func clearSceneTransitionCover() {
        transitionCoverTask?.cancel()
        transitionCoverTask = nil
        transitionCoverView.layer?.removeAllAnimations()
        transitionCoverView.isHidden = true
        transitionCoverView.clearFrame()
        transitionOriginalFrame = nil
        transitionCoverView.alphaValue = 1
    }

    func scheduleSceneTransitionCoverFade(
        settle: Duration = MirrorSceneTransition.settleDuration,
        fadeDuration: TimeInterval = MirrorSceneTransition.fadeDuration
    ) {
        if desktopTheme == .glass {
            guard isWaitingForMirrorCapture else { return }
            mirrorReturnTask?.cancel()
            mirrorReturnTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: settle)
                guard !Task.isCancelled, let self,
                      self.scene == .mirror, self.desktopTheme == .glass else { return }
                self.isWaitingForMirrorCapture = false
                self.mirrorReturnTask = nil
                if let image = self.pendingMirrorCapture {
                    self.pendingMirrorCapture = nil
                    self.displayCapture(image: image)
                }
            }
            return
        }
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
                }, completionHandler: { continuation.resume() })
            }
            guard !Task.isCancelled else { return }
            self.clearSceneTransitionCover()
        }
    }

    var mirrorViewportSize: CGSize {
        CGSize(
            width: max(bounds.width, 1),
            height: max(bounds.height, 1)
        )
    }

    func setScene(_ scene: BarScene) {
        if self.scene != scene {
            showsFunctionKeyCapture = false
            if scene == .workspace && desktopTheme == .glass && !showsWorkspaceFallback {
                surfaceView.setRenderingEnabled(false)
            }
        }
        self.scene = scene
        updateContentVisibility()
        if scene == .mirror && desktopTheme == .glass && isWaitingForMirrorCapture {
            let rendered = retainedMirrorAppearance == surfaceView.effectiveAppearance.name
                ? retainedMirrorRendered : nil
            surfaceView.restoreFrame(original: retainedMirrorOriginal, rendered: rendered)
        }
    }

    func setWorkspaceFallbackVisible(_ visible: Bool) {
        if showsWorkspaceFallback != visible { showsFunctionKeyCapture = false }
        showsWorkspaceFallback = visible
        updateContentVisibility()
    }

    func setFunctionKeyPressed(_ pressed: Bool) {
        guard isFunctionKeyPressed != pressed else { return }
        isFunctionKeyPressed = pressed
        showsFunctionKeyCapture = false
        updateContentVisibility()
    }

    private func handleGlassFrameDisplayed() {
        guard scene == .workspace, desktopTheme == .glass, !showsWorkspaceFallback,
              isFunctionKeyPressed, !hasCaptureDiagnostic, !showsFunctionKeyCapture,
              let original = surfaceView.latestOriginalFrame,
              original === functionKeyOriginalFrame else { return }
        showsFunctionKeyCapture = true
        updateContentVisibility()
    }

    private func updateContentVisibility() {
        let showFallback = scene == .workspace
            && (showsWorkspaceFallback
                || (desktopTheme == .glass && !hasCaptureDiagnostic && !showsFunctionKeyCapture))
        let preparesFunctionKeys = scene == .workspace && desktopTheme == .glass
            && !showsWorkspaceFallback && isFunctionKeyPressed && !hasCaptureDiagnostic
            && !showsFunctionKeyCapture
        let hasRetainedFunctionKeys = surfaceView.latestOriginalFrame != nil
            && surfaceView.latestOriginalFrame === functionKeyOriginalFrame
        workspaceView.setMirrorsPhysicalQuotaScroll(showFallback && !showsWorkspaceFallback)
        surfaceView.isHidden = showFallback
        surfaceView.setRenderingEnabled(!showFallback || preparesFunctionKeys,
            reprocessRetainedFrame: !preparesFunctionKeys || hasRetainedFunctionKeys)
        workspaceView.isHidden = !showFallback
    }
}
