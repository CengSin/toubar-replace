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
    static let collapseButtonWidth: CGFloat = 36
    static let collapseContentGap: CGFloat = 6


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


    static let appTileWidth: CGFloat = 40
    static let appTileSpacing: CGFloat = 4
    static let appSettingsWidth: CGFloat = 28
    static let emptyAppsWidth: CGFloat = 132

    static func dockNaturalWidth(appCount: Int) -> CGFloat {
        let count = max(0, min(appCount, CustomWorkspaceAppList.maxCount))
        guard count > 0 else { return emptyAppsWidth }
        return CGFloat(count) * (appTileWidth + appTileSpacing) + appSettingsWidth
    }

    static func fittedZoneFrames(
        tray: NSRect,
        appCount: Int,
        quotaShare: Double = WorkspacePreferences.quotaShare
    ) -> (quota: NSRect, apps: NSRect) {
        let capped = trayZoneFrames(tray: tray, quotaShare: quotaShare)
        let natural = ceil(dockNaturalWidth(appCount: appCount) + zoneContentInset * 2)
        let appsWidth = min(capped.apps.width, natural)
        let usableWidth = max(tray.width - trayTrailingSafeInset, 0)
        let quota = NSRect(
            x: tray.minX,
            y: tray.minY,
            width: max(usableWidth - appsWidth, 0),
            height: tray.height
        )
        let apps = NSRect(x: quota.maxX, y: tray.minY, width: appsWidth, height: tray.height)
        return (quota, apps)
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
        collapse: NSRect,
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
        let collapse = NSRect(x: switcher.maxX + switcherContentGap, y: y,
                              width: collapseButtonWidth, height: height)
        let trayX = collapse.maxX + collapseContentGap
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
        return (switcher, collapse, tray, zones.quota, zones.apps)
    }

    static func collapseFrame(in bounds: NSRect) -> NSRect {
        let height = min(WorkspaceTouchBarStyle.controlHeight, max(bounds.height, 1))
        return NSRect(x: bounds.minX + WorkspaceTouchBarStyle.canvasInset, y: bounds.midY - height / 2,
                      width: collapseButtonWidth, height: height)
    }


    static func trayFrame(in bounds: NSRect) -> NSRect {
        let height = min(
            WorkspaceTouchBarStyle.controlHeight,
            max(bounds.height, 1)
        )
        let inset = WorkspaceTouchBarStyle.canvasInset
        return NSRect(
            x: bounds.minX + inset + collapseButtonWidth + collapseContentGap,
            y: bounds.midY - height / 2,
            width: max(bounds.width - inset * 2 - collapseButtonWidth - collapseContentGap, 0),
            height: height
        )
    }


    static func customSlotCount(appCount: Int) -> Int {
        let count = max(0, min(appCount, CustomWorkspaceAppList.maxCount))
        return count == 0 ? 1 : count + 1
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




    static let paceOnPaceColor = NSColor(
        red: 95 / 255,
        green: 208 / 255,
        blue: 176 / 255,
        alpha: 1
    )

    static let paceDeficitColor = NSColor(
        red: 255 / 255,
        green: 111 / 255,
        blue: 97 / 255,
        alpha: 1
    )

    @MainActor
    static func paceColor(for metric: QuotaBarMetric, theme: DesktopTheme) -> NSColor {
        if metric.isHighlighted { return amberAccent }
        switch metric.pace {
        case .surplus: return amberAccent
        case .deficit: return paceDeficitColor
        case .onPace: return paceOnPaceColor
        case nil: return theme == .glass ? .labelColor : primaryTextColor
        }
    }

    @MainActor
    static func recommendedFill(theme: DesktopTheme) -> NSColor {
        guard theme == .black else { return amberAccent.withAlphaComponent(0.16) }
        return itemBackground.blended(withFraction: 0.16, of: amberAccent) ?? itemBackground
    }

    @MainActor
    static func roundedDigitFont(size: CGFloat, weight: NSFont.Weight) -> NSFont {
        let base = NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        return base.fontDescriptor.withDesign(.rounded)
            .flatMap { NSFont(descriptor: $0, size: size) } ?? base
    }

    @MainActor
    static func compactValueText(_ text: String, size: CGFloat, color: NSColor) -> NSAttributedString {
        let result = NSMutableAttributedString(string: text, attributes: [
            .font: roundedDigitFont(size: size, weight: .semibold),
            .foregroundColor: color,
        ])
        let unitFont = NSFont.systemFont(ofSize: max(size * 0.75, 6), weight: .medium)
        for (index, unit) in text.utf16.enumerated() where [37, 100, 104, 109].contains(unit) {
            result.addAttributes([
                .font: unitFont,
                .foregroundColor: color.withAlphaComponent(0.65),
            ], range: NSRange(location: index, length: 1))
        }
        return result
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
    static func providerIcon(for id: QuotaProviderID, foregroundColor: NSColor = primaryTextColor) -> NSImage? {
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
                .applying(.init(paletteColors: [foregroundColor]))
        )
    }

    @MainActor
    private static var bundledIcons: [String: NSImage] = [:]

    @MainActor
    static func bundledIcon(named resourceName: String) -> NSImage? {
        if let cached = bundledIcons[resourceName] { return cached }
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
            bundledIcons[resourceName] = image
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
    var desktopTheme: DesktopTheme = .black {
        didSet { refreshChrome() }
    }
    var isQuiet = false {
        didSet { refreshChrome() }
    }
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
        effectiveAppearance.performAsCurrentDrawingAppearance {
            DesktopThemeChrome.apply(to: layer, theme: desktopTheme,
                                    highlighted: isHighlighted, enabled: isEnabled)
            if isQuiet && !(isHighlighted && isEnabled) {
                layer?.backgroundColor = NSColor.clear.cgColor
            }
        }
        if image?.isTemplate != false {
            let tint: NSColor = desktopTheme == .glass ? .labelColor : WorkspaceTouchBarStyle.primaryTextColor
            contentTintColor = isQuiet ? tint.withAlphaComponent(0.55) : tint
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        refreshChrome()
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
    let collapseButton = NSButton()
    var onCollapse: (() -> Void)?
    private let trayView = NSView()
    private let quotaView: NSView
    private let customView: NSView
    private let zoneDivider = NSView()

    var onWindowAttachmentChanged: ((Bool) -> Void)?

    init(quotaView: NSView, customView: NSView) {
        self.quotaView = quotaView
        self.customView = customView
        super.init(frame: .zero)
        collapseButton.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: "隐藏 ToubarReplace")
        collapseButton.contentTintColor = .white
        collapseButton.isBordered = false
        collapseButton.imagePosition = .imageOnly
        collapseButton.target = self
        collapseButton.action = #selector(collapse)
        collapseButton.setAccessibilityLabel("隐藏 ToubarReplace")
        collapseButton.setAccessibilityIdentifier("ToubarReplace.TouchBar.Collapse")
        addSubview(collapseButton)


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
        collapseButton.frame = WorkspaceTouchBarLayout.collapseFrame(in: bounds)
        trayView.frame = tray
        let zones = (customView as? WorkspaceCustomAppsView).map {
            WorkspaceTouchBarLayout.fittedZoneFrames(tray: tray, appCount: $0.appCount)
        } ?? WorkspaceTouchBarLayout.trayZoneFrames(tray: tray)

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

    @objc private func collapse() { onCollapse?() }
}


@MainActor
final class WorkspaceCustomAppsView: NSView {
    private let emptyButton = WorkspaceChromeButton()
    private let settingsButton = WorkspaceChromeButton()
    private var iconButtons: [WorkspaceAppTileButton] = []
    private var apps: [CustomWorkspaceApp] = []
    private var slotViews: [NSView] = []
    private var desktopTheme: DesktopTheme = .black
    private var quotaState = QuotaBoardState.empty

    var appCount: Int { apps.count }

    func setDesktopTheme(_ theme: DesktopTheme) {
        desktopTheme = theme
        emptyButton.desktopTheme = theme
        settingsButton.desktopTheme = theme
        iconButtons.forEach { $0.desktopTheme = theme }
    }

    var onOpenSettings: (() -> Void)?
    var onOpenCustomApp: ((CustomWorkspaceApp) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true

        emptyButton.configureTitleChrome(
            title: "＋ 添加常用 App",
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
            accessibilityDescription: "管理常用应用"
        )?.withSymbolConfiguration(
            NSImage.SymbolConfiguration(pointSize: 12, weight: .medium)
        )
        settingsButton.imagePosition = .imageOnly
        settingsButton.imageScaling = .scaleProportionallyDown
        settingsButton.setAccessibilityLabel("管理常用应用")
        settingsButton.isQuiet = true
        settingsButton.target = self
        settingsButton.action = #selector(openSettings)
        addSubview(settingsButton)

        let center = NSWorkspace.shared.notificationCenter
        for name in [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification,
        ] {
            center.addObserver(
                self,
                selector: #selector(runningApplicationsChanged(_:)),
                name: name,
                object: nil
            )
        }

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
            for (index, app) in self.apps.enumerated() {
                let button = makeAppButton(app: app, index: index)
                addSubview(button)
                iconButtons.append(button)
            }
            var views: [NSView] = iconButtons
            views.append(settingsButton)
            slotViews = views
        }
        refreshRunningState()
        applyQuotaBadges()
        needsLayout = true
        superview?.needsLayout = true
        setDesktopTheme(desktopTheme)
    }

    func showQuota(_ state: QuotaBoardState) {
        guard quotaState != state else { return }
        quotaState = state
        applyQuotaBadges()
    }

    func playLaunchFeedback(for app: CustomWorkspaceApp) {
        guard let index = apps.firstIndex(where: { $0.applicationPath == app.applicationPath }),
              iconButtons.indices.contains(index) else { return }
        iconButtons[index].playLaunchFeedback()
    }

    var slotFramesForValidation: [NSRect] { slotViews.map(\.frame) }

    var settingsButtonFrame: NSRect {
        settingsButton.isHidden ? .zero : settingsButton.frame
    }

    func layoutDock(in region: NSRect) {
        guard region.width > 1, region.height > 1 else { return }
        let height = max(min(region.height, WorkspaceTouchBarStyle.controlHeight - 4), 1)
        let y = floor(region.midY - height / 2)
        if apps.isEmpty {
            emptyButton.frame = NSRect(x: region.minX, y: y, width: region.width, height: height)
            return
        }
        let spacing = WorkspaceTouchBarLayout.appTileSpacing
        let gearWidth = min(WorkspaceTouchBarLayout.appSettingsWidth, region.width)
        let count = CGFloat(iconButtons.count)
        let available = region.width - gearWidth - spacing * count
        let tileWidth = max(
            min(WorkspaceTouchBarLayout.appTileWidth, floor(available / max(count, 1))),
            1
        )
        var x = region.minX
        for tile in iconButtons {
            tile.frame = NSRect(x: x, y: y, width: tileWidth, height: height)
            x += tileWidth + spacing
        }
        settingsButton.frame = NSRect(
            x: min(x, region.maxX - gearWidth),
            y: y,
            width: gearWidth,
            height: height
        )
    }

    override func layout() {
        super.layout()
        layoutDock(in: bounds)
    }

    @objc private func runningApplicationsChanged(_ notification: Notification) {
        refreshRunningState()
    }

    private func refreshRunningState() {
        guard !iconButtons.isEmpty else { return }
        let workspace = NSWorkspace.shared
        let running = workspace.runningApplications
        let frontmost = workspace.frontmostApplication?.processIdentifier
        for (index, tile) in iconButtons.enumerated() where apps.indices.contains(index) {
            let match = running.first { Self.matches(apps[index], running: $0) }
            tile.isRunning = match != nil
            tile.isFrontmost = match != nil && match?.processIdentifier == frontmost
        }
    }

    private static func matches(_ app: CustomWorkspaceApp, running: NSRunningApplication) -> Bool {
        if let identifier = app.bundleIdentifier, running.bundleIdentifier == identifier {
            return true
        }
        guard let url = running.bundleURL else { return false }
        return url.standardizedFileURL.path
            == URL(fileURLWithPath: app.applicationPath).standardizedFileURL.path
    }

    private func applyQuotaBadges() {
        var badges: [String: QuotaBarMetric] = [:]
        for group in quotaState.groups where group.balance == nil {
            let metric = group.weekly.isAvailable ? group.weekly : group.fiveHour
            guard metric.isAvailable,
                  let app = QuotaProviderLaunch.matchingCustomApp(provider: group.provider, apps: apps),
                  badges[app.applicationPath] == nil else { continue }
            badges[app.applicationPath] = metric
        }
        for (index, tile) in iconButtons.enumerated() where apps.indices.contains(index) {
            tile.quotaBadge = badges[apps[index].applicationPath]
        }
    }

    private func makeAppButton(
        app: CustomWorkspaceApp,
        index: Int
    ) -> WorkspaceAppTileButton {
        let button = WorkspaceAppTileButton()
        button.icon = WorkspaceTouchBarStyle.customAppIcon(for: app)
        button.desktopTheme = desktopTheme
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
        (sender as? WorkspaceAppTileButton)?.playLaunchFeedback()
        onOpenCustomApp?(apps[sender.tag])
    }
}

@MainActor
final class WorkspaceAppTileButton: NSButton {
    var desktopTheme: DesktopTheme = .black {
        didSet { if oldValue != desktopTheme { needsDisplay = true } }
    }
    var icon: NSImage? {
        didSet { needsDisplay = true }
    }
    var isRunning = false {
        didSet { if oldValue != isRunning { needsDisplay = true } }
    }
    var isFrontmost = false {
        didSet { if oldValue != isFrontmost { needsDisplay = true } }
    }
    var quotaBadge: QuotaBarMetric? {
        didSet { if oldValue != quotaBadge { needsDisplay = true } }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        isBordered = false
        title = ""
        imagePosition = .noImage
        setButtonType(.momentaryChange)
        wantsLayer = true
    }

    convenience init() {
        self.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override var isHighlighted: Bool {
        didSet { needsDisplay = true }
    }

    override func highlight(_ flag: Bool) {
        super.highlight(flag)
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let foreground = desktopTheme == .glass
            ? NSColor.labelColor : WorkspaceTouchBarStyle.primaryTextColor
        if isHighlighted || isFrontmost {
            foreground.withAlphaComponent(isHighlighted ? 0.2 : 0.09).setFill()
            NSBezierPath(
                roundedRect: bounds,
                xRadius: WorkspaceTouchBarStyle.cornerRadius,
                yRadius: WorkspaceTouchBarStyle.cornerRadius
            ).fill()
        }
        let iconSide = max(min(20, bounds.height - 6, bounds.width - 4), 1)
        let iconRect = NSRect(
            x: floor(bounds.midX - iconSide / 2),
            y: max(floor((bounds.height - iconSide - 4) / 2), 0),
            width: iconSide,
            height: iconSide
        )
        icon?.draw(
            in: iconRect,
            from: .zero,
            operation: .sourceOver,
            fraction: isEnabled ? 1 : 0.5,
            respectFlipped: true,
            hints: [.interpolation: NSImageInterpolation.high]
        )
        if isRunning {
            foreground.withAlphaComponent(0.78).setFill()
            NSBezierPath(ovalIn: NSRect(
                x: bounds.midX - 1.5,
                y: min(iconRect.maxY + 1.5, bounds.maxY - 3),
                width: 3,
                height: 3
            )).fill()
        }
        if let badge = quotaBadge, let ratio = badge.ratio {
            let rect = NSRect(x: iconRect.maxX - 5, y: iconRect.maxY - 8, width: 9, height: 9)
            (desktopTheme == .black ? NSColor.black : NSColor.black.withAlphaComponent(0.55)).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: -1.5, dy: -1.5)).fill()
            foreground.withAlphaComponent(0.25).setFill()
            NSBezierPath(ovalIn: rect).fill()
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let wedge = NSBezierPath()
            wedge.move(to: center)
            wedge.appendArc(
                withCenter: center,
                radius: rect.width / 2,
                startAngle: -90,
                endAngle: -90 + 360 * CGFloat(min(max(ratio, 0), 1)),
                clockwise: false
            )
            wedge.close()
            WorkspaceTouchBarStyle.paceColor(for: badge, theme: desktopTheme).setFill()
            wedge.fill()
        }
    }

    func playLaunchFeedback() {
        guard let layer, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let center = CGPoint(x: bounds.midX, y: bounds.midY)
        func scaled(_ scale: CGFloat) -> NSValue {
            var transform = CATransform3DMakeTranslation(center.x, center.y, 0)
            transform = CATransform3DScale(transform, scale, scale, 1)
            transform = CATransform3DTranslate(transform, -center.x, -center.y, 0)
            return NSValue(caTransform3D: transform)
        }
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = [scaled(1), scaled(0.84), scaled(1.05), scaled(1)]
        animation.keyTimes = [0, 0.3, 0.7, 1]
        animation.duration = 0.36
        layer.add(animation, forKey: "launch")
    }
}

@MainActor
final class QuotaResetRingView: NSView {
    var progress: Double? {
        didSet { if oldValue != progress { needsDisplay = true } }
    }
    var showsBadge = false {
        didSet { if oldValue != showsBadge { needsDisplay = true } }
    }
    var desktopTheme: DesktopTheme = .black {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let foreground = desktopTheme == .glass
            ? NSColor.labelColor : WorkspaceTouchBarStyle.primaryTextColor
        let radius = min(bounds.width, bounds.height) / 2 - 1
        let center = NSPoint(x: bounds.midX, y: bounds.midY)
        let track = NSBezierPath(ovalIn: NSRect(
            x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2
        ))
        track.lineWidth = 1.6
        foreground.withAlphaComponent(progress == nil ? 0.08 : 0.14).setStroke()
        track.stroke()
        if let progress, progress > 0 {
            let arc = NSBezierPath()
            arc.appendArc(
                withCenter: center,
                radius: radius,
                startAngle: -90,
                endAngle: -90 + 360 * CGFloat(min(progress, 1)),
                clockwise: false
            )
            arc.lineWidth = 1.6
            arc.lineCapStyle = .round
            WorkspaceTouchBarStyle.resetBarColor.setStroke()
            arc.stroke()
        }
        if showsBadge {
            let badge = NSRect(x: bounds.maxX - 6, y: bounds.minY, width: 6, height: 6)
            NSColor.black.setFill()
            NSBezierPath(ovalIn: badge.insetBy(dx: -1, dy: -1)).fill()
            WorkspaceTouchBarStyle.amberAccent.setFill()
            NSBezierPath(ovalIn: badge).fill()
        }
    }
}

@MainActor
final class QuotaPaceRowView: NSView {
    static let captionWidth: CGFloat = 10
    static let valueWidth: CGFloat = 24

    var metric = QuotaBarMetric(ratio: nil, caption: "", valueText: "—", isHighlighted: false) {
        didSet { if oldValue != metric { needsDisplay = true } }
    }
    var desktopTheme: DesktopTheme = .black {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let foreground = desktopTheme == .glass
            ? NSColor.labelColor : WorkspaceTouchBarStyle.primaryTextColor
        let secondary = desktopTheme == .glass
            ? NSColor.secondaryLabelColor : WorkspaceTouchBarStyle.secondaryTextColor
        let midY = bounds.midY

        let caption = NSAttributedString(string: metric.caption, attributes: [
            .font: NSFont.systemFont(ofSize: 8, weight: .medium),
            .foregroundColor: metric.isHighlighted ? WorkspaceTouchBarStyle.amberAccent : secondary,
        ])
        caption.draw(at: NSPoint(x: 0, y: floor(midY - caption.size().height / 2)))

        let valueColor: NSColor
        if metric.ratio == nil {
            valueColor = secondary
        } else if metric.isHighlighted || metric.pace == .surplus {
            valueColor = WorkspaceTouchBarStyle.amberAccent
        } else if metric.pace == .deficit {
            valueColor = WorkspaceTouchBarStyle.paceDeficitColor
        } else {
            valueColor = foreground
        }
        let value = WorkspaceTouchBarStyle.compactValueText(metric.valueText, size: 10, color: valueColor)
        let valueSize = value.size()
        value.draw(at: NSPoint(x: bounds.maxX - valueSize.width, y: floor(midY - valueSize.height / 2)))

        let trackX = Self.captionWidth + 3
        let trackWidth = max(bounds.width - trackX - 3 - Self.valueWidth, 4)
        let track = NSRect(x: trackX, y: midY - 1.5, width: trackWidth, height: 3)
        foreground.withAlphaComponent(0.13).setFill()
        NSBezierPath(roundedRect: track, xRadius: 1.5, yRadius: 1.5).fill()
        guard let ratio = metric.ratio else { return }
        let fillWidth = ratio > 0 ? max(trackWidth * CGFloat(min(ratio, 1)), 2) : 0
        if fillWidth > 0 {
            WorkspaceTouchBarStyle.paceColor(for: metric, theme: desktopTheme).setFill()
            NSBezierPath(
                roundedRect: NSRect(x: trackX, y: track.minY, width: fillWidth, height: 3),
                xRadius: 1.5,
                yRadius: 1.5
            ).fill()
        }
        if let expected = metric.expectedRatio {
            let x = round(trackX + trackWidth * CGFloat(min(max(expected, 0), 1)))
            foreground.withAlphaComponent(0.85).setFill()
            NSBezierPath(
                roundedRect: NSRect(x: x - 0.5, y: midY - 3.5, width: 1, height: 7),
                xRadius: 0.5,
                yRadius: 0.5
            ).fill()
        }
    }
}

@MainActor
final class QuotaStackedTextView: NSView {
    enum Arrangement {
        case stacked
        case leading
        case inline
    }

    var arrangement: Arrangement = .stacked {
        didSet { needsDisplay = true }
    }
    var primary = "" {
        didSet { if oldValue != primary { needsDisplay = true } }
    }
    var secondary = "" {
        didSet { if oldValue != secondary { needsDisplay = true } }
    }
    var primarySize: CGFloat = 10 {
        didSet { needsDisplay = true }
    }
    var primaryColor: NSColor = WorkspaceTouchBarStyle.primaryTextColor {
        didSet { needsDisplay = true }
    }
    var secondaryColor: NSColor = WorkspaceTouchBarStyle.secondaryTextColor {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        let main = WorkspaceTouchBarStyle.compactValueText(primary, size: primarySize, color: primaryColor)
        let detail = NSAttributedString(string: secondary, attributes: [
            .font: NSFont.systemFont(ofSize: 7.5, weight: .medium),
            .foregroundColor: secondaryColor,
        ])
        let mainSize = main.size()
        let detailSize = secondary.isEmpty ? CGSize.zero : detail.size()
        switch arrangement {
        case .inline:
            let height = max(mainSize.height, detailSize.height)
            let y = bounds.midY - height / 2
            detail.draw(at: NSPoint(x: 0, y: floor(y + (height - detailSize.height) / 2)))
            let x = secondary.isEmpty ? 0 : detailSize.width + 3
            main.draw(at: NSPoint(x: x, y: floor(y + (height - mainSize.height) / 2)))
        case .stacked, .leading:
            let gap: CGFloat = secondary.isEmpty ? 0 : -2
            let total = mainSize.height + detailSize.height + gap
            let top = floor(bounds.midY - total / 2)
            let centered = arrangement == .stacked
            main.draw(at: NSPoint(x: centered ? floor(bounds.midX - mainSize.width / 2) : 0, y: top))
            if !secondary.isEmpty {
                detail.draw(at: NSPoint(
                    x: centered ? floor(bounds.midX - detailSize.width / 2) : 0,
                    y: top + mainSize.height + gap
                ))
            }
        }
    }
}

@MainActor
final class QuotaProviderGroupView: NSView {
    var desktopTheme: DesktopTheme = .black {
        didSet {
            guard oldValue != desktopTheme else { return }
            effectiveAppearance.performAsCurrentDrawingAppearance {
                if let state { display(state) }
                else { refreshChrome() }
            }
        }
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        effectiveAppearance.performAsCurrentDrawingAppearance {
            if let state { display(state) }
            else { refreshChrome() }
        }
    }

    private let ringView = QuotaResetRingView()
    private let iconView = NSImageView()
    private let fiveHourRow = QuotaPaceRowView()
    private let weeklyRow = QuotaPaceRowView()
    private let resetText = QuotaStackedTextView()
    private let detailText = QuotaStackedTextView()
    private let tapButton = NSButton()
    private(set) var state: QuotaProviderGroupState?
    var onActivate: ((QuotaProviderID) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.masksToBounds = true
        WorkspaceTouchBarStyle.applyItemChrome(
            to: layer,
            highlighted: false,
            enabled: true
        )
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.wantsLayer = true
        iconView.layer?.cornerRadius = 3.5
        iconView.layer?.masksToBounds = true
        resetText.arrangement = .stacked
        for view in [ringView, iconView, fiveHourRow, weeklyRow, resetText, detailText] {
            addSubview(view)
        }
        tapButton.isBordered = false
        tapButton.isTransparent = true
        tapButton.title = ""
        tapButton.imagePosition = .noImage
        tapButton.setAccessibilityElement(false)
        tapButton.target = self
        tapButton.action = #selector(activate)
        addSubview(tapButton)
        setAccessibilityElement(true)
        setAccessibilityRole(.button)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    func display(_ state: QuotaProviderGroupState) {
        self.state = state
        let foreground = desktopTheme == .glass
            ? NSColor.labelColor : WorkspaceTouchBarStyle.primaryTextColor
        let secondary = desktopTheme == .glass
            ? NSColor.secondaryLabelColor : WorkspaceTouchBarStyle.secondaryTextColor
        iconView.image = WorkspaceTouchBarStyle.providerIcon(
            for: state.provider,
            foregroundColor: foreground
        )
        iconView.contentTintColor = foreground
        ringView.desktopTheme = desktopTheme
        ringView.showsBadge = state.isRecommended
        for view in [fiveHourRow, weeklyRow] { view.desktopTheme = desktopTheme }
        for view in [resetText, detailText] {
            view.primaryColor = foreground
            view.secondaryColor = secondary
        }
        toolTip = state.tooltip

        if let balance = state.balance {
            ringView.progress = nil
            fiveHourRow.isHidden = true
            weeklyRow.isHidden = true
            resetText.isHidden = true
            detailText.isHidden = false
            detailText.arrangement = .leading
            detailText.primarySize = 11.5
            detailText.primary = balance.valueText
            detailText.secondary = balance.caption
            setAccessibilityLabel("\(state.title) 额度，\(balance.caption) \(balance.valueText)")
            refreshChrome()
            needsLayout = true
            return
        }

        ringView.progress = state.reset.ratio
        fiveHourRow.isHidden = !state.fiveHour.isAvailable
        fiveHourRow.metric = state.fiveHour
        weeklyRow.isHidden = false
        weeklyRow.metric = state.weekly
        if state.fiveHour.isAvailable {
            let parts = QuotaDisplayFormatting.countdownParts(state.reset.valueText)
            resetText.isHidden = false
            detailText.isHidden = true
            resetText.primarySize = 10
            resetText.primary = parts.major
            resetText.secondary = parts.minor
        } else {
            resetText.isHidden = true
            detailText.isHidden = false
            detailText.arrangement = .inline
            detailText.primarySize = 9
            detailText.primary = state.reset.valueText
            detailText.secondary = "重置"
        }
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
        tapButton.frame = bounds
        guard bounds.width > 1, bounds.height > 1 else { return }

        let padding: CGFloat = 4
        let gap: CGFloat = 5
        let ringSide = max(min(22, bounds.height - 2), 1)
        ringView.frame = NSRect(
            x: padding,
            y: floor((bounds.height - ringSide) / 2),
            width: ringSide,
            height: ringSide
        )
        let iconInset = min(4, ringSide / 4)
        iconView.frame = ringView.frame.insetBy(dx: iconInset, dy: iconInset)
        let contentX = ringView.frame.maxX + gap
        let trailing: CGFloat = 5

        if state?.balance != nil {
            detailText.frame = NSRect(
                x: contentX,
                y: 0,
                width: max(bounds.width - contentX - trailing, 1),
                height: bounds.height
            )
            return
        }

        let rowHeight: CGFloat = 11
        let top = floor((bounds.height - rowHeight * 2) / 2)
        if state?.fiveHour.isAvailable == true {
            let countdownWidth: CGFloat = 20
            let rowWidth = max(bounds.width - contentX - gap - countdownWidth - trailing, 1)
            fiveHourRow.frame = NSRect(x: contentX, y: top, width: rowWidth, height: rowHeight)
            weeklyRow.frame = NSRect(x: contentX, y: top + rowHeight, width: rowWidth, height: rowHeight)
            resetText.frame = NSRect(
                x: bounds.width - trailing - countdownWidth,
                y: 0,
                width: countdownWidth,
                height: bounds.height
            )
        } else {
            let rowWidth = max(bounds.width - contentX - trailing, 1)
            fiveHourRow.frame = .zero
            weeklyRow.frame = NSRect(x: contentX, y: top, width: rowWidth, height: rowHeight)
            detailText.frame = NSRect(x: contentX, y: top + rowHeight, width: rowWidth, height: rowHeight)
        }
    }

    func playRecommendationFlash() {
        guard let layer, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let animation = CABasicAnimation(keyPath: "backgroundColor")
        animation.fromValue = WorkspaceTouchBarStyle.amberAccent.withAlphaComponent(0.55).cgColor
        animation.toValue = layer.backgroundColor
        animation.duration = 0.9
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: "recommendation")
    }

    @objc private func activate() {
        guard let state else { return }
        if let layer, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            let animation = CABasicAnimation(keyPath: "backgroundColor")
            animation.fromValue = (desktopTheme == .glass ? NSColor.labelColor : NSColor.white)
                .withAlphaComponent(0.24).cgColor
            animation.toValue = layer.backgroundColor
            animation.duration = 0.3
            layer.add(animation, forKey: "press")
        }
        onActivate?(state.provider)
    }

    override func accessibilityPerformPress() -> Bool {
        activate()
        return true
    }

    private func refreshChrome() {
        effectiveAppearance.performAsCurrentDrawingAppearance {
            DesktopThemeChrome.apply(to: layer, theme: desktopTheme)
            if state?.isRecommended == true {
                layer?.borderWidth = 1
                layer?.borderColor = WorkspaceTouchBarStyle.amberAccent
                    .withAlphaComponent(0.7).cgColor
                layer?.backgroundColor = WorkspaceTouchBarStyle
                    .recommendedFill(theme: desktopTheme).cgColor
            }
        }
    }
}

struct QuotaScrollState: Equatable {
    let viewportWidth: CGFloat
    let contentWidth: CGFloat
    let offset: CGFloat
}

@MainActor
final class QuotaPlateView: NSView {
    private var desktopTheme: DesktopTheme = .black

    func setDesktopTheme(_ theme: DesktopTheme) {
        guard desktopTheme != theme else { return }
        desktopTheme = theme
        emptyLabel.textColor = theme == .glass ? .secondaryLabelColor : WorkspaceTouchBarStyle.secondaryTextColor
        groupViews.forEach { $0.desktopTheme = theme }
    }
    private let emptyLabel = NSTextField(labelWithString: "打开 OpenUsage 后显示订阅额度")
    var onOpenProvider: ((QuotaProviderID) -> Void)? {
        didSet { groupViews.forEach { $0.onActivate = onOpenProvider } }
    }
    private let scrollView = NSScrollView()
    private let documentView = NSView()
    private(set) var groupViews: [QuotaProviderGroupView] = []
    private var state = QuotaBoardState.empty
    private var displayedStyle: QuotaMetricDisplayStyle?
    private var leadingProvider: QuotaProviderID?
    private var pendingScrollReset = false
    private(set) var contentWidth: CGFloat = 0
    private(set) var needsHorizontalScroll = false
    private var mirroredScrollState: QuotaScrollState?
    private var lastPublishedScrollState: QuotaScrollState?
    private var isLayingOut = false
    var onScrollStateChanged: ((QuotaScrollState) -> Void)? {
        didSet {
            lastPublishedScrollState = nil
            publishScrollState()
        }
    }

    func mirrorScrollState(_ state: QuotaScrollState?) {
        if let state, state.viewportWidth <= 1 { return }
        guard mirroredScrollState != state else { return }
        let geometryChanged = mirroredScrollState?.viewportWidth != state?.viewportWidth
            || mirroredScrollState?.contentWidth != state?.contentWidth
        mirroredScrollState = state
        if geometryChanged {
            needsLayout = true
            layoutSubtreeIfNeeded()
        } else {
            applyMirroredScrollPosition()
        }
    }

    private func applyMirroredScrollPosition() {
        guard let state = mirroredScrollState, bounds.width > 1 else { return }
        let scale = bounds.width / state.viewportWidth
        let offset = min(max(state.offset * scale, 0), max(contentWidth - bounds.width, 0))
        scrollView.contentView.scroll(to: NSPoint(x: offset, y: 0))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func publishScrollState() {
        guard !isLayingOut, scrollView.contentView.bounds.width > 1,
              let onScrollStateChanged else { return }
        let viewportWidth = scrollView.contentView.bounds.width
        let state = QuotaScrollState(viewportWidth: viewportWidth, contentWidth: contentWidth,
            offset: min(max(scrollView.contentView.bounds.minX, 0), max(contentWidth - viewportWidth, 0)))
        guard state != lastPublishedScrollState else { return }
        lastPublishedScrollState = state
        onScrollStateChanged(state)
    }

    @objc private func scrollBoundsChanged(_ notification: Notification) {
        publishScrollState()
    }

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
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(scrollBoundsChanged(_:)),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
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
        let style = WorkspacePreferences.quotaMetricDisplayStyle
        guard self.state != state || displayedStyle != style else { return }
        let styleChanged = displayedStyle != style
        let previousRecommended = self.state.recommendedProvider
        displayedStyle = style
        self.state = state
        let newLeading = state.groups.first?.provider
        if newLeading != leadingProvider {
            pendingScrollReset = true
            leadingProvider = newLeading
        }
        var retainedViews = Dictionary(uniqueKeysWithValues: groupViews.compactMap { view in
            view.state.map { ($0.provider, view) }
        })
        groupViews.removeAll(keepingCapacity: true)
        emptyLabel.isHidden = !state.isEmpty
        emptyLabel.stringValue = "打开 OpenUsage 后显示订阅额度"
        scrollView.isHidden = state.isEmpty
        toolTip = state.isEmpty ? "暂无订阅额度数据" : nil
        for group in state.groups {
            let view = retainedViews.removeValue(forKey: group.provider) ?? QuotaProviderGroupView()
            view.onActivate = onOpenProvider
            view.desktopTheme = desktopTheme
            if view.state != group || styleChanged { view.display(group) }
            if view.superview == nil { documentView.addSubview(view) }
            groupViews.append(view)
        }
        retainedViews.values.forEach { $0.removeFromSuperview() }
        if let recommended = state.recommendedProvider,
           let previousRecommended, previousRecommended != recommended {
            groupViews.first { $0.state?.provider == recommended }?.playRecommendationFlash()
        }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        guard bounds.width > 1, bounds.height > 1 else { return }
        isLayingOut = true
        defer {
            isLayingOut = false
            publishScrollState()
        }
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
            plateWidth: mirroredScrollState?.viewportWidth ?? bounds.width,
            showsFiveHourPerGroup: showsFiveHour
        )
        let scale = mirroredScrollState.map { bounds.width / $0.viewportWidth } ?? 1
        contentWidth = arrangement.contentWidth * scale
        needsHorizontalScroll = arrangement.needsScroll
        scrollView.horizontalScrollElasticity = arrangement.needsScroll
            ? .allowed
            : .none
        documentView.frame = NSRect(
            x: 0,
            y: 0,
            width: contentWidth,
            height: bounds.height
        )
        var x: CGFloat = 0
        let spacing = WorkspaceTouchBarLayout.quotaGroupSpacing * scale
        for (index, view) in groupViews.enumerated() {
            let groupWidth = index < arrangement.groupWidths.count
                ? arrangement.groupWidths[index]
                : WorkspaceTouchBarLayout.quotaGroupMinimumWidth
            view.frame = NSRect(
                x: x,
                y: 0,
                width: groupWidth * scale,
                height: bounds.height
            )
            x += groupWidth * scale + spacing
        }
        let maxOffset = max(contentWidth - bounds.width, 0)
        scrollView.contentView.scroll(
            to: NSPoint(
                x: min(max(previousOffset, 0), maxOffset),
                y: 0
            )
        )
        applyMirroredScrollPosition()
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

        if hadPreviousMode, let previousMode {
            return .set(previousMode)
        }
        return .remove
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
    private var contentSizeConstraints: (
        minimum: NSLayoutConstraint, preferred: NSLayoutConstraint, maximum: NSLayoutConstraint
    )?
    private var previousPresentationMode: String?
    private var hadPreviousPresentationMode = false
    private lazy var recovery = TouchBarPresentationRecovery { [weak self] in
        guard let self, self.isPresented else { return true }
        guard self.contentView.window == nil || self.returnView.window == nil else { return true }
        if TouchBarPresentationPreferences.currentMode != WorkspaceTouchBarLayout.presentationMode {
            self.dismiss()
            self.onPresentationInterrupted?()
            return true
        }
        TBRDismissSystemModalTouchBar(self.touchBar)
        TBRPresentSystemModalTouchBar(self.touchBar, WorkspaceTouchBarLayout.placement)
        return self.contentView.window != nil && self.returnView.window != nil
    }
    private(set) var isPresented = false

    var onOpenSettings: (() -> Void)?
    var onOpenCustomApp: ((CustomWorkspaceApp) -> Void)?
    var onPresentationInterrupted: (() -> Void)?
    var onToggleWorkspace: (() -> Void)?
    var onCollapse: (() -> Void)?

    var onOpenQuotaProvider: ((QuotaProviderID) -> Void)? {
        didSet { quotaPlate.onOpenProvider = onOpenQuotaProvider }
    }

    func playLaunchFeedback(for app: CustomWorkspaceApp) {
        customAppsView.playLaunchFeedback(for: app)
    }

    var onQuotaScrollStateChanged: ((QuotaScrollState) -> Void)? {
        didSet { quotaPlate.onScrollStateChanged = onQuotaScrollStateChanged }
    }

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
        contentView.onCollapse = { [weak self] in self?.onCollapse?() }
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

        let storedMode = TouchBarPresentationModeGuard.beginOverride(
            currentMode: TouchBarPresentationPreferences.currentMode,
            overrideMode: WorkspaceTouchBarLayout.presentationMode
        )
        hadPreviousPresentationMode = storedMode != nil
        previousPresentationMode = storedMode
        isPresented = true
        TBRSetSystemModalShowsCloseBoxWhenFrontMost(false)
        TBRPresentSystemModalTouchBar(
            touchBar,
            WorkspaceTouchBarLayout.placement
        )
        TouchBarPresentationPreferences.setCurrentMode(
            WorkspaceTouchBarLayout.presentationMode
        )
        recovery.schedule()
    }

    func dismiss() {
        guard isPresented else { return }
        isPresented = false
        recovery.cancel()
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
        TouchBarPresentationModeGuard.endOverride()
        TBRDismissSystemModalTouchBar(touchBar)
        TBRSetSystemModalShowsCloseBoxWhenFrontMost(true)
        previousPresentationMode = nil
        hadPreviousPresentationMode = false
    }

    func showQuota(_ state: QuotaBoardState) {
        quotaPlate.display(state)
        customAppsView.showQuota(state)
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
            updateContentSizeConstraints()
            item.view = contentView
            return item
        default:
            return nil
        }
    }

    func reconcilePresentation() {
        guard isPresented else { return }
        recovery.schedule()
    }

    private func updateContentSizeConstraints() {
        let preferredWidthValue = WorkspaceTouchBarLayout.preferredTrayWidth()
        let minimumWidthValue = min(WorkspaceTouchBarLayout.minimumContentWidth, preferredWidthValue)
        if let constraints = contentSizeConstraints {
            constraints.minimum.constant = minimumWidthValue
            constraints.preferred.constant = preferredWidthValue
            constraints.maximum.constant = preferredWidthValue
            return
        }
        contentView.heightAnchor.constraint(
            equalToConstant: WorkspaceTouchBarStyle.controlHeight
        ).isActive = true
        let minWidth = contentView.widthAnchor.constraint(greaterThanOrEqualToConstant: minimumWidthValue)
        minWidth.priority = .defaultHigh
        let preferredWidth = contentView.widthAnchor.constraint(equalToConstant: preferredWidthValue)
        preferredWidth.priority = .defaultLow
        let maxWidth = contentView.widthAnchor.constraint(lessThanOrEqualToConstant: preferredWidthValue)
        maxWidth.priority = .required
        NSLayoutConstraint.activate([minWidth, preferredWidth, maxWidth])
        contentSizeConstraints = (minWidth, preferredWidth, maxWidth)
    }

    private func handleWindowAttachmentChanged(_ attached: Bool) {
        reconcilePresentation()
    }

}
