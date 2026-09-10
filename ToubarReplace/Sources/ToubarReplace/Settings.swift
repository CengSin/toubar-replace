import AppKit

enum TouchBarDisplayPosition: String, CaseIterable {
    case bottom
    case top
    case center
    /// Restore AppKit autosaved mirror frame origin on launch.
    case lastSaved
    /// Use explicit top-left coordinates from preferences.
    case custom

    var title: String {
        switch self {
        case .bottom:
            return "底部（默认）"
        case .top:
            return "顶部"
        case .center:
            return "屏幕中央"
        case .lastSaved:
            return "上次关闭时的位置"
        case .custom:
            return "自定义坐标"
        }
    }

    var usesCustomTopLeft: Bool {
        self == .custom
    }

    var restoresAutosavedFrame: Bool {
        self == .lastSaved
    }
}

enum TouchBarPreferences {
    private static let positionKey = "ToubarReplace.displayPosition"
    private static let widthPixelsKey = "ToubarReplace.widthPixels"
    private static let heightPixelsKey = "ToubarReplace.heightPixels"
    private static let customTopLeftXKey = "ToubarReplace.customTopLeftX"
    private static let customTopLeftYKey = "ToubarReplace.customTopLeftY"

    static let mirrorWindowAutosaveName = "ToubarReplaceMirrorWindow"
    static let settingsWindowAutosaveName = "ToubarReplaceSettingsWindow"

    private static let legacyDefaultMirrorPixelSize = CGSize(
        width: 2_008,
        height: 60
    )
    static let defaultMirrorPixelSize = CGSize(width: 2_300, height: 70)

    static var displayPosition: TouchBarDisplayPosition {
        get {
            guard
                let rawValue = UserDefaults.standard.string(forKey: positionKey),
                let position = TouchBarDisplayPosition(rawValue: rawValue)
            else {
                return .bottom
            }
            return position
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: positionKey)
        }
    }

    /// Whether the user has explicitly saved a custom top-left origin.
    static var hasCustomTopLeft: Bool {
        UserDefaults.standard.object(forKey: customTopLeftXKey) != nil
            && UserDefaults.standard.object(forKey: customTopLeftYKey) != nil
    }

    /// Top-left of the mirror window in AppKit screen points
    /// (`y` increases upward).
    static var customTopLeft: CGPoint {
        get {
            CGPoint(
                x: UserDefaults.standard.double(forKey: customTopLeftXKey),
                y: UserDefaults.standard.double(forKey: customTopLeftYKey)
            )
        }
        set {
            UserDefaults.standard.set(newValue.x, forKey: customTopLeftXKey)
            UserDefaults.standard.set(newValue.y, forKey: customTopLeftYKey)
        }
    }

    static var mirrorPixelSize: CGSize {
        get {
            let width = UserDefaults.standard.double(forKey: widthPixelsKey)
            let height = UserDefaults.standard.double(forKey: heightPixelsKey)
            guard width > 0, height > 0 else {
                return defaultMirrorPixelSize
            }
            if width == legacyDefaultMirrorPixelSize.width,
                height == legacyDefaultMirrorPixelSize.height
            {
                return defaultMirrorPixelSize
            }
            return CGSize(width: width, height: height)
        }
        set {
            UserDefaults.standard.set(
                max(newValue.width.rounded(), 1),
                forKey: widthPixelsKey
            )
            UserDefaults.standard.set(
                max(newValue.height.rounded(), 1),
                forKey: heightPixelsKey
            )
        }
    }
}

private final class SettingsDocumentView: NSView {
    override var isFlipped: Bool { true }
}

@MainActor
final class TouchBarSettingsWindowController: NSWindowController,
    NSWindowDelegate
{
    private let positionPopup: NSPopUpButton
    private let originXField: NSTextField
    private let originYField: NSTextField
    private let switcherDisplayModePopup: NSPopUpButton
    private let startupScenePopup: NSPopUpButton
    private let quotaDisplayStylePopup: NSPopUpButton
    private let widthField: NSTextField
    private let heightField: NSTextField
    private let customAppsStack: NSStackView
    private let quotaProvidersStack: NSStackView
    private var quotaProviderChoices: [QuotaProviderChoice] = []
    private let onPositionChanged: (TouchBarDisplayPosition) -> Void
    private let onCustomTopLeftChanged: (CGPoint) -> Void
    private let onWorkspaceFloatingSwitcherChanged: (Bool) -> Void
    private let onWorkspaceStartupSceneChanged: (WorkspaceStartupScene) -> Void
    private let onPixelSizeChanged: (CGSize) -> Void
    private let onPickApplication: (@escaping (URL?) -> Void) -> Void
    private let onCustomAppsChanged: () -> Void
    private let onQuotaVisibilityChanged: () -> Void
    private let onQuotaDisplayStyleChanged: () -> Void
    private let onWindowClosed: () -> Void

    init(
        currentPosition: TouchBarDisplayPosition,
        currentCustomTopLeft: CGPoint,
        currentPixelSize: CGSize,
        currentWorkspaceSwitcherFloats: Bool,
        currentWorkspaceStartupScene: WorkspaceStartupScene,
        onPositionChanged: @escaping (TouchBarDisplayPosition) -> Void,
        onCustomTopLeftChanged: @escaping (CGPoint) -> Void,
        onWorkspaceFloatingSwitcherChanged: @escaping (Bool) -> Void,
        onWorkspaceStartupSceneChanged: @escaping (WorkspaceStartupScene) -> Void,
        onPixelSizeChanged: @escaping (CGSize) -> Void,
        onPickApplication: @escaping (@escaping (URL?) -> Void) -> Void,
        onCustomAppsChanged: @escaping () -> Void,
        onQuotaVisibilityChanged: @escaping () -> Void,
        onQuotaDisplayStyleChanged: @escaping () -> Void,
        onWindowClosed: @escaping () -> Void
    ) {
        self.positionPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        self.originXField = NSTextField()
        self.originYField = NSTextField()
        self.switcherDisplayModePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        self.startupScenePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        self.quotaDisplayStylePopup = NSPopUpButton(frame: .zero, pullsDown: false)
        self.widthField = NSTextField()
        self.heightField = NSTextField()
        self.customAppsStack = NSStackView()
        self.quotaProvidersStack = NSStackView()
        self.onPositionChanged = onPositionChanged
        self.onCustomTopLeftChanged = onCustomTopLeftChanged
        self.onWorkspaceFloatingSwitcherChanged = onWorkspaceFloatingSwitcherChanged
        self.onWorkspaceStartupSceneChanged = onWorkspaceStartupSceneChanged
        self.onPixelSizeChanged = onPixelSizeChanged
        self.onPickApplication = onPickApplication
        self.onCustomAppsChanged = onCustomAppsChanged
        self.onQuotaVisibilityChanged = onQuotaVisibilityChanged
        self.onQuotaDisplayStyleChanged = onQuotaDisplayStyleChanged
        self.onWindowClosed = onWindowClosed

        let contentView = SettingsDocumentView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        let titleLabel = NSTextField(labelWithString: "Touch Bar 镜像设置")
        titleLabel.font = .systemFont(ofSize: 18, weight: .semibold)

        let positionLabel = NSTextField(labelWithString: "展示位置")
        positionPopup.addItems(withTitles: TouchBarDisplayPosition.allCases.map(\.title))
        positionPopup.selectItem(
            at: TouchBarDisplayPosition.allCases.firstIndex(of: currentPosition) ?? 0
        )

        let originLabel = NSTextField(labelWithString: "起始坐标")
        let originXCaption = NSTextField(labelWithString: "X")
        let originYCaption = NSTextField(labelWithString: "Y")
        let originUnitLabel = NSTextField(labelWithString: "pt（窗口左上角）")
        originUnitLabel.textColor = .secondaryLabelColor
        let originFormatter = NumberFormatter()
        originFormatter.allowsFloats = true
        originFormatter.minimumFractionDigits = 0
        originFormatter.maximumFractionDigits = 1
        originFormatter.minimum = -20_000
        originFormatter.maximum = 20_000
        originXField.formatter = originFormatter
        originYField.formatter = originFormatter
        originXField.alignment = .right
        originYField.alignment = .right
        originXField.doubleValue = currentCustomTopLeft.x
        originYField.doubleValue = currentCustomTopLeft.y

        let switcherModeLabel = NSTextField(labelWithString: "切换按钮")
        switcherDisplayModePopup.addItems(
            withTitles: WorkspaceSwitcherDisplayMode.allCases.map(\.title)
        )
        let currentMode: WorkspaceSwitcherDisplayMode =
            TouchBarHardwareCapability.usesSoftwareWorkspace
            ? .floating
            : (currentWorkspaceSwitcherFloats ? .floating : .touchBar)
        switcherDisplayModePopup.selectItem(
            at: WorkspaceSwitcherDisplayMode.allCases.firstIndex(of: currentMode) ?? 0
        )
        // No physical bar: only the floating switcher is available.
        if TouchBarHardwareCapability.usesSoftwareWorkspace,
            let touchBarItem = switcherDisplayModePopup.item(
                at: WorkspaceSwitcherDisplayMode.allCases.firstIndex(of: .touchBar) ?? -1
            )
        {
            touchBarItem.isEnabled = false
        }

        let startupSceneLabel = NSTextField(labelWithString: "启动后进入")
        startupScenePopup.addItems(
            withTitles: WorkspaceStartupScene.allCases.map(\.title)
        )
        startupScenePopup.selectItem(
            at: WorkspaceStartupScene.allCases.firstIndex(
                of: currentWorkspaceStartupScene
            ) ?? 0
        )

        let sizeLabel = NSTextField(labelWithString: "窗口像素")
        let multiplicationLabel = NSTextField(labelWithString: "×")
        let pixelsLabel = NSTextField(labelWithString: "px")
        let formatter = NumberFormatter()
        formatter.allowsFloats = false
        formatter.minimum = 1
        formatter.maximum = 20_000
        widthField.formatter = formatter
        heightField.formatter = formatter
        widthField.alignment = .right
        heightField.alignment = .right
        widthField.integerValue = Int(currentPixelSize.width.rounded())
        heightField.integerValue = Int(currentPixelSize.height.rounded())

        let quotaSectionLabel = NSTextField(labelWithString: "用量订阅")
        quotaSectionLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        let quotaDisplayStyleLabel = NSTextField(labelWithString: "额度样式")
        quotaDisplayStylePopup.addItems(
            withTitles: QuotaMetricDisplayStyle.allCases.map(\.title)
        )
        let currentQuotaStyle = WorkspacePreferences.quotaMetricDisplayStyle
        quotaDisplayStylePopup.selectItem(
            at: QuotaMetricDisplayStyle.allCases.firstIndex(
                of: currentQuotaStyle
            ) ?? 0
        )
        quotaProvidersStack.orientation = .vertical
        quotaProvidersStack.alignment = .leading
        quotaProvidersStack.spacing = 6
        quotaProvidersStack.translatesAutoresizingMaskIntoConstraints = false

        let customAppsSectionLabel = NSTextField(labelWithString: "自定义 App")
        customAppsSectionLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        customAppsStack.orientation = .vertical
        customAppsStack.alignment = .leading
        customAppsStack.spacing = 8
        customAppsStack.translatesAutoresizingMaskIntoConstraints = false

        let positionRow = NSStackView(views: [positionLabel, positionPopup])
        positionRow.orientation = .horizontal
        positionRow.spacing = 12
        positionRow.alignment = .centerY

        let originRow = NSStackView(
            views: [
                originLabel,
                originXCaption,
                originXField,
                originYCaption,
                originYField,
                originUnitLabel,
            ]
        )
        originRow.orientation = .horizontal
        originRow.spacing = 8
        originRow.alignment = .centerY

        let switcherModeRow = NSStackView(views: [switcherModeLabel, switcherDisplayModePopup])
        switcherModeRow.orientation = .horizontal
        switcherModeRow.spacing = 12
        switcherModeRow.alignment = .centerY

        let startupSceneRow = NSStackView(
            views: [startupSceneLabel, startupScenePopup]
        )
        startupSceneRow.orientation = .horizontal
        startupSceneRow.spacing = 12
        startupSceneRow.alignment = .centerY

        let quotaDisplayStyleRow = NSStackView(
            views: [quotaDisplayStyleLabel, quotaDisplayStylePopup]
        )
        quotaDisplayStyleRow.orientation = .horizontal
        quotaDisplayStyleRow.spacing = 12
        quotaDisplayStyleRow.alignment = .centerY

        let sizeRow = NSStackView(
            views: [sizeLabel, widthField, multiplicationLabel, heightField, pixelsLabel]
        )
        sizeRow.orientation = .horizontal
        sizeRow.spacing = 8
        sizeRow.alignment = .centerY

        let stack = NSStackView(
            views: [
                titleLabel,
                positionRow,
                originRow,
                switcherModeRow,
                startupSceneRow,
                sizeRow,
                quotaSectionLabel,
                quotaDisplayStyleRow,
                quotaProvidersStack,
                customAppsSectionLabel,
                customAppsStack,
            ]
        )
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 18
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24),
            positionLabel.widthAnchor.constraint(equalToConstant: 72),
            originLabel.widthAnchor.constraint(equalToConstant: 72),
            switcherModeLabel.widthAnchor.constraint(equalToConstant: 72),
            startupSceneLabel.widthAnchor.constraint(equalToConstant: 72),
            quotaDisplayStyleLabel.widthAnchor.constraint(equalToConstant: 72),
            sizeLabel.widthAnchor.constraint(equalToConstant: 72),
            positionPopup.widthAnchor.constraint(equalToConstant: 180),
            switcherDisplayModePopup.widthAnchor.constraint(equalToConstant: 180),
            startupScenePopup.widthAnchor.constraint(equalToConstant: 180),
            quotaDisplayStylePopup.widthAnchor.constraint(equalToConstant: 180),
            originXField.widthAnchor.constraint(equalToConstant: 70),
            originYField.widthAnchor.constraint(equalToConstant: 70),
            widthField.widthAnchor.constraint(equalToConstant: 90),
            heightField.widthAnchor.constraint(equalToConstant: 70),
            customAppsStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
            quotaProvidersStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
        ])

        let initialContentRect = NSRect(x: 0, y: 0, width: 560, height: 720)
        let scrollView = NSScrollView(frame: initialContentRect)
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.documentView = contentView
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(
                equalTo: scrollView.contentView.leadingAnchor
            ),
            contentView.topAnchor.constraint(
                equalTo: scrollView.contentView.topAnchor
            ),
            contentView.widthAnchor.constraint(
                equalTo: scrollView.contentView.widthAnchor
            ),
            contentView.heightAnchor.constraint(
                greaterThanOrEqualTo: scrollView.contentView.heightAnchor
            ),
        ])

        let window = NSWindow(
            contentRect: initialContentRect,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ToubarReplace 设置"
        window.contentView = scrollView
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 480, height: 480)
        let restoredFrame = window.setFrameUsingName(
            TouchBarPreferences.settingsWindowAutosaveName
        )
        window.setFrameAutosaveName(
            TouchBarPreferences.settingsWindowAutosaveName
        )
        if !restoredFrame {
            window.center()
        }

        super.init(window: window)
        window.delegate = self
        positionPopup.target = self
        positionPopup.action = #selector(positionChanged(_:))
        originXField.target = self
        originXField.action = #selector(customTopLeftChanged(_:))
        originYField.target = self
        originYField.action = #selector(customTopLeftChanged(_:))
        switcherDisplayModePopup.target = self
        switcherDisplayModePopup.action = #selector(switcherDisplayModeChanged(_:))
        startupScenePopup.target = self
        startupScenePopup.action = #selector(startupSceneChanged(_:))
        quotaDisplayStylePopup.target = self
        quotaDisplayStylePopup.action = #selector(quotaDisplayStyleChanged(_:))
        widthField.target = self
        widthField.action = #selector(pixelSizeChanged(_:))
        heightField.target = self
        heightField.action = #selector(pixelSizeChanged(_:))
        updateCustomOriginFieldsEnabled(for: currentPosition)
        rebuildCustomAppsRows()
        reloadQuotaProviderRows(WorkspacePreferences.seenQuotaProviders)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func windowWillClose(_ notification: Notification) {
        onWindowClosed()
    }

    func reloadCustomAppsRows() {
        rebuildCustomAppsRows()
    }

    func reloadQuotaProviderRows(_ choices: [QuotaProviderChoice]) {
        quotaProviderChoices = choices
        rebuildQuotaProviderRows()
    }

    private func rebuildQuotaProviderRows() {
        for view in quotaProvidersStack.arrangedSubviews {
            quotaProvidersStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let hint = NSTextField(
            labelWithString: "勾选的订阅会出现在用量区，可左右滑动查看。"
        )
        hint.textColor = .secondaryLabelColor
        hint.font = .systemFont(ofSize: 11)
        hint.lineBreakMode = .byWordWrapping
        hint.maximumNumberOfLines = 2
        quotaProvidersStack.addArrangedSubview(hint)

        if quotaProviderChoices.isEmpty {
            let empty = NSTextField(
                labelWithString: "还没有读到订阅。请确认本机已安装 OpenUsage。"
            )
            empty.textColor = .secondaryLabelColor
            empty.font = .systemFont(ofSize: 12)
            quotaProvidersStack.addArrangedSubview(empty)
            return
        }

        let showAll = NSButton(
            title: "全部显示",
            target: self,
            action: #selector(showAllQuotaProviders)
        )
        showAll.bezelStyle = .rounded
        let hideAll = NSButton(
            title: "全部隐藏",
            target: self,
            action: #selector(hideAllQuotaProviders)
        )
        hideAll.bezelStyle = .rounded
        let bulkRow = NSStackView(views: [showAll, hideAll])
        bulkRow.orientation = .horizontal
        bulkRow.spacing = 8
        bulkRow.alignment = .centerY
        quotaProvidersStack.addArrangedSubview(bulkRow)

        for choice in quotaProviderChoices {
            quotaProvidersStack.addArrangedSubview(
                makeQuotaProviderRow(choice: choice)
            )
        }
    }

    private func makeQuotaProviderRow(choice: QuotaProviderChoice) -> NSView {
        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = WorkspaceTouchBarStyle.providerIcon(for: choice.id)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let check = NSButton(
            checkboxWithTitle: choice.title,
            target: self,
            action: #selector(toggleQuotaProvider(_:))
        )
        check.identifier = NSUserInterfaceItemIdentifier(choice.id.rawValue)
        check.state = WorkspacePreferences.isQuotaProviderVisible(choice.id)
            ? .on
            : .off
        check.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        let row = NSStackView(views: [iconView, check])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
        ])
        return row
    }

    @objc
    private func toggleQuotaProvider(_ sender: NSButton) {
        guard let rawValue = sender.identifier?.rawValue else { return }
        WorkspacePreferences.setQuotaProvider(
            QuotaProviderID(rawValue),
            visible: sender.state == .on
        )
        onQuotaVisibilityChanged()
    }

    @objc
    private func showAllQuotaProviders() {
        WorkspacePreferences.hiddenQuotaProviderIDs = []
        rebuildQuotaProviderRows()
        onQuotaVisibilityChanged()
    }

    @objc
    private func hideAllQuotaProviders() {
        WorkspacePreferences.hiddenQuotaProviderIDs = Set(
            quotaProviderChoices.map(\.id.rawValue)
        )
        rebuildQuotaProviderRows()
        onQuotaVisibilityChanged()
    }

    func updateCustomTopLeft(_ topLeft: CGPoint) {
        originXField.doubleValue = topLeft.x
        originYField.doubleValue = topLeft.y
    }

    @objc
    private func positionChanged(_ sender: NSPopUpButton) {
        let itemIndex = sender.indexOfSelectedItem
        guard TouchBarDisplayPosition.allCases.indices.contains(itemIndex) else {
            return
        }
        let position = TouchBarDisplayPosition.allCases[itemIndex]
        updateCustomOriginFieldsEnabled(for: position)
        onPositionChanged(position)
    }

    @objc
    private func customTopLeftChanged(_ sender: NSTextField) {
        let topLeft = CGPoint(
            x: originXField.doubleValue,
            y: originYField.doubleValue
        )
        updateCustomTopLeft(topLeft)
        onCustomTopLeftChanged(topLeft)
    }

    @objc
    private func startupSceneChanged(_ sender: NSPopUpButton) {
        let itemIndex = sender.indexOfSelectedItem
        guard WorkspaceStartupScene.allCases.indices.contains(itemIndex) else {
            return
        }
        onWorkspaceStartupSceneChanged(WorkspaceStartupScene.allCases[itemIndex])
    }

    @objc
    private func quotaDisplayStyleChanged(_ sender: NSPopUpButton) {
        let styles = QuotaMetricDisplayStyle.allCases
        guard styles.indices.contains(sender.indexOfSelectedItem) else { return }
        WorkspacePreferences.quotaMetricDisplayStyle =
            styles[sender.indexOfSelectedItem]
        onQuotaDisplayStyleChanged()
    }

    @objc
    private func switcherDisplayModeChanged(_ sender: NSPopUpButton) {
        let itemIndex = sender.indexOfSelectedItem
        guard WorkspaceSwitcherDisplayMode.allCases.indices.contains(itemIndex) else {
            return
        }
        let mode = WorkspaceSwitcherDisplayMode.allCases[itemIndex]
        onWorkspaceFloatingSwitcherChanged(mode == .floating)
    }

    @objc
    private func pixelSizeChanged(_ sender: NSTextField) {
        let pixelSize = CGSize(
            width: max(widthField.doubleValue.rounded(), 1),
            height: max(heightField.doubleValue.rounded(), 1)
        )
        updatePixelSize(pixelSize)
        onPixelSizeChanged(pixelSize)
    }

    func updatePixelSize(_ pixelSize: CGSize) {
        widthField.integerValue = Int(pixelSize.width.rounded())
        heightField.integerValue = Int(pixelSize.height.rounded())
    }

    private func updateCustomOriginFieldsEnabled(for position: TouchBarDisplayPosition) {
        let enabled = position.usesCustomTopLeft
        originXField.isEnabled = enabled
        originYField.isEnabled = enabled
        originXField.alphaValue = enabled ? 1 : 0.5
        originYField.alphaValue = enabled ? 1 : 0.5
    }

    private func rebuildCustomAppsRows() {
        for view in customAppsStack.arrangedSubviews {
            customAppsStack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        let apps = WorkspacePreferences.customApps
        for (index, app) in apps.enumerated() {
            customAppsStack.addArrangedSubview(
                makeCustomAppRow(app: app, index: index)
            )
        }

        if apps.count < CustomWorkspaceAppList.maxCount {
            let addButton = NSButton(
                title: "添加应用…",
                target: self,
                action: #selector(addCustomApp)
            )
            addButton.bezelStyle = .rounded
            customAppsStack.addArrangedSubview(addButton)
        } else {
            let fullHint = NSTextField(
                labelWithString:
                    "已满 \(CustomWorkspaceAppList.maxCount) 个，可替换或移除后再添加。"
            )
            fullHint.textColor = .secondaryLabelColor
            fullHint.font = .systemFont(ofSize: 11)
            customAppsStack.addArrangedSubview(fullHint)
        }

        if apps.isEmpty {
            let emptyHint = NSTextField(labelWithString: "尚未固定应用")
            emptyHint.textColor = .secondaryLabelColor
            emptyHint.font = .systemFont(ofSize: 12)
            customAppsStack.insertArrangedSubview(emptyHint, at: 0)
        }
    }

    private func makeCustomAppRow(app: CustomWorkspaceApp, index: Int) -> NSView {
        let iconView = NSImageView()
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.image = WorkspaceTouchBarStyle.customAppIcon(for: app)
            ?? NSImage(
                systemSymbolName: "app.fill",
                accessibilityDescription: nil
            )
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let nameLabel = NSTextField(labelWithString: app.displayName)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setContentCompressionResistancePriority(
            .defaultLow,
            for: .horizontal
        )

        let replaceButton = NSButton(
            title: "替换…",
            target: self,
            action: #selector(replaceCustomApp(_:))
        )
        replaceButton.bezelStyle = .rounded
        replaceButton.tag = index

        let removeButton = NSButton(
            title: "移除",
            target: self,
            action: #selector(removeCustomApp(_:))
        )
        removeButton.bezelStyle = .rounded
        removeButton.tag = index

        let row = NSStackView(views: [
            iconView,
            nameLabel,
            replaceButton,
            removeButton,
        ])
        row.orientation = .horizontal
        row.spacing = 8
        row.alignment = .centerY
        row.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),
            nameLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
        ])
        return row
    }

    @objc
    private func addCustomApp() {
        onPickApplication { [weak self] url in
            guard let self else { return }
            guard
                let url,
                let app = CustomWorkspaceApp.make(fromApplicationURL: url)
            else {
                return
            }
            guard
                let updated = CustomWorkspaceAppList.adding(
                    app,
                    to: WorkspacePreferences.customApps
                )
            else {
                self.presentCustomAppsFullAlert()
                return
            }
            WorkspacePreferences.customApps = updated
            self.rebuildCustomAppsRows()
            self.onCustomAppsChanged()
        }
    }

    @objc
    private func replaceCustomApp(_ sender: NSButton) {
        let index = sender.tag
        onPickApplication { [weak self] url in
            guard let self else { return }
            guard
                let url,
                let app = CustomWorkspaceApp.make(fromApplicationURL: url)
            else {
                return
            }
            guard
                let updated = CustomWorkspaceAppList.replacing(
                    at: index,
                    with: app,
                    in: WorkspacePreferences.customApps
                )
            else {
                return
            }
            WorkspacePreferences.customApps = updated
            self.rebuildCustomAppsRows()
            self.onCustomAppsChanged()
        }
    }

    @objc
    private func removeCustomApp(_ sender: NSButton) {
        let index = sender.tag
        guard
            let updated = CustomWorkspaceAppList.removing(
                at: index,
                from: WorkspacePreferences.customApps
            )
        else {
            return
        }
        WorkspacePreferences.customApps = updated
        rebuildCustomAppsRows()
        onCustomAppsChanged()
    }

    private func presentCustomAppsFullAlert() {
        guard let window else { return }
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "自定义 App 已满"
        alert.informativeText =
            "最多固定 \(CustomWorkspaceAppList.maxCount) 个。请先移除或替换其中一个。"
        alert.addButton(withTitle: "好")
        alert.beginSheetModal(for: window, completionHandler: nil)
    }
}
