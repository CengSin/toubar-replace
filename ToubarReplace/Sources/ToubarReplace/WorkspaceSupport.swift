import AppKit
import Foundation

enum WorkspaceSwitcherDisplayMode: String, CaseIterable {
    case touchBar
    case floating

    var title: String {
        switch self {
        case .touchBar:
            return "物理 Touch Bar"
        case .floating:
            return "独立浮窗"
        }
    }
}

enum QuotaMetricDisplayStyle: String, CaseIterable {
    case bars
    case percent

    var title: String {
        switch self {
        case .bars: return "柱状图"
        case .percent: return "百分比"
        }
    }
}

enum WorkspaceStartupScene: String, CaseIterable {
    case workspace
    case mirror

    var title: String {
        switch self {
        case .workspace:
            return "Workspace"
        case .mirror:
            return "镜像"
        }
    }
}

enum WorkspaceStartupScenePolicy {
    static func scene(storedRawValue: String?) -> WorkspaceStartupScene {
        guard
            let storedRawValue,
            let scene = WorkspaceStartupScene(rawValue: storedRawValue)
        else {
            return .workspace
        }
        return scene
    }
}

enum WorkspacePreferences {
    private static let floatingSwitcherKey =
        "ToubarReplace.workspace.floatingSwitcher"
    private static let switcherDisplayModeKey =
        "ToubarReplace.workspace.switcherDisplayMode"
    private static let startupSceneKey =
        "ToubarReplace.workspace.startupScene"

    /// Preferred location of the Workspace switcher button.
    /// `.touchBar` shows a real touchable button on the hardware Touch Bar.
    /// `.floating` shows the independent floating window only.
    static var switcherDisplayMode: WorkspaceSwitcherDisplayMode {
        get {
            if let rawValue = UserDefaults.standard.string(
                forKey: switcherDisplayModeKey
            ),
                let mode = WorkspaceSwitcherDisplayMode(rawValue: rawValue)
            {
                return mode
            }
            // Migrate from the older floatingSwitcher bool.
            if UserDefaults.standard.object(forKey: floatingSwitcherKey) != nil {
                return UserDefaults.standard.bool(forKey: floatingSwitcherKey)
                    ? .floating
                    : .touchBar
            }
            return .touchBar
        }
        set {
            UserDefaults.standard.set(
                newValue.rawValue,
                forKey: switcherDisplayModeKey
            )
        }
    }

    /// Convenience: true means floating window mode.
    static var floatingSwitcher: Bool {
        get { switcherDisplayMode == .floating }
        set { switcherDisplayMode = newValue ? .floating : .touchBar }
    }

    static var startupScene: WorkspaceStartupScene {
        get {
            WorkspaceStartupScenePolicy.scene(
                storedRawValue: UserDefaults.standard.string(
                    forKey: startupSceneKey
                )
            )
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: startupSceneKey)
        }
    }

    private static let customAppsKey = "ToubarReplace.workspace.customApps"
    private static let hiddenQuotaProvidersKey =
        "ToubarReplace.workspace.hiddenQuotaProviders"
    private static let seenQuotaProvidersKey =
        "ToubarReplace.workspace.seenQuotaProviders"
    private static let quotaMetricDisplayStyleKey =
        "ToubarReplace.workspace.quotaMetricDisplayStyle"

    static let defaultQuotaShare = 0.70
    static func clampedQuotaShare(_ value: Double) -> Double {
        value.isFinite ? min(max(value, 0.30), 0.75) : defaultQuotaShare
    }

    static var quotaShare: Double {
        get {
            let value = UserDefaults.standard.object(forKey: "ToubarReplace.workspace.quotaShare") as? Double
            return clampedQuotaShare(value ?? defaultQuotaShare)
        }
        set {
            UserDefaults.standard.set(clampedQuotaShare(newValue), forKey: "ToubarReplace.workspace.quotaShare")
        }
    }

    /// How each quota metric is drawn on the plate: vertical bars or percent text.
    static var quotaMetricDisplayStyle: QuotaMetricDisplayStyle {
        get {
            if let raw = UserDefaults.standard.string(
                forKey: quotaMetricDisplayStyleKey
            ),
                let style = QuotaMetricDisplayStyle(rawValue: raw)
            {
                return style
            }
            return .bars
        }
        set {
            UserDefaults.standard.set(
                newValue.rawValue,
                forKey: quotaMetricDisplayStyleKey
            )
        }
    }

    /// Provider IDs the user hid in Settings. Missing key / empty = show all.
    static var hiddenQuotaProviderIDs: Set<String> {
        get {
            Set(
                UserDefaults.standard.stringArray(
                    forKey: hiddenQuotaProvidersKey
                ) ?? []
            )
        }
        set {
            UserDefaults.standard.set(
                Array(newValue).sorted(),
                forKey: hiddenQuotaProvidersKey
            )
        }
    }

    static func isQuotaProviderVisible(_ id: QuotaProviderID) -> Bool {
        !hiddenQuotaProviderIDs.contains(id.rawValue)
    }

    static func setQuotaProvider(_ id: QuotaProviderID, visible: Bool) {
        var hidden = hiddenQuotaProviderIDs
        if visible {
            hidden.remove(id.rawValue)
        } else {
            hidden.insert(id.rawValue)
        }
        hiddenQuotaProviderIDs = hidden
    }

    /// Last OpenUsage pools, so Settings can list subscriptions before/without a live fetch.
    static var seenQuotaProviders: [QuotaProviderChoice] {
        get {
            guard
                let data = UserDefaults.standard.data(forKey: seenQuotaProvidersKey),
                let decoded = try? JSONDecoder().decode(
                    [SeenQuotaProviderRecord].self,
                    from: data
                )
            else {
                return []
            }
            return decoded.map {
                QuotaProviderChoice(
                    id: QuotaProviderID($0.id),
                    title: $0.title
                )
            }
        }
        set {
            let records = newValue.map {
                SeenQuotaProviderRecord(id: $0.id.rawValue, title: $0.title)
            }
            if let data = try? JSONEncoder().encode(records) {
                UserDefaults.standard.set(data, forKey: seenQuotaProvidersKey)
            } else {
                UserDefaults.standard.removeObject(forKey: seenQuotaProvidersKey)
            }
        }
    }

    static func rememberSeenQuotaProviders(_ pools: [QuotaPool]) {
        seenQuotaProviders = pools.map {
            QuotaProviderChoice(id: $0.provider, title: $0.title)
        }
    }

    /// Pinned favorites in slot order (index 0…maxCount-1). Cap via
    /// ``CustomWorkspaceAppList.normalized``.
    static var customApps: [CustomWorkspaceApp] {
        get {
            guard
                let data = UserDefaults.standard.data(forKey: customAppsKey),
                let decoded = try? JSONDecoder().decode(
                    [CustomWorkspaceApp].self,
                    from: data
                )
            else {
                return []
            }
            return CustomWorkspaceAppList.normalized(decoded)
        }
        set {
            let normalized = CustomWorkspaceAppList.normalized(newValue)
            if let data = try? JSONEncoder().encode(normalized) {
                UserDefaults.standard.set(data, forKey: customAppsKey)
            } else {
                UserDefaults.standard.removeObject(forKey: customAppsKey)
            }
        }
    }
}

struct QuotaProviderChoice: Equatable {
    var id: QuotaProviderID
    var title: String
}

struct SeenQuotaProviderRecord: Codable, Equatable {
    var id: String
    var title: String
}

/// User-pinned app for the Workspace apps zone (open only).
struct CustomWorkspaceApp: Codable, Equatable {
    /// Bundle identifier when known; used for dedupe and relaunch fallback.
    var bundleIdentifier: String?
    /// Absolute path to the `.app` bundle when selected.
    var applicationPath: String
    /// Display name captured at add time.
    var displayName: String

    var applicationURL: URL {
        URL(fileURLWithPath: applicationPath, isDirectory: true)
    }

    static func make(fromApplicationURL url: URL) -> CustomWorkspaceApp? {
        let standardized = url.standardizedFileURL
        guard standardized.pathExtension == "app" else { return nil }
        let bundle = Bundle(url: standardized)
        let bundleIdentifier = bundle?.bundleIdentifier
        let displayName =
            bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? standardized.deletingPathExtension().lastPathComponent
        return CustomWorkspaceApp(
            bundleIdentifier: bundleIdentifier,
            applicationPath: standardized.path,
            displayName: displayName
        )
    }
}

enum CustomWorkspaceAppList {
    static let maxCount = 5

    /// Dedupe (last wins) and keep at most ``maxCount`` in list order.
    /// Does not silently evict by FIFO when adding — callers use ``adding`` /
    /// ``replacing`` for explicit pin management.
    static func normalized(_ apps: [CustomWorkspaceApp]) -> [CustomWorkspaceApp] {
        var result: [CustomWorkspaceApp] = []
        for app in apps {
            result.removeAll { Self.isSameApp($0, app) }
            result.append(app)
        }
        if result.count > maxCount {
            result = Array(result.prefix(maxCount))
        }
        return result
    }

    /// Append when under capacity. If already pinned, refreshes that slot.
    /// Returns `nil` when full and `app` is not already in the list.
    static func adding(
        _ app: CustomWorkspaceApp,
        to apps: [CustomWorkspaceApp]
    ) -> [CustomWorkspaceApp]? {
        var result = normalized(apps)
        if let existingIndex = result.firstIndex(where: { isSameApp($0, app) }) {
            result[existingIndex] = app
            return result
        }
        guard result.count < maxCount else { return nil }
        result.append(app)
        return result
    }

    /// Replace the pin at `index`. Other slots that match the same app are
    /// removed. Returns `nil` if `index` is out of range.
    static func replacing(
        at index: Int,
        with app: CustomWorkspaceApp,
        in apps: [CustomWorkspaceApp]
    ) -> [CustomWorkspaceApp]? {
        var result = normalized(apps)
        guard result.indices.contains(index) else { return nil }
        result[index] = app
        var kept: [CustomWorkspaceApp] = []
        for (i, item) in result.enumerated() {
            if i != index, isSameApp(item, app) { continue }
            kept.append(item)
        }
        return normalized(kept)
    }

    static func removing(
        at index: Int,
        from apps: [CustomWorkspaceApp]
    ) -> [CustomWorkspaceApp]? {
        var result = normalized(apps)
        guard result.indices.contains(index) else { return nil }
        result.remove(at: index)
        return result
    }

    static func isSameApp(_ lhs: CustomWorkspaceApp, _ rhs: CustomWorkspaceApp)
        -> Bool
    {
        if let leftID = lhs.bundleIdentifier,
            let rightID = rhs.bundleIdentifier,
            !leftID.isEmpty,
            leftID == rightID
        {
            return true
        }
        return lhs.applicationPath == rhs.applicationPath
    }
}

enum CustomWorkspaceAppLauncher {
    @MainActor
    static func open(
        _ app: CustomWorkspaceApp,
        workspace: NSWorkspace = .shared,
        fileManager: FileManager = .default
    ) async throws {
        try await open(
            app,
            fileManager: fileManager,
            resolveBundleIdentifier: { bundleIdentifier in
                workspace.urlForApplication(
                    withBundleIdentifier: bundleIdentifier
                )
            },
            openApplication: { url in
                try await openApplication(at: url, workspace: workspace)
            }
        )
    }

    @MainActor
    static func open(
        _ app: CustomWorkspaceApp,
        fileManager: FileManager,
        resolveBundleIdentifier: (String) -> URL?,
        openApplication: (URL) async throws -> Void
    ) async throws {
        if fileManager.fileExists(atPath: app.applicationPath) {
            try await openApplication(app.applicationURL)
            return
        }
        if let bundleIdentifier = app.bundleIdentifier,
            let url = resolveBundleIdentifier(bundleIdentifier)
        {
            try await openApplication(url)
            return
        }
        throw CustomWorkspaceAppLaunchError.applicationMissing(app.displayName)
    }

    @MainActor
    static func openApplication(
        at url: URL,
        workspace: NSWorkspace = .shared
    ) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        try await withCheckedThrowingContinuation {
            (continuation: CheckedContinuation<Void, Error>) in
            workspace.openApplication(
                at: url,
                configuration: configuration
            ) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

enum CustomWorkspaceAppLaunchError: LocalizedError {
    case applicationMissing(String)

    var errorDescription: String? {
        switch self {
        case let .applicationMissing(name):
            return "找不到应用「\(name)」"
        }
    }
}
