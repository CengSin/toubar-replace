import AppKit
import TouchBarPrivateAPI

enum WorkspaceTouchBarLayout {
    static let presentationMode = "app"
    static let placement: Int64 = 1

    static let minimumContentWidth: CGFloat = 400



    static let designReferenceBarWidth: CGFloat = 1_010



    static let maximumContentWidth: CGFloat = 1_010





    static func preferredContentSize(
        mirrorPixelSize: CGSize = TouchBarPreferences.mirrorPixelSize,
        backingScaleFactor: CGFloat = NSScreen.main?.backingScaleFactor ?? 2
    ) -> CGSize {
        let points = TouchBarWindowMetrics.pointSize(
            forPixelSize: mirrorPixelSize,
            backingScaleFactor: backingScaleFactor
        )
        let width = min(
            max(points.width, minimumContentWidth),
            maximumContentWidth
        )
        return CGSize(
            width: width,
            height: max(points.height, 1)
        )
    }

    static func preferredContentWidth(
        mirrorPixelSize: CGSize = TouchBarPreferences.mirrorPixelSize,
        backingScaleFactor: CGFloat = NSScreen.main?.backingScaleFactor ?? 2
    ) -> CGFloat {
        preferredContentSize(
            mirrorPixelSize: mirrorPixelSize,
            backingScaleFactor: backingScaleFactor
        ).width
    }




    static let switcherWidth: CGFloat = 44
    static let switcherContentGap: CGFloat = 10


    static func preferredTrayWidth(
        mirrorPixelSize: CGSize = TouchBarPreferences.mirrorPixelSize,
        backingScaleFactor: CGFloat = NSScreen.main?.backingScaleFactor ?? 2
    ) -> CGFloat {
        let full = preferredContentWidth(
            mirrorPixelSize: mirrorPixelSize,
            backingScaleFactor: backingScaleFactor
        )
        return max(
            full - switcherWidth - switcherContentGap,
            minimumContentWidth - switcherWidth - switcherContentGap
        )
    }


    static let totalUnits = 10
    static let quotaUnits = 7
    static let appsUnits = 3


    static let zoneDividerWidth: CGFloat = 1

    static let zoneContentInset: CGFloat = 6

    static let slotVerticalInset: CGFloat = 3


    static let trayTrailingSafeInset: CGFloat = 12


    static let quotaGroupMinimumWidth: CGFloat = 144

    static let quotaGroupTwoBarMinimumWidth: CGFloat = 104
    static let quotaGroupSpacing: CGFloat = 4

    static func quotaGroupMinimumWidth(showsFiveHour: Bool) -> CGFloat {
        showsFiveHour ? quotaGroupMinimumWidth : quotaGroupTwoBarMinimumWidth
    }


    static func trayZoneFrames(
        tray: NSRect,
        quotaShare: Double = WorkspacePreferences.quotaShare
    ) -> (quota: NSRect, apps: NSRect) {
        let usableWidth = max(tray.width - trayTrailingSafeInset, 0)
        let quotaWidth = floor(
            usableWidth * CGFloat(WorkspacePreferences.clampedQuotaShare(quotaShare))
        )
        let appsWidth = max(usableWidth - quotaWidth, 0)
        let quota = NSRect(
            x: tray.minX,
            y: tray.minY,
            width: quotaWidth,
            height: tray.height
        )
        let apps = NSRect(
            x: quota.maxX,
            y: tray.minY,
            width: appsWidth,
            height: tray.height
        )
        return (quota, apps)
    }


    static func stripFrames(
        in bounds: NSRect
    ) -> (
        switcher: NSRect,
        tray: NSRect,
        quota: NSRect,
        apps: NSRect
    ) {
        let height = min(
            WorkspaceTouchBarStyle.controlHeight,
            max(bounds.height, 1)
        )
        let y = bounds.midY - height / 2
        let inset = WorkspaceTouchBarStyle.canvasInset
        let switcher = NSRect(
            x: bounds.minX + inset,
            y: y,
            width: switcherWidth,
            height: height
        )
        let trayX = switcher.maxX + switcherContentGap
        let trayWidth = max(
            bounds.maxX - inset - trayX,
            0
        )
        let tray = NSRect(
            x: trayX,
            y: y,
            width: trayWidth,
            height: height
        )
        let zones = trayZoneFrames(tray: tray)
        return (switcher, tray, zones.quota, zones.apps)
    }


    static func trayFrame(in bounds: NSRect) -> NSRect {
        let height = min(
            WorkspaceTouchBarStyle.controlHeight,
            max(bounds.height, 1)
        )
        let inset = WorkspaceTouchBarStyle.canvasInset
        return NSRect(
            x: bounds.minX + inset,
            y: bounds.midY - height / 2,
            width: max(bounds.width - inset * 2, 0),
            height: height
        )
    }


    static func customSlotCount(appCount: Int) -> Int {
        let count = max(0, min(appCount, CustomWorkspaceAppList.maxCount))
        return count == 0 ? 1 : count + 1
    }


    static func equalSlotWidth(
        regionWidth: CGFloat,
        slotCount: Int,
        spacing: CGFloat = WorkspaceTouchBarStyle.itemSpacing
    ) -> CGFloat {
        let count = max(slotCount, 1)
        let gaps = spacing * CGFloat(count - 1)
        return max(floor((regionWidth - gaps) / CGFloat(count)), 1)
    }



    static func slotFrames(
        in region: NSRect,
        slotCount: Int,
        spacing: CGFloat = WorkspaceTouchBarStyle.itemSpacing
    ) -> [NSRect] {
        let count = max(slotCount, 1)
        let slotHeight = max(
            region.height - slotVerticalInset * 2,
            WorkspaceTouchBarStyle.controlHeight - slotVerticalInset * 2
        )
        let usable = NSRect(
            x: region.minX,
            y: region.midY - slotHeight / 2,
            width: region.width,
            height: slotHeight
        )
        let slotWidth = equalSlotWidth(
            regionWidth: usable.width,
            slotCount: count,
            spacing: spacing
        )
        return (0..<count).map { index in
            let x = usable.minX + CGFloat(index) * (slotWidth + spacing)
            return NSRect(
                x: x,
                y: usable.minY,
                width: slotWidth,
                height: usable.height
            )
        }
    }


    static func zoneContentRect(_ region: NSRect) -> NSRect {
        region.insetBy(dx: zoneContentInset, dy: 0)
    }




    static func quotaScrollArrangement(
        plateWidth: CGFloat,
        showsFiveHourPerGroup: [Bool]
    ) -> (groupWidths: [CGFloat], contentWidth: CGFloat, needsScroll: Bool) {
        let width = max(plateWidth, 0)
        let flags = showsFiveHourPerGroup
        if flags.isEmpty {
            return ([], width, false)
        }
        var widths = flags.map { quotaGroupMinimumWidth(showsFiveHour: $0) }
        let spacing = CGFloat(flags.count - 1) * quotaGroupSpacing
        let contentMin = widths.reduce(0, +) + spacing
        if contentMin > width + 0.5 {
            return (widths, contentMin, true)
        }


        let threeBarIndices = flags.indices.filter { flags[$0] }
        guard !threeBarIndices.isEmpty else {
            return (widths, contentMin, false)
        }
        let leftover = width - contentMin
        let share = leftover / CGFloat(threeBarIndices.count)
        for index in threeBarIndices {
            widths[index] += share
        }
        return (widths, width, false)
    }


    static func quotaScrollArrangement(
        plateWidth: CGFloat,
        groupCount: Int
    ) -> (groupWidths: [CGFloat], contentWidth: CGFloat, needsScroll: Bool) {
        quotaScrollArrangement(
            plateWidth: plateWidth,
            showsFiveHourPerGroup: Array(repeating: true, count: max(groupCount, 0))
        )
    }



    static func regionFrames(
        in bounds: NSRect
    ) -> (
        quota: NSRect,
        apps: NSRect
    ) {
        trayZoneFrames(tray: bounds)
    }
}

enum WorkspaceTouchBarStyle {

    static let canvasInset: CGFloat = 4

    static let trayBackground = NSColor(
        red: 18 / 255,
        green: 22 / 255,
        blue: 29 / 255,
        alpha: 1
    )

    static let itemBackground = NSColor(
        red: 32 / 255,
        green: 39 / 255,
        blue: 49 / 255,
        alpha: 1
    )

    static let itemHighlightedBackground = NSColor.white.withAlphaComponent(0.22)
    static let itemHighlightBorderColor = NSColor.white.withAlphaComponent(0.32)
    static let dividerColor = NSColor.white.withAlphaComponent(0.10)
    static let primaryTextColor = NSColor.white
    static let secondaryTextColor = NSColor.white.withAlphaComponent(0.55)
    static let amberAccent = NSColor(
        red: 232 / 255,
        green: 160 / 255,
        blue: 74 / 255,
        alpha: 1
    )
    static let controlHeight: CGFloat = 30
    static let cornerRadius: CGFloat = 7
    static let trayCornerRadius: CGFloat = 8

    static let itemSpacing: CGFloat = 6
    static let horizontalPadding: CGFloat = 12
    static let imageTitleSpacing: CGFloat = 7
    static let iconWidth: CGFloat = 16
    static let agentIconSize: CGFloat = 22
    @MainActor
    static var titleFont: NSFont {
        NSFont.systemFont(ofSize: 12, weight: .semibold)
    }

    @MainActor
    static var secondaryFont: NSFont {
        NSFont.systemFont(ofSize: 10, weight: .regular)
    }

    @MainActor
    static var quotaValueFont: NSFont {
        let base = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        return base.fontDescriptor.withDesign(.rounded)
            .flatMap { NSFont(descriptor: $0, size: 11) } ?? base
    }

    @MainActor
    static var microFont: NSFont {
        NSFont.systemFont(ofSize: 8, weight: .medium)
    }


    static let resetBarColor = NSColor(
        red: 120 / 255,
        green: 196 / 255,
        blue: 188 / 255,
        alpha: 1
    )

    static let failureSymbolName: String? = nil

    @MainActor
    static func symbol(
        named name: String?,
        accessibilityDescription: String
    ) -> NSImage? {
        guard let name else { return nil }
        return NSImage(
            systemSymbolName: name,
            accessibilityDescription: accessibilityDescription
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 11, weight: .medium)
        )
    }













    @MainActor
    static func providerIcon(for id: QuotaProviderID) -> NSImage? {
        if let resourceName = id.iconResourceName,
            let bundled = bundledIcon(named: resourceName)
        {
            return bundled
        }
        return NSImage(
            systemSymbolName: id.placeholderSymbolName,
            accessibilityDescription: id.displayName
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
                .applying(.init(paletteColors: [primaryTextColor]))
        )
    }

    @MainActor
    static func bundledIcon(named resourceName: String) -> NSImage? {
        var candidates: [URL?] = [
            Bundle.main.url(
                forResource: resourceName,
                withExtension: "png",
                subdirectory: "AgentIcons"
            ),
            Bundle.main.resourceURL?
                .appendingPathComponent("AgentIcons", isDirectory: true)
                .appendingPathComponent("\(resourceName).png"),
        ]

        if let exeDir = Bundle.main.executableURL?.deletingLastPathComponent() {
            let spmBundle = exeDir.appendingPathComponent(
                "ToubarReplace_ToubarReplace.bundle",
                isDirectory: true
            )
            candidates.append(
                spmBundle.appendingPathComponent("\(resourceName).png")
            )
            candidates.append(
                spmBundle
                    .appendingPathComponent("AgentIcons", isDirectory: true)
                    .appendingPathComponent("\(resourceName).png")
            )
        }
        for candidate in candidates {
            guard let url = candidate,
                FileManager.default.fileExists(atPath: url.path),
                let image = NSImage(contentsOf: url)
            else { continue }
            image.isTemplate = false
            return image
        }
        return nil
    }

    @MainActor
    static func customAppIcon(for app: CustomWorkspaceApp) -> NSImage? {
        let path = app.applicationPath
        let sourceImage: NSImage?
        if FileManager.default.fileExists(atPath: path) {
            sourceImage = NSWorkspace.shared.icon(forFile: path)
            sourceImage?.isTemplate = false
        } else if let bundleIdentifier = app.bundleIdentifier,
            let url = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: bundleIdentifier
            )
        {
            sourceImage = NSWorkspace.shared.icon(forFile: url.path)
            sourceImage?.isTemplate = false
        } else {
            sourceImage = symbol(
                named: "app.dashed",
                accessibilityDescription: app.displayName
            )
        }
        return scaledIcon(from: sourceImage)
    }

    @MainActor
    private static func scaledIcon(from sourceImage: NSImage?) -> NSImage? {
        guard let sourceImage else { return nil }
        let targetSize = NSSize(width: agentIconSize, height: agentIconSize)
        let icon = NSImage(size: targetSize, flipped: false) { rect in
            NSGraphicsContext.current?.imageInterpolation = .high
            sourceImage.draw(
                in: rect,
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: [.interpolation: NSImageInterpolation.high]
            )
            return true
        }
        icon.isTemplate = sourceImage.isTemplate
        return icon
    }

    @MainActor
    static func applyItemChrome(
        to layer: CALayer?,
        highlighted: Bool,
        enabled: Bool = true
    ) {
        let showHighlight = highlighted && enabled
        layer?.backgroundColor = showHighlight
            ? itemHighlightedBackground.cgColor
            : itemBackground.cgColor
        layer?.borderWidth = showHighlight ? 1 : 0
        layer?.borderColor = itemHighlightBorderColor.cgColor
        layer?.cornerRadius = cornerRadius
    }
}



@MainActor
final class WorkspaceChromeButton: NSButton {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configureDefaults()
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureDefaults() {
        isBordered = false
        bezelStyle = .rounded
        setButtonType(.momentaryChange)
        wantsLayer = true
        layer?.masksToBounds = true
        font = WorkspaceTouchBarStyle.secondaryFont
        contentTintColor = WorkspaceTouchBarStyle.primaryTextColor
        WorkspaceTouchBarStyle.applyItemChrome(
            to: layer,
            highlighted: false,
            enabled: true
        )
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        layer?.contentsScale = scale
    }

    override var isEnabled: Bool {
        didSet {
            alphaValue = isEnabled ? 1 : 0.72
            refreshChrome()
        }
    }

    override var isHighlighted: Bool {
        didSet { refreshChrome() }
    }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        refreshChrome()
    }

    override func mouseDown(with event: NSEvent) {


        refreshChrome()
        super.mouseDown(with: event)
        refreshChrome()
    }

    func refreshChrome() {
        WorkspaceTouchBarStyle.applyItemChrome(
            to: layer,
            highlighted: isHighlighted,
            enabled: isEnabled
        )
    }

    func configureTitleChrome(title: String, toolTip: String) {
        self.title = title
        self.toolTip = toolTip
        image = nil
        imagePosition = .noImage
        setAccessibilityLabel(title.isEmpty ? "添加自定义 App" : title)
        refreshChrome()
    }
}



@MainActor
final class WorkspaceReturnItemView: NSView {
    var onActivate: (() -> Void)?
    var onWindowAttachmentChanged: ((Bool) -> Void)?

    private let button = NSButton()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        button.image = NSImage(
            systemSymbolName: "chevron.backward",
            accessibilityDescription: "返回 Touch Bar 镜像"
        )
        button.contentTintColor = NSColor.white
        button.isBordered = false
        button.bezelStyle = .texturedRounded
        button.imageScaling = .scaleProportionallyDown
        button.imagePosition = .imageOnly
        button.toolTip = "点击返回 Touch Bar 镜像"
        button.setAccessibilityLabel("返回 Touch Bar 镜像")
        button.target = self
        button.action = #selector(activate)
        button.translatesAutoresizingMaskIntoConstraints = false
        addSubview(button)
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor),
            button.trailingAnchor.constraint(equalTo: trailingAnchor),
            button.topAnchor.constraint(equalTo: topAnchor),
            button.bottomAnchor.constraint(equalTo: bottomAnchor),
            button.widthAnchor.constraint(
                equalToConstant: WorkspaceTouchBarLayout.switcherWidth
            ),
            button.heightAnchor.constraint(
                equalToConstant: WorkspaceTouchBarStyle.controlHeight
            ),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowAttachmentChanged?(window != nil)
    }

    @objc private func activate() {
        onActivate?()
    }
}

@MainActor
final class WorkspaceTouchBarContentView: NSView {
    private let trayView = NSView()
    private let quotaView: NSView
    private let customView: NSView
    private let zoneDivider = NSView()

    var onWindowAttachmentChanged: ((Bool) -> Void)?

    init(quotaView: NSView, customView: NSView) {
        self.quotaView = quotaView
        self.customView = customView
        super.init(frame: .zero)


        setContentHuggingPriority(.defaultLow, for: .horizontal)
        setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        setContentHuggingPriority(.required, for: .vertical)
        setContentCompressionResistancePriority(.required, for: .vertical)

        trayView.wantsLayer = true
        trayView.layer?.backgroundColor =
            WorkspaceTouchBarStyle.trayBackground.cgColor
        trayView.layer?.cornerRadius = WorkspaceTouchBarStyle.trayCornerRadius
        addSubview(trayView)

        addSubview(quotaView)
        addSubview(customView)
        zoneDivider.wantsLayer = true
        zoneDivider.layer?.backgroundColor = WorkspaceTouchBarStyle
            .dividerColor.cgColor
        addSubview(zoneDivider)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: NSSize {


        NSSize(
            width: WorkspaceTouchBarLayout.preferredTrayWidth(),
            height: WorkspaceTouchBarStyle.controlHeight
        )
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowAttachmentChanged?(window != nil)
    }

    func setNeedsRegionLayout() {
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard bounds.width > 1, bounds.height > 1 else { return }

        let scale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        trayView.layer?.contentsScale = scale

        let tray = WorkspaceTouchBarLayout.trayFrame(in: bounds)
        trayView.frame = tray
        let zones = WorkspaceTouchBarLayout.trayZoneFrames(tray: tray)

        let quotaInner = WorkspaceTouchBarLayout.zoneContentRect(zones.quota)
        let plateHeight = max(
            tray.height - WorkspaceTouchBarLayout.slotVerticalInset * 2,
            22
        )
        quotaView.frame = NSRect(
            x: quotaInner.minX,
            y: tray.midY - plateHeight / 2,
            width: quotaInner.width,
            height: plateHeight
        )

        let appsInner = WorkspaceTouchBarLayout.zoneContentRect(zones.apps)
        customView.frame = NSRect(
            x: appsInner.minX,
            y: tray.minY,
            width: appsInner.width,
            height: tray.height
        )

        let dividerHeight: CGFloat = 18
        zoneDivider.frame = NSRect(
            x: floor(
                zones.apps.minX
                    - WorkspaceTouchBarLayout.zoneDividerWidth / 2
            ),
            y: floor(tray.midY - dividerHeight / 2),
            width: WorkspaceTouchBarLayout.zoneDividerWidth,
            height: dividerHeight
        )
        customView.needsLayout = true
        customView.layoutSubtreeIfNeeded()
        quotaView.needsLayout = true
        quotaView.layoutSubtreeIfNeeded()
    }
}


@MainActor
final class WorkspaceCustomAppsView: NSView {
    private let emptyButton = WorkspaceChromeButton()
    private let settingsButton = WorkspaceChromeButton()
    private var iconButtons: [WorkspaceChromeButton] = []
    private var apps: [CustomWorkspaceApp] = []
    private var slotViews: [NSView] = []


    var onOpenSettings: (() -> Void)?
    var onOpenCustomApp: ((CustomWorkspaceApp) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        emptyButton.configureTitleChrome(
            title: "自定义app",
            toolTip: "打开设置，管理常用应用（最多 5 个）"
        )
        emptyButton.target = self
        emptyButton.action = #selector(openSettings)
        addSubview(emptyButton)

        settingsButton.configureTitleChrome(
            title: "",
            toolTip: "打开设置，管理常用应用（最多 5 个）"
        )
        settingsButton.image = NSImage(
            systemSymbolName: "gearshape",
            accessibilityDescription: "设置自定义 App"
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
        )
        settingsButton.imagePosition = .imageOnly
        settingsButton.imageScaling = .scaleProportionallyDown
        settingsButton.contentTintColor = WorkspaceTouchBarStyle.primaryTextColor
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        addSubview(settingsButton)

        display(apps: WorkspacePreferences.customApps)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func display(apps: [CustomWorkspaceApp]) {
        self.apps = CustomWorkspaceAppList.normalized(apps)
        iconButtons.forEach { $0.removeFromSuperview() }
        iconButtons.removeAll()

        if self.apps.isEmpty {
            emptyButton.isHidden = false
            settingsButton.isHidden = true
            slotViews = [emptyButton]
        } else {
            emptyButton.isHidden = true
            settingsButton.isHidden = false
            var views: [NSView] = []
            for (index, app) in self.apps.enumerated() {
                let button = makeAppButton(app: app, index: index)
                addSubview(button)
                iconButtons.append(button)
                views.append(button)
            }
            views.append(settingsButton)
            slotViews = views
        }
        needsLayout = true
        superview?.needsLayout = true
    }

    var slotFramesForValidation: [NSRect] { slotViews.map(\.frame) }

    var settingsButtonFrame: NSRect {
        settingsButton.isHidden ? .zero : settingsButton.frame
    }



    func layoutEqualSlots(in region: NSRect) {
        guard region.width > 1, region.height > 1, !slotViews.isEmpty else {
            return
        }
        let slots = WorkspaceTouchBarLayout.slotFrames(
            in: region,
            slotCount: slotViews.count
        )
        for (index, view) in slotViews.enumerated() where index < slots.count {
            view.frame = slots[index]
        }
    }

    override func layout() {
        super.layout()
        layoutEqualSlots(in: bounds)
    }

    private func makeAppButton(
        app: CustomWorkspaceApp,
        index: Int
    ) -> WorkspaceChromeButton {
        let button = WorkspaceChromeButton()
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleProportionallyDown
        button.image = WorkspaceTouchBarStyle.customAppIcon(for: app)
        button.contentTintColor = nil
        button.toolTip = "打开 \(app.displayName)"
        button.setAccessibilityLabel(app.displayName)
        button.tag = index
        button.target = self
        button.action = #selector(openCustomApp(_:))
        return button
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    @objc private func openCustomApp(_ sender: NSButton) {
        guard apps.indices.contains(sender.tag) else { return }
        onOpenCustomApp?(apps[sender.tag])
    }
}


@MainActor
final class QuotaVerticalBarView: NSView {
    private let track = NSView()
    private let fill = NSView()
    private let valueLabel = NSTextField(labelWithString: "")
    private let caption = NSTextField(labelWithString: "")
    private var metric = QuotaBarMetric(
        ratio: nil,
        caption: "",
        valueText: "—",
        isHighlighted: false
    )
    private var fillColor = NSColor.white
    private var style: QuotaMetricDisplayStyle = .bars

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        track.wantsLayer = true
        track.layer?.cornerRadius = 2
        track.layer?.backgroundColor = NSColor.white.withAlphaComponent(0.14).cgColor
        addSubview(track)
        fill.wantsLayer = true
        fill.layer?.cornerRadius = 2
        track.addSubview(fill)
        valueLabel.font = WorkspaceTouchBarStyle.quotaValueFont
        valueLabel.textColor = WorkspaceTouchBarStyle.primaryTextColor
        valueLabel.isBezeled = false
        valueLabel.drawsBackground = false
        valueLabel.isEditable = false
        valueLabel.isSelectable = false
        valueLabel.alignment = .center
        valueLabel.lineBreakMode = .byClipping
        valueLabel.isHidden = true
        addSubview(valueLabel)
        caption.font = WorkspaceTouchBarStyle.microFont
        caption.textColor = WorkspaceTouchBarStyle.secondaryTextColor
        caption.isBezeled = false
        caption.drawsBackground = false
        caption.isEditable = false
        caption.isSelectable = false
        caption.alignment = .center
        caption.lineBreakMode = .byClipping
        addSubview(caption)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func display(
        _ metric: QuotaBarMetric,
        fillColor: NSColor,
        style: QuotaMetricDisplayStyle = .bars,
        textColor: NSColor? = nil
    ) {
        self.metric = metric
        self.fillColor = fillColor
        self.style = style
        caption.stringValue = metric.caption
        caption.textColor = metric.isHighlighted
            ? WorkspaceTouchBarStyle.amberAccent
            : WorkspaceTouchBarStyle.secondaryTextColor
        valueLabel.stringValue = metric.valueText
        valueLabel.textColor = metric.isHighlighted
            ? WorkspaceTouchBarStyle.amberAccent
            : (metric.valueText != "—" ? (textColor ?? fillColor) : WorkspaceTouchBarStyle.secondaryTextColor)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let text = NSMutableAttributedString(string: metric.valueText, attributes: [
            .paragraphStyle: paragraph,
            .font: WorkspaceTouchBarStyle.quotaValueFont,
            .foregroundColor: valueLabel.textColor ?? .white,
        ])
        for (index, character) in metric.valueText.utf16.enumerated() {
            if character == 37 || character == 100 || character == 104 || character == 109 {
                text.addAttributes([
                    .font: NSFont.systemFont(ofSize: 9, weight: .regular),
                    .foregroundColor: (valueLabel.textColor ?? .white).withAlphaComponent(0.7),
                ], range: NSRange(location: index, length: 1))
            }
        }
        valueLabel.attributedStringValue = text
        fill.layer?.backgroundColor = fillColor.cgColor
        let showBars = style == .bars
        track.isHidden = !showBars
        fill.isHidden = !showBars
        valueLabel.isHidden = showBars
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        track.layer?.contentsScale = scale
        fill.layer?.contentsScale = scale
        guard bounds.width > 1, bounds.height > 1 else { return }

        let captionHeight: CGFloat = 10
        caption.frame = NSRect(
            x: 0,
            y: 0,
            width: bounds.width,
            height: captionHeight
        )
        if style == .percent {
            valueLabel.frame = NSRect(
                x: 0,
                y: captionHeight,
                width: bounds.width,
                height: max(bounds.height - captionHeight, 12)
            )
            return
        }

        let trackWidth: CGFloat = min(max(floor(bounds.width * 0.42), 6), 10)
        let trackHeight = max(bounds.height - captionHeight - 1, 8)
        let trackX = floor((bounds.width - trackWidth) / 2)
        track.frame = NSRect(
            x: trackX,
            y: captionHeight,
            width: trackWidth,
            height: trackHeight
        )
        let ratio = CGFloat(min(max(metric.ratio ?? 0, 0), 1))
        let fillHeight: CGFloat
        if metric.ratio == nil {
            fillHeight = 2
            fill.alphaValue = 0.28
        } else {
            fillHeight = max(floor(trackHeight * ratio), 2)
            fill.alphaValue = 1
        }
        fill.frame = NSRect(
            x: 0,
            y: 0,
            width: trackWidth,
            height: fillHeight
        )
    }
}

@MainActor
final class QuotaProviderGroupView: NSView {
    private let iconView = NSImageView()
    private let fiveHourBar = QuotaVerticalBarView()
    private let weeklyBar = QuotaVerticalBarView()
    private let resetBar = QuotaVerticalBarView()
    private(set) var state: QuotaProviderGroupState?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        WorkspaceTouchBarStyle.applyItemChrome(
            to: layer,
            highlighted: false,
            enabled: true
        )
        iconView.imageScaling = .scaleProportionallyDown
        iconView.contentTintColor = WorkspaceTouchBarStyle.primaryTextColor
        addSubview(iconView)
        addSubview(fiveHourBar)
        addSubview(weeklyBar)
        addSubview(resetBar)
        setAccessibilityElement(true)
        setAccessibilityRole(.group)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func display(_ state: QuotaProviderGroupState) {
        self.state = state
        iconView.image = WorkspaceTouchBarStyle.providerIcon(for: state.provider)
        let style = WorkspacePreferences.quotaMetricDisplayStyle
        weeklyBar.isHidden = false
        resetBar.isHidden = state.balance != nil
        if let balance = state.balance {
            fiveHourBar.isHidden = true
            weeklyBar.display(QuotaBarMetric(ratio: nil, caption: balance.caption,
                                             valueText: balance.valueText, isHighlighted: false),
                              fillColor: WorkspaceTouchBarStyle.resetBarColor, style: .percent)
            toolTip = state.tooltip
            setAccessibilityLabel("\(state.title) 额度，\(balance.caption) \(balance.valueText)")
            refreshChrome()
            needsLayout = true
            return
        }

        fiveHourBar.isHidden = !state.fiveHour.isAvailable
        if state.fiveHour.isAvailable {
            fiveHourBar.display(
                state.fiveHour,
                fillColor: state.fiveHour.isHighlighted
                    ? WorkspaceTouchBarStyle.amberAccent
                    : .white,
                style: style
            )
        }
        weeklyBar.display(
            state.weekly,
            fillColor: state.weekly.isHighlighted
                ? WorkspaceTouchBarStyle.amberAccent
                : .white,
            style: style
        )
        resetBar.display(
            state.reset,
            fillColor: WorkspaceTouchBarStyle.resetBarColor,
            style: style,
            textColor: WorkspaceTouchBarStyle.primaryTextColor
        )
        toolTip = state.tooltip
        setAccessibilityLabel("\(state.title) 额度")
        refreshChrome()
        needsLayout = true
    }

    override func layout() {
        super.layout()
        let scale = window?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor
            ?? 2
        layer?.contentsScale = scale
        guard bounds.width > 1, bounds.height > 1 else { return }

        let pad: CGFloat = 5
        let iconSize = min(WorkspaceTouchBarStyle.agentIconSize - 4, bounds.height - 8)
        iconView.frame = NSRect(
            x: pad,
            y: floor((bounds.height - iconSize) / 2),
            width: iconSize,
            height: iconSize
        )
        let barsX = iconView.frame.maxX + 4
        let barsWidth = max(bounds.width - barsX - 4, 24)
        let showFiveHour = state?.fiveHour.isAvailable == true
        let barCount: CGFloat = showFiveHour ? 3 : 2
        let barWidth = floor(barsWidth / barCount)
        let barHeight = max(bounds.height - 4, 16)
        let barY = floor((bounds.height - barHeight) / 2)
        if state?.balance != nil {
            fiveHourBar.frame = .zero
            resetBar.frame = .zero
            weeklyBar.frame = NSRect(x: barsX, y: barY, width: barsWidth, height: barHeight)
            return
        }
        if showFiveHour {
            fiveHourBar.frame = NSRect(
                x: barsX,
                y: barY,
                width: barWidth,
                height: barHeight
            )
            weeklyBar.frame = NSRect(
                x: barsX + barWidth,
                y: barY,
                width: barWidth,
                height: barHeight
            )
            resetBar.frame = NSRect(
                x: barsX + barWidth * 2,
                y: barY,
                width: max(barsWidth - barWidth * 2, 8),
                height: barHeight
            )
        } else {
            fiveHourBar.frame = .zero
            weeklyBar.frame = NSRect(
                x: barsX,
                y: barY,
                width: barWidth,
                height: barHeight
            )
            resetBar.frame = NSRect(
                x: barsX + barWidth,
                y: barY,
                width: max(barsWidth - barWidth, 8),
                height: barHeight
            )
        }
    }

    private func refreshChrome() {
        WorkspaceTouchBarStyle.applyItemChrome(
            to: layer,
            highlighted: false,
            enabled: true
        )
        if state?.isRecommended == true {
            layer?.borderWidth = 1
            layer?.borderColor = WorkspaceTouchBarStyle.amberAccent
                .withAlphaComponent(0.7).cgColor
        }
    }
}

@MainActor
final class QuotaPlateView: NSView {
    private let emptyLabel = NSTextField(labelWithString: "暂无额度")
    private let scrollView = NSScrollView()
    private let documentView = NSView()
    private(set) var groupViews: [QuotaProviderGroupView] = []
    private var state = QuotaBoardState.empty
    private var leadingProvider: QuotaProviderID?
    private var pendingScrollReset = false
    private(set) var contentWidth: CGFloat = 0
    private(set) var needsHorizontalScroll = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        emptyLabel.font = WorkspaceTouchBarStyle.secondaryFont
        emptyLabel.textColor = WorkspaceTouchBarStyle.secondaryTextColor
        emptyLabel.isBezeled = false
        emptyLabel.drawsBackground = false
        emptyLabel.isEditable = false
        emptyLabel.isSelectable = false
        emptyLabel.alignment = .center
        emptyLabel.lineBreakMode = .byClipping
        addSubview(emptyLabel)

        scrollView.drawsBackground = false
        scrollView.backgroundColor = .clear
        scrollView.borderType = .noBorder
        scrollView.hasHorizontalScroller = false
        scrollView.hasVerticalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.verticalScrollElasticity = .none
        scrollView.horizontalScrollElasticity = .allowed
        scrollView.usesPredominantAxisScrolling = true
        scrollView.automaticallyAdjustsContentInsets = false
        scrollView.contentInsets = NSEdgeInsets()
        scrollView.scrollerInsets = NSEdgeInsets()
        scrollView.allowedTouchTypes = [.direct, .indirect]
        scrollView.contentView.drawsBackground = false
        scrollView.contentView.backgroundColor = .clear
        documentView.wantsLayer = true
        scrollView.documentView = documentView
        addSubview(scrollView)

        setAccessibilityElement(true)
        setAccessibilityRole(.group)
        setAccessibilityLabel("订阅额度")
        display(.empty)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func display(_ state: QuotaBoardState) {
        self.state = state
        let newLeading = state.groups.first?.provider
        if newLeading != leadingProvider {
            pendingScrollReset = true
            leadingProvider = newLeading
        }
        groupViews.forEach { $0.removeFromSuperview() }
        groupViews.removeAll()
        emptyLabel.isHidden = !state.isEmpty
        emptyLabel.stringValue = "暂无额度"
        scrollView.isHidden = state.isEmpty
        toolTip = state.isEmpty ? "暂无订阅额度数据" : nil
        for group in state.groups {
            let view = QuotaProviderGroupView()
            view.display(group)
            documentView.addSubview(view)
            groupViews.append(view)
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard bounds.width > 1, bounds.height > 1 else { return }
        emptyLabel.frame = bounds
        scrollView.frame = bounds
        guard !groupViews.isEmpty else {
            contentWidth = bounds.width
            needsHorizontalScroll = false
            documentView.frame = NSRect(
                x: 0,
                y: 0,
                width: bounds.width,
                height: bounds.height
            )
            return
        }
        let previousOffset = pendingScrollReset
            ? 0
            : scrollView.contentView.bounds.origin.x
        pendingScrollReset = false
        let showsFiveHour = groupViews.map {
            $0.state?.fiveHour.isAvailable != false
        }
        let arrangement = WorkspaceTouchBarLayout.quotaScrollArrangement(
            plateWidth: bounds.width,
            showsFiveHourPerGroup: showsFiveHour
        )
        contentWidth = arrangement.contentWidth
        needsHorizontalScroll = arrangement.needsScroll
        scrollView.horizontalScrollElasticity = arrangement.needsScroll
            ? .allowed
            : .none
        documentView.frame = NSRect(
            x: 0,
            y: 0,
            width: arrangement.contentWidth,
            height: bounds.height
        )
        var x: CGFloat = 0
        let spacing = WorkspaceTouchBarLayout.quotaGroupSpacing
        for (index, view) in groupViews.enumerated() {
            let groupWidth = index < arrangement.groupWidths.count
                ? arrangement.groupWidths[index]
                : WorkspaceTouchBarLayout.quotaGroupMinimumWidth
            view.frame = NSRect(
                x: x,
                y: 0,
                width: groupWidth,
                height: bounds.height
            )
            x += groupWidth + spacing
        }
        let maxOffset = max(arrangement.contentWidth - bounds.width, 0)
        scrollView.contentView.scroll(
            to: NSPoint(
                x: min(max(previousOffset, 0), maxOffset),
                y: 0
            )
        )
    }
}

enum WorkspaceTouchBarPresentationError: LocalizedError {
    case unavailable

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "当前系统不支持替换物理 Touch Bar"
        }
    }
}

enum WorkspacePresentationModeDismissalAction: Equatable {
    case preserveCurrent
    case set(String)
    case remove
}

enum WorkspacePresentationModePolicy {
    static func dismissalAction(
        currentMode: String?,
        workspaceMode: String,
        previousMode: String?,
        hadPreviousMode: Bool
    ) -> WorkspacePresentationModeDismissalAction {
        guard currentMode == workspaceMode else {
            return .preserveCurrent
        }



        if hadPreviousMode, let previousMode, previousMode != workspaceMode {
            return .set(previousMode)
        }
        return .remove
    }
}

enum WorkspacePresentationInterruptionPolicy {
    static func shouldInterrupt(
        isPresented: Bool,
        hasAttachedToWindow: Bool,
        isExplicitlyDismissing: Bool,
        isCurrentlyAttached: Bool,
        currentMode: String?,
        workspaceMode: String
    ) -> Bool {
        isPresented
            && hasAttachedToWindow
            && !isExplicitlyDismissing
            && !isCurrentlyAttached
            && currentMode != workspaceMode
    }
}

@MainActor
final class WorkspaceTouchBarController: NSObject, NSTouchBarDelegate {
    private enum ItemIdentifier {
        static let back = NSTouchBarItem.Identifier(
            "com.toubarreplace.workspace.back"
        )
        static let content = NSTouchBarItem.Identifier(
            "com.toubarreplace.workspace.content"
        )
    }

    private let touchBar = NSTouchBar()
    private let quotaPlate = QuotaPlateView()
    private let customAppsView = WorkspaceCustomAppsView()
    private let returnView = WorkspaceReturnItemView()
    private lazy var contentView = WorkspaceTouchBarContentView(
        quotaView: quotaPlate,
        customView: customAppsView
    )
    private var customApps: [CustomWorkspaceApp] = []
    private var previousPresentationMode: String?
    private var hadPreviousPresentationMode = false
    private var hasAttachedToTouchBarWindow = false
    private var isExplicitlyDismissing = false
    private var detachmentTask: Task<Void, Never>?
    private(set) var isPresented = false

    var onOpenSettings: (() -> Void)?
    var onOpenCustomApp: ((CustomWorkspaceApp) -> Void)?
    var onPresentationInterrupted: (() -> Void)?
    var onToggleWorkspace: (() -> Void)?

    override init() {
        super.init()
        touchBar.delegate = self




        touchBar.escapeKeyReplacementItemIdentifier = ItemIdentifier.back
        touchBar.defaultItemIdentifiers = [ItemIdentifier.content]
        touchBar.principalItemIdentifier = ItemIdentifier.content
        touchBar.customizationAllowedItemIdentifiers = []

        contentView.onWindowAttachmentChanged = { [weak self] attached in
            self?.handleWindowAttachmentChanged(attached)
        }
        returnView.onActivate = { [weak self] in
            self?.onToggleWorkspace?()
        }
        returnView.onWindowAttachmentChanged = { [weak self] attached in
            self?.handleWindowAttachmentChanged(attached)
        }

        customAppsView.onOpenSettings = { [weak self] in
            self?.onOpenSettings?()
        }
        customAppsView.onOpenCustomApp = { [weak self] app in
            self?.onOpenCustomApp?(app)
        }

        reloadCustomAppsFromPreferences()
        showQuota(.empty)
    }

    func reloadRegionLayout() {
        contentView.setNeedsRegionLayout()
    }

    func reloadCustomAppsFromPreferences() {
        customApps = WorkspacePreferences.customApps
        customAppsView.display(apps: customApps)
        contentView.setNeedsRegionLayout()
    }

    func present() throws {
        guard !isPresented else { return }
        guard TBRCanPresentSystemModalTouchBar() else {
            throw WorkspaceTouchBarPresentationError.unavailable
        }

        let storedMode = TouchBarPresentationPreferences.currentMode
        hadPreviousPresentationMode = storedMode != nil
        previousPresentationMode = storedMode
        detachmentTask?.cancel()
        hasAttachedToTouchBarWindow = false
        isExplicitlyDismissing = false
        isPresented = true
        TBRSetSystemModalShowsCloseBoxWhenFrontMost(false)
        TBRPresentSystemModalTouchBar(
            touchBar,
            WorkspaceTouchBarLayout.placement
        )
        TouchBarPresentationPreferences.setCurrentMode(
            WorkspaceTouchBarLayout.presentationMode
        )


    }

    func dismiss() {
        guard isPresented else { return }
        isExplicitlyDismissing = true
        detachmentTask?.cancel()
        detachmentTask = nil
        let dismissalAction = WorkspacePresentationModePolicy.dismissalAction(
            currentMode: TouchBarPresentationPreferences.currentMode,
            workspaceMode: WorkspaceTouchBarLayout.presentationMode,
            previousMode: previousPresentationMode,
            hadPreviousMode: hadPreviousPresentationMode
        )
        switch dismissalAction {
        case .preserveCurrent:
            break
        case let .set(mode):
            TouchBarPresentationPreferences.setCurrentMode(mode)
        case .remove:
            TouchBarPresentationPreferences.setCurrentMode(nil)
        }
        TBRDismissSystemModalTouchBar(touchBar)
        TBRSetSystemModalShowsCloseBoxWhenFrontMost(true)
        previousPresentationMode = nil
        hadPreviousPresentationMode = false
        hasAttachedToTouchBarWindow = false
        isPresented = false
        isExplicitlyDismissing = false
    }

    func showQuota(_ state: QuotaBoardState) {
        quotaPlate.display(state)
        contentView.setNeedsRegionLayout()
    }

    func touchBar(
        _ touchBar: NSTouchBar,
        makeItemForIdentifier identifier: NSTouchBarItem.Identifier
    ) -> NSTouchBarItem? {
        switch identifier {
        case ItemIdentifier.back:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.customizationLabel = "返回镜像"
            item.view = returnView
            return item
        case ItemIdentifier.content:
            let item = NSCustomTouchBarItem(identifier: identifier)
            item.customizationLabel = "Workspace"
            contentView.heightAnchor.constraint(
                equalToConstant: WorkspaceTouchBarStyle.controlHeight
            ).isActive = true



            let preferredWidthValue = WorkspaceTouchBarLayout.preferredTrayWidth()
            let minWidth = contentView.widthAnchor.constraint(
                greaterThanOrEqualToConstant: min(
                    WorkspaceTouchBarLayout.minimumContentWidth,
                    preferredWidthValue
                )
            )
            minWidth.priority = .defaultHigh
            minWidth.isActive = true
            let preferredWidth = contentView.widthAnchor.constraint(
                equalToConstant: preferredWidthValue
            )
            preferredWidth.priority = .defaultLow
            preferredWidth.isActive = true
            let maxWidth = contentView.widthAnchor.constraint(
                lessThanOrEqualToConstant: preferredWidthValue
            )
            maxWidth.priority = .required
            maxWidth.isActive = true
            item.view = contentView
            return item
        default:
            return nil
        }
    }

    private func handleWindowAttachmentChanged(_ attached: Bool) {
        detachmentTask?.cancel()
        detachmentTask = nil
        if attached {
            guard isPresented else { return }
            hasAttachedToTouchBarWindow = true
            return
        }
        guard
            isPresented,
            hasAttachedToTouchBarWindow,
            !isExplicitlyDismissing
        else {
            return
        }

        detachmentTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled, let self else { return }
            guard WorkspacePresentationInterruptionPolicy.shouldInterrupt(
                isPresented: self.isPresented,
                hasAttachedToWindow: self.hasAttachedToTouchBarWindow,
                isExplicitlyDismissing: self.isExplicitlyDismissing,
                isCurrentlyAttached: self.contentView.window != nil,
                currentMode: TouchBarPresentationPreferences.currentMode,
                workspaceMode: WorkspaceTouchBarLayout.presentationMode
            ) else {
                return
            }
            self.previousPresentationMode = nil
            self.hadPreviousPresentationMode = false
            self.hasAttachedToTouchBarWindow = false
            self.isPresented = false
            TBRSetSystemModalShowsCloseBoxWhenFrontMost(true)
            self.onPresentationInterrupted?()
        }
    }
}
