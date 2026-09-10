import Foundation

struct OpenUsageLimitsEnvelope: Equatable, Sendable {
    var providers: [String: OpenUsageProviderSnapshot]
}

struct OpenUsageProviderSnapshot: Equatable, Sendable {
    var displayName: String?
    var fetchedAt: Date?
    var resources: [String: OpenUsageResourceSnapshot]
}

struct OpenUsageResourceSnapshot: Equatable, Sendable {
    var kind: String?
    var unit: String?
    var remaining: Double?
    var limit: Double?
    var used: Double?
    var resetsAt: Date?
    var windowSeconds: Double?
    var available: Double? = nil
}

enum OpenUsageLimitsMapper {
    static let fiveHourCycle: TimeInterval = 5 * 3_600
    static let weeklyCycle: TimeInterval = 7 * 86_400

    static func pools(
        from envelope: OpenUsageLimitsEnvelope,
        now: Date = Date()
    ) -> [QuotaPool] {
        var pools: [QuotaPool] = []
        for key in envelope.providers.keys.sorted() {
            guard let snapshot = envelope.providers[key] else { continue }
            if isFamily(key, "cursor") {
                if let bots = extractPool(
                    provider: .grokBots,
                    title: QuotaProviderID.grokBots.displayName,
                    snapshot: snapshot,
                    includingKeys: ["grokBot"],
                    excludingKeys: [],
                    now: now
                ) {
                    pools.append(bots)
                }
                if let cursor = extractPool(
                    provider: .cursor,
                    title: snapshotTitle(snapshot, fallback: .cursor),
                    snapshot: snapshot,
                    includingKeys: nil,
                    excludingKeys: ["grokBot"],
                    now: now
                ) {
                    pools.append(cursor)
                }
                continue
            }
            let provider = canonicalProviderID(key)
            if let pool = extractPool(
                provider: provider,
                title: snapshotTitle(snapshot, fallback: provider),
                snapshot: snapshot,
                includingKeys: nil,
                excludingKeys: [],
                now: now
            ) {
                pools.append(pool)
            }
        }
        return sortPools(pools)
    }

    static func decodeEnvelope(from data: Data) throws -> OpenUsageLimitsEnvelope {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any] else {
            throw OpenUsageQuotaError.invalidEnvelope
        }
        let rawProviders = root["providers"] as? [String: Any] ?? [:]
        var providers: [String: OpenUsageProviderSnapshot] = [:]
        for (id, value) in rawProviders {
            guard let body = value as? [String: Any] else { continue }
            providers[id] = decodeProvider(body)
        }
        return OpenUsageLimitsEnvelope(providers: providers)
    }

    private static func decodeProvider(
        _ body: [String: Any]
    ) -> OpenUsageProviderSnapshot {
        let fetchedAt = OpenUsageDateParser.date(
            from: body["fetchedAt"] as? String
        )
        let rawResources = body["resources"] as? [String: Any] ?? [:]
        var resources: [String: OpenUsageResourceSnapshot] = [:]
        for (key, value) in rawResources {
            guard let resource = value as? [String: Any] else { continue }
            resources[key] = OpenUsageResourceSnapshot(
                kind: resource["kind"] as? String,
                unit: resource["unit"] as? String,
                remaining: double(resource["remaining"]),
                limit: double(resource["limit"]),
                used: double(resource["used"]),
                resetsAt: OpenUsageDateParser.date(
                    from: resource["resetsAt"] as? String
                ),
                windowSeconds: double(resource["windowSeconds"]),
                available: double(resource["available"])
            )
        }
        return OpenUsageProviderSnapshot(
            displayName: body["displayName"] as? String,
            fetchedAt: fetchedAt,
            resources: resources
        )
    }

    private static func extractPool(
        provider: QuotaProviderID,
        title: String,
        snapshot: OpenUsageProviderSnapshot,
        includingKeys: Set<String>?,
        excludingKeys: Set<String>,
        now: Date
    ) -> QuotaPool? {
        let hasConsumption = snapshot.resources.values.contains { $0.kind == "consumption" }
        if provider == .openrouter || !hasConsumption {
            let balanceResource = snapshot.resources.keys.sorted().compactMap { snapshot.resources[$0] }
                .first { $0.kind == "balance" && ($0.available ?? $0.remaining)?.isFinite == true }
            var balance: QuotaBalance?
            if let resource = balanceResource, let amount = resource.available ?? resource.remaining {
                balance = QuotaBalance(amount: amount, unit: resource.unit ?? "", caption: "余额")
            } else if provider == .openrouter, let credits = snapshot.resources["credits"] {
                let amount = credits.remaining ?? credits.limit.flatMap { limit in credits.used.map { limit - $0 } }
                if let amount, amount.isFinite {
                    balance = QuotaBalance(amount: amount, unit: credits.unit ?? "", caption: "额度")
                }
            }
            if let balance {
                return QuotaPool(provider: provider, windows: [], fetchedAt: snapshot.fetchedAt ?? now,
                                 title: title, balance: balance)
            }
            if provider == .openrouter { return nil }
        }
        var byKind: [QuotaWindowKind: (window: QuotaWindow, key: String, unit: String?)] = [:]
        for key in snapshot.resources.keys.sorted() {
            if let includingKeys, !includingKeys.contains(key) { continue }
            if excludingKeys.contains(key) { continue }
            if ignoredResourceKeys.contains(key) { continue }
            guard let resource = snapshot.resources[key] else { continue }
            let kind = classifiedKind(windowSeconds: resource.windowSeconds)
            let defaultCycle = kind == .fiveHour ? fiveHourCycle : weeklyCycle
            guard let window = consumptionWindow(
                resource,
                kind: kind,
                defaultCycle: defaultCycle,
                fetchedAt: snapshot.fetchedAt,
                now: now
            ) else { continue }
            let candidate = (window: window, key: key, unit: resource.unit)
            if let current = byKind[kind] {
                byKind[kind] = preferredResource(
                    current,
                    candidate,
                    now: now
                )
            } else {
                byKind[kind] = candidate
            }
        }
        let windows = [QuotaWindowKind.fiveHour, .weekly].compactMap { byKind[$0]?.window }
        guard !windows.isEmpty else { return nil }
        return QuotaPool(
            provider: provider,
            windows: windows,
            fetchedAt: snapshot.fetchedAt ?? now,
            title: title
        )
    }

    private static func classifiedKind(windowSeconds: Double?) -> QuotaWindowKind {
        if let windowSeconds, windowSeconds > 0, windowSeconds <= 8 * 3_600 {
            return .fiveHour
        }
        return .weekly
    }

    private static func canonicalProviderID(_ providerID: String) -> QuotaProviderID {
        if isFamily(providerID, "grok") { return .grokBuild }
        if isFamily(providerID, "codex") { return .codex }
        if isFamily(providerID, "claude") { return .claude }
        if isFamily(providerID, "cursor") { return .cursor }
        if isFamily(providerID, "antigravity") { return .antigravity }
        if isFamily(providerID, "copilot") { return .copilot }
        if isFamily(providerID, "opencode") { return .opencode }
        if isFamily(providerID, "ollama") { return .ollama }
        if isFamily(providerID, "devin") { return .devin }
        if isFamily(providerID, "openrouter") { return .openrouter }
        return QuotaProviderID(providerID.lowercased())
    }

    private static func snapshotTitle(
        _ snapshot: OpenUsageProviderSnapshot,
        fallback: QuotaProviderID
    ) -> String {
        if fallback == .grokBuild {
            return fallback.displayName
        }
        let name = snapshot.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            return name
        }
        return fallback.displayName
    }

    private static func sortPools(_ pools: [QuotaPool]) -> [QuotaPool] {
        pools.sorted { left, right in
            let leftRank = QuotaProviderID.preferredDisplayOrder.firstIndex(
                of: left.provider
            ) ?? Int.max
            let rightRank = QuotaProviderID.preferredDisplayOrder.firstIndex(
                of: right.provider
            ) ?? Int.max
            if leftRank != rightRank {
                return leftRank < rightRank
            }
            return left.title.localizedCaseInsensitiveCompare(right.title)
                == .orderedAscending
        }
    }

    private static let ignoredResourceKeys: Set<String> = [
        "keyLimit",
        "rateLimitResets",
        "creditValue",
    ]

    private static func preferredResource(
        _ current: (window: QuotaWindow, key: String, unit: String?),
        _ candidate: (window: QuotaWindow, key: String, unit: String?),
        now: Date
    ) -> (window: QuotaWindow, key: String, unit: String?) {
        let currentRank = resourceRank(key: current.key, unit: current.unit)
        let candidateRank = resourceRank(key: candidate.key, unit: candidate.unit)
        if candidateRank != currentRank {
            return candidateRank < currentRank ? candidate : current
        }
        let currentRisk = QuotaRecommendationEngine.wasteRisk(
            window: current.window,
            now: now
        )
        let candidateRisk = QuotaRecommendationEngine.wasteRisk(
            window: candidate.window,
            now: now
        )
        return candidateRisk > currentRisk ? candidate : current
    }

    private static func resourceRank(key: String, unit: String?) -> Int {
        let keyRank: Int
        switch key {
        case "session", "weekly", "geminiSession", "geminiWeekly":
            keyRank = 0
        case "grokBot", "autoUsage", "credits":
            keyRank = 1
        default:
            keyRank = 2
        }
        let unitRank = unit == "percent" ? 0 : 1
        return keyRank * 10 + unitRank
    }

    private static func consumptionWindow(
        _ resource: OpenUsageResourceSnapshot?,
        kind: QuotaWindowKind,
        defaultCycle: TimeInterval,
        fetchedAt: Date?,
        now: Date
    ) -> QuotaWindow? {
        guard let resource, resource.kind == "consumption" else { return nil }
        let limit = resource.limit ?? 0
        guard limit > 0 else { return nil }
        let remaining: Double
        if let value = resource.remaining {
            remaining = value
        } else if let used = resource.used {
            remaining = max(limit - used, 0)
        } else {
            return nil
        }
        let cycle = resource.windowSeconds ?? defaultCycle
        let resetAt = resource.resetsAt
            ?? (fetchedAt ?? now).addingTimeInterval(max(cycle, 0))
        return QuotaWindow(
            kind: kind,
            remaining: remaining,
            limit: limit,
            resetAt: resetAt,
            cycle: cycle > 0 ? cycle : defaultCycle
        )
    }

    private static func isFamily(_ providerID: String, _ family: String) -> Bool {
        let id = providerID.lowercased()
        return id == family
            || id.hasPrefix(family + ".")
            || id.hasPrefix(family + "-")
    }

    private static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as Double:
            return number
        case let number as Int:
            return Double(number)
        case let number as NSNumber:
            return number.doubleValue
        default:
            return nil
        }
    }
}

enum OpenUsageDateParser {
    static func date(from string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) {
            return date
        }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: string)
    }
}

enum OpenUsageQuotaError: Error {
    case invalidEnvelope
    case unavailable
}

enum OpenUsageQuotaReader {
    static let loopbackURL = URL(string: "http://127.0.0.1:6736/v1/limits")!
    static let helperPath =
        "/Applications/OpenUsage.app/Contents/Helpers/openusage"

    static func fetch() async throws -> [QuotaPool] {
        let data: Data
        if let httpData = try? await fetchHTTP() {
            data = httpData
        } else {
            data = try await fetchCLI()
        }
        let envelope = try OpenUsageLimitsMapper.decodeEnvelope(from: data)
        return OpenUsageLimitsMapper.pools(from: envelope)
    }

    private static func fetchHTTP() async throws -> Data {
        var request = URLRequest(url: loopbackURL)
        request.timeoutInterval = 1.5
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status), !data.isEmpty else {
            throw OpenUsageQuotaError.unavailable
        }
        return data
    }

    private static func fetchCLI() async throws -> Data {
        let helper = URL(fileURLWithPath: helperPath)
        guard FileManager.default.isExecutableFile(atPath: helper.path) else {
            throw OpenUsageQuotaError.unavailable
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = helper
                process.arguments = []
                let stdout = Pipe()
                process.standardOutput = stdout
                process.standardError = FileHandle.nullDevice
                do {
                    try process.run()
                } catch {
                    continuation.resume(throwing: error)
                    return
                }
                let timeout = DispatchTime.now() + .seconds(20)
                let deadline = DispatchSource.makeTimerSource(
                    queue: DispatchQueue.global(qos: .userInitiated)
                )
                deadline.schedule(deadline: timeout)
                deadline.setEventHandler {
                    if process.isRunning {
                        process.terminate()
                    }
                }
                deadline.resume()
                process.waitUntilExit()
                deadline.cancel()
                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                if process.terminationStatus == 0, !data.isEmpty {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: OpenUsageQuotaError.unavailable)
                }
            }
        }
    }
}
