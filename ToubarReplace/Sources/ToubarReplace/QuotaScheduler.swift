import Foundation



struct QuotaProviderID: Hashable, Codable, Sendable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    static let grokBuild = QuotaProviderID("grokBuild")
    static let grokBots = QuotaProviderID("grokBots")
    static let codex = QuotaProviderID("codex")
    static let cursor = QuotaProviderID("cursor")
    static let claude = QuotaProviderID("claude")
    static let antigravity = QuotaProviderID("antigravity")
    static let copilot = QuotaProviderID("copilot")
    static let opencode = QuotaProviderID("opencode")
    static let ollama = QuotaProviderID("ollama")
    static let devin = QuotaProviderID("devin")
    static let openrouter = QuotaProviderID("openrouter")



    static let preferredDisplayOrder: [QuotaProviderID] = [
        .grokBuild, .grokBots, .codex, .cursor, .claude, .antigravity,
        .copilot, .opencode, .ollama, .devin, .openrouter,
    ]

    var displayName: String {
        switch self {
        case .grokBuild:
            return "Grok Build"
        case .grokBots:
            return "Grok Bots"
        case .codex:
            return "Codex"
        case .cursor:
            return "Cursor"
        case .claude:
            return "Claude"
        case .antigravity:
            return "Antigravity"
        case .copilot:
            return "Copilot"
        case .opencode:
            return "OpenCode"
        case .ollama:
            return "Ollama"
        case .devin:
            return "Devin"
        case .openrouter:
            return "OpenRouter"
        default:
            return Self.titleCased(rawValue)
        }
    }


    var iconResourceName: String? {
        switch self {
        case .codex:
            return "codex"
        case .grokBuild:
            return "grokBuild"
        case .grokBots:
            return "grokBots"
        case .cursor:
            return "cursor"
        case .claude:
            return "claudeCode"
        case .antigravity:
            return "antigravity"
        case .openrouter:
            return "openrouter"
        case .copilot:
            return "copilot"
        case .opencode:
            return "opencode"
        case .ollama:
            return "ollama"
        case .devin:
            return "devin"
        default:
            return nil
        }
    }

    var placeholderSymbolName: String { "chart.bar.fill" }

    var bundleIdentifiers: [String] {
        switch self {
        case .codex:
            return ["com.openai.codex"]
        case .grokBuild, .grokBots:
            return ["ai.xai.grok", "com.xai.grok"]
        case .cursor:
            return ["com.todesktop.230313mzl4w4u92"]
        case .claude:
            return ["com.anthropic.claudefordesktop"]
        case .antigravity:
            return ["com.google.antigravity"]
        default:
            return []
        }
    }

    var applicationNames: [String] {
        switch self {
        case .codex:
            return ["Codex"]
        case .grokBuild, .grokBots:
            return ["Grok"]
        case .cursor:
            return ["Cursor"]
        case .claude:
            return ["Claude"]
        case .antigravity:
            return ["Antigravity"]
        case .copilot:
            return ["GitHub Copilot"]
        case .opencode:
            return ["OpenCode"]
        case .ollama:
            return ["Ollama"]
        case .devin:
            return ["Devin"]
        default:
            return [displayName]
        }
    }

    var fallbackURL: URL? {
        switch self {
        case .grokBots, .grokBuild:
            return URL(string: "https://grok.com")
        case .openrouter:
            return URL(string: "https://openrouter.ai")
        case .claude:
            return URL(string: "https://claude.ai")
        default:
            return nil
        }
    }

    private static func titleCased(_ raw: String) -> String {
        raw.split { $0 == "." || $0 == "-" || $0 == "_" }
            .map { part in
                guard let first = part.first else { return "" }
                return String(first).uppercased() + part.dropFirst()
            }
            .joined(separator: " ")
    }
}

enum QuotaWindowKind: String, Codable, Sendable {
    case fiveHour
    case weekly
}

struct QuotaWindow: Equatable, Sendable {
    var kind: QuotaWindowKind

    var remaining: Double
    var limit: Double
    var resetAt: Date


    var cycle: TimeInterval

    var remainingRatio: Double {
        guard limit > 0 else { return 0 }
        return min(max(remaining / limit, 0), 1)
    }

    func hoursUntilReset(now: Date) -> Double {
        max(resetAt.timeIntervalSince(now) / 3_600, 0)
    }

    func cycleRemainingRatio(now: Date) -> Double {
        guard cycle > 0 else { return 0 }
        return min(max(resetAt.timeIntervalSince(now) / cycle, 0), 1)
    }
}

struct QuotaBalance: Equatable, Sendable {
    var amount: Double
    var unit: String
    var caption: String

    var valueText: String {
        let number = String(format: "%.2f", amount)
        return unit.lowercased() == "usd" ? "$" + number : number + " " + unit
    }
}

struct QuotaPool: Equatable, Sendable {
    var provider: QuotaProviderID
    var windows: [QuotaWindow]
    var fetchedAt: Date
    var title: String
    var balance: QuotaBalance?

    init(
        provider: QuotaProviderID,
        windows: [QuotaWindow],
        fetchedAt: Date,
        title: String? = nil,
        balance: QuotaBalance? = nil
    ) {
        self.provider = provider
        self.windows = windows
        self.fetchedAt = fetchedAt
        self.title = title ?? provider.displayName
        self.balance = balance
    }
}

struct QuotaDecision: Equatable, Sendable {
    var provider: QuotaProviderID
    var highlightedKind: QuotaWindowKind
    var pressure: Double
    var windows: [QuotaWindow]
}

enum QuotaRefreshSchedule {

    static let interval: TimeInterval = 30 * 60
}






enum QuotaRecommendationEngine {
    static let minimumRemainingRatio: Double = 0.001
    static let minimumCycleRemainingRatio: Double = 0.01

    static func pressure(window: QuotaWindow, now: Date) -> Double {
        let remaining = window.remainingRatio
        guard remaining >= minimumRemainingRatio else { return 0 }
        let cycleLeft = max(
            window.cycleRemainingRatio(now: now),
            minimumCycleRemainingRatio
        )
        return remaining / cycleLeft
    }

    static func recommend(
        pools: [QuotaPool],
        now: Date = Date()
    ) -> QuotaDecision? {
        var best: QuotaDecision?
        for pool in pools {
            guard let scored = bestWindow(in: pool, now: now) else { continue }
            if let current = best {
                if scored.pressure > current.pressure {
                    best = scored
                }
            } else {
                best = scored
            }
        }
        return best
    }

    private static func bestWindow(
        in pool: QuotaPool,
        now: Date
    ) -> QuotaDecision? {
        var highlighted: QuotaWindow?
        var highlightedPressure: Double = 0
        for window in pool.windows {
            let score = pressure(window: window, now: now)
            if score > highlightedPressure {
                highlighted = window
                highlightedPressure = score
            }
        }
        guard let highlighted, highlightedPressure > 0 else { return nil }
        return QuotaDecision(
            provider: pool.provider,
            highlightedKind: highlighted.kind,
            pressure: highlightedPressure,
            windows: pool.windows
        )
    }
}

enum QuotaDisplayFormatting {
    static func percent(_ ratio: Double) -> String {
        "\(Int((ratio * 100).rounded()))%"
    }

    static func countdown(_ interval: TimeInterval) -> String {
        let seconds = max(interval, 0)
        let days = Int(seconds / 86_400)
        let hours = Int(seconds.truncatingRemainder(dividingBy: 86_400) / 3_600)
        let minutes = Int(seconds.truncatingRemainder(dividingBy: 3_600) / 60)
        if days > 0 {
            return "\(days)d\(hours)h"
        }
        if hours > 0 {
            return "\(hours)h\(String(format: "%02d", minutes))m"
        }
        return "\(max(minutes, 0))m"
    }
}

struct QuotaBarMetric: Equatable {
    var ratio: Double?
    var caption: String
    var valueText: String
    var isHighlighted: Bool

    var isAvailable: Bool { ratio != nil }
}

struct QuotaProviderGroupState: Equatable {
    var provider: QuotaProviderID
    var title: String
    var fiveHour: QuotaBarMetric
    var weekly: QuotaBarMetric
    var reset: QuotaBarMetric
    var tooltip: String
    var isRecommended: Bool
    var balance: QuotaBalance? = nil
}

struct QuotaBoardState: Equatable {
    var groups: [QuotaProviderGroupState]
    var recommendedProvider: QuotaProviderID?

    var isEmpty: Bool { groups.isEmpty }

    static let empty = QuotaBoardState(groups: [], recommendedProvider: nil)

    static func from(
        pools: [QuotaPool],
        now: Date,
        hiddenProviderIDs: Set<String> = []
    ) -> QuotaBoardState {
        let visible = pools.filter {
            !hiddenProviderIDs.contains($0.provider.rawValue)
        }
        let decision = QuotaRecommendationEngine.recommend(
            pools: visible,
            now: now
        )
        let groups = promoteRecommended(
            visible.map { group(from: $0, decision: decision, now: now) },
            recommended: decision?.provider
        )
        return QuotaBoardState(
            groups: groups,
            recommendedProvider: decision?.provider
        )
    }


    static func promoteRecommended(
        _ groups: [QuotaProviderGroupState],
        recommended: QuotaProviderID?
    ) -> [QuotaProviderGroupState] {
        guard let recommended,
              let index = groups.firstIndex(where: { $0.provider == recommended }),
              index > 0
        else { return groups }
        var ordered = groups
        let winner = ordered.remove(at: index)
        ordered.insert(winner, at: 0)
        return ordered
    }

    private static func group(
        from pool: QuotaPool,
        decision: QuotaDecision?,
        now: Date
    ) -> QuotaProviderGroupState {
        if let balance = pool.balance {
            let empty = QuotaBarMetric(ratio: nil, caption: "", valueText: "—", isHighlighted: false)
            return QuotaProviderGroupState(
                provider: pool.provider, title: pool.title,
                fiveHour: empty, weekly: empty, reset: empty,
                tooltip: "\(pool.title) · \(balance.caption) \(balance.valueText)",
                isRecommended: false, balance: balance)
        }
        let fiveHour = pool.windows.first { $0.kind == .fiveHour }
        let weekly = pool.windows.first { $0.kind == .weekly }
        let isRecommended = decision?.provider == pool.provider
        let highlighted = isRecommended ? decision?.highlightedKind : nil

        let fiveMetric = metric(
            caption: "5h",
            ratio: fiveHour?.remainingRatio,
            valueText: fiveHour.map {
                QuotaDisplayFormatting.percent($0.remainingRatio)
            },
            highlighted: highlighted == .fiveHour
        )
        let weeklyMetric = metric(
            caption: "周",
            ratio: weekly?.remainingRatio,
            valueText: weekly.map {
                QuotaDisplayFormatting.percent($0.remainingRatio)
            },
            highlighted: highlighted == .weekly
        )
        let resetText = weekly.map {
            QuotaDisplayFormatting.countdown($0.resetAt.timeIntervalSince(now))
        }
        let resetMetric = metric(
            caption: "重置",
            ratio: weekly.map { $0.cycleRemainingRatio(now: now) },
            valueText: resetText,
            highlighted: false
        )
        var tooltipParts = [pool.title]
        if fiveMetric.isAvailable {
            tooltipParts.append("5h \(fiveMetric.valueText)")
        }
        tooltipParts.append("周 \(weeklyMetric.valueText)")
        tooltipParts.append("重置 \(resetMetric.valueText)")
        let tooltip = tooltipParts.joined(separator: " · ")
        return QuotaProviderGroupState(
            provider: pool.provider,
            title: pool.title,
            fiveHour: fiveMetric,
            weekly: weeklyMetric,
            reset: resetMetric,
            tooltip: tooltip,
            isRecommended: isRecommended
        )
    }

    private static func metric(
        caption: String,
        ratio: Double?,
        valueText: String?,
        highlighted: Bool
    ) -> QuotaBarMetric {
        QuotaBarMetric(
            ratio: ratio,
            caption: caption,
            valueText: valueText ?? "—",
            isHighlighted: highlighted
        )
    }
}

@MainActor
final class QuotaSnapshotStore {
    private(set) var pools: [QuotaPool] = []

    func replace(_ pools: [QuotaPool]) {
        self.pools = pools
    }

    func decision(now: Date = Date()) -> QuotaDecision? {
        QuotaRecommendationEngine.recommend(pools: pools, now: now)
    }

    func boardState(
        now: Date = Date(),
        hiddenProviderIDs: Set<String> = WorkspacePreferences.hiddenQuotaProviderIDs
    ) -> QuotaBoardState {
        QuotaBoardState.from(
            pools: pools,
            now: now,
            hiddenProviderIDs: hiddenProviderIDs
        )
    }

    func providerChoices() -> [QuotaProviderChoice] {
        pools.map {
            QuotaProviderChoice(id: $0.provider, title: $0.title)
        }
    }
}

enum QuotaProviderLaunch {
    static func matchingCustomApp(
        provider: QuotaProviderID,
        apps: [CustomWorkspaceApp]
    ) -> CustomWorkspaceApp? {
        let identifiers = Set(provider.bundleIdentifiers)
        if let match = apps.first(where: { app in
            if let id = app.bundleIdentifier, identifiers.contains(id) {
                return true
            }
            return false
        }) {
            return match
        }
        let names = provider.applicationNames.map { $0.lowercased() }
        return apps.first { app in
            names.contains { token in
                app.displayName.lowercased().contains(token)
            }
        }
    }
}
