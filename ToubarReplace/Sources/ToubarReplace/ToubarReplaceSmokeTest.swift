import AppKit
import CoreGraphics
import Foundation

@MainActor
private final class SmokeFrameDeliveryProbe {
    var deliveredWidths: [Int] = []
}

enum ToubarReplaceSmokeTest {
    @MainActor
    static func failures() async -> [String] {
        enum CustomAppOpenTestError: Error {
            case rejected
        }

        var failures: [String] = []

        expect(
            TouchBarWindowMetrics.defaultSize
                == CGSize(width: 1_150, height: 35),
            "default mirror size changed unexpectedly",
            failures: &failures
        )
        expect(
            TouchBarWindowMetrics.minimumSize.width
                < TouchBarWindowMetrics.defaultSize.width,
            "minimum mirror width must be below the default width",
            failures: &failures
        )
        expect(
            TouchBarWindowMetrics.pixelSize(
                forPointSize: CGSize(width: 1_150, height: 35),
                backingScaleFactor: 2
            ) == CGSize(width: 2_300, height: 70),
            "point-to-pixel conversion changed unexpectedly",
            failures: &failures
        )
        expect(
            TouchBarWindowMetrics.rootSize(
                forMirrorSize: TouchBarWindowMetrics.defaultSize
            ) == TouchBarWindowMetrics.defaultSize,
            "mirror root size equals viewport (no attached switcher rail)",
            failures: &failures
        )
        expect(
            TouchBarWindowMetrics.rootSize(
                forMirrorSize: TouchBarWindowMetrics.minimumSize
            ) == TouchBarWindowMetrics.minimumSize,
            "minimum root size equals minimum mirror size",
            failures: &failures
        )
        expect(
            WorkspaceTouchBarLayout.presentationMode == "app"
                && WorkspaceTouchBarLayout.placement == 1,
            "Workspace must use the full-width Touch Bar presentation",
            failures: &failures
        )
        expect(
            MirrorSceneTransition.fadeDuration > 0
                && MirrorSceneTransition.fadeDuration <= 0.3,
            "mirror scene cover fade should be a short crossfade",
            failures: &failures
        )
        expect(
            MirrorSceneTransition.settleDuration > .milliseconds(0)
                && MirrorSceneTransition.settleDuration <= .milliseconds(500),
            "mirror scene cover settle should hide modal-swap glitches briefly",
            failures: &failures
        )
        expect(
            WorkspacePresentationModePolicy.dismissalAction(
                currentMode: "app",
                workspaceMode: "app",
                previousMode: "quickActions",
                hadPreviousMode: true
            ) == .set("quickActions"),
            "closing Workspace must restore the mode saved at presentation",
            failures: &failures
        )
        expect(
            !WorkspacePresentationInterruptionPolicy.shouldInterrupt(
                isPresented: true,
                hasAttachedToWindow: true,
                isExplicitlyDismissing: false,
                isCurrentlyAttached: false,
                currentMode: "app",
                workspaceMode: "app"
            ),
            "transient Touch Bar detachment must not reset Workspace",
            failures: &failures
        )
        expect(
            WorkspacePresentationInterruptionPolicy.shouldInterrupt(
                isPresented: true,
                hasAttachedToWindow: true,
                isExplicitlyDismissing: false,
                isCurrentlyAttached: false,
                currentMode: "spaces",
                workspaceMode: "app"
            ),
            "an external system mode change must reset Workspace",
            failures: &failures
        )
        expect(
            WorkspacePresentationModePolicy.dismissalAction(
                currentMode: "spaces",
                workspaceMode: "app",
                previousMode: "quickActions",
                hadPreviousMode: true
            ) == .preserveCurrent,
            "closing Workspace must preserve a mode changed by the user",
            failures: &failures
        )
        expect(
            WorkspacePresentationModePolicy.dismissalAction(
                currentMode: "app",
                workspaceMode: "app",
                previousMode: nil,
                hadPreviousMode: false
            ) == .remove,
            "closing Workspace must remove an originally absent mode",
            failures: &failures
        )
        expect(
            WorkspacePresentationModePolicy.dismissalAction(
                currentMode: "app",
                workspaceMode: "app",
                previousMode: "app",
                hadPreviousMode: true
            ) == .remove,
            "closing Workspace must not restore our own app mode leftover",
            failures: &failures
        )
        expect(
            CustomWorkspaceAppList.maxCount == 5,
            "Workspace custom apps must cap at five favorites",
            failures: &failures
        )
        let pinSeed = [
            CustomWorkspaceApp(
                bundleIdentifier: "a.one",
                applicationPath: "/Applications/One.app",
                displayName: "One"
            ),
            CustomWorkspaceApp(
                bundleIdentifier: "a.two",
                applicationPath: "/Applications/Two.app",
                displayName: "Two"
            ),
            CustomWorkspaceApp(
                bundleIdentifier: "a.three",
                applicationPath: "/Applications/Three.app",
                displayName: "Three"
            ),
            CustomWorkspaceApp(
                bundleIdentifier: "a.four",
                applicationPath: "/Applications/Four.app",
                displayName: "Four"
            ),
            CustomWorkspaceApp(
                bundleIdentifier: "a.five",
                applicationPath: "/Applications/Five.app",
                displayName: "Five"
            ),
        ]
        let fullAdd = CustomWorkspaceAppList.adding(
            CustomWorkspaceApp(
                bundleIdentifier: "a.six",
                applicationPath: "/Applications/Six.app",
                displayName: "Six"
            ),
            to: pinSeed
        )
        expect(
            fullAdd == nil,
            "custom app add must refuse when already at maxCount",
            failures: &failures
        )
        let replaceMid = CustomWorkspaceAppList.replacing(
            at: 1,
            with: CustomWorkspaceApp(
                bundleIdentifier: "a.six",
                applicationPath: "/Applications/Six.app",
                displayName: "Six"
            ),
            in: pinSeed
        )
        expect(
            replaceMid?.map(\.bundleIdentifier)
                == ["a.one", "a.six", "a.three", "a.four", "a.five"],
            "custom app replace must update the chosen slot only",
            failures: &failures
        )
        let refreshExisting = CustomWorkspaceAppList.adding(
            CustomWorkspaceApp(
                bundleIdentifier: "a.two",
                applicationPath: "/Applications/Two.app",
                displayName: "Two"
            ),
            to: pinSeed
        )
        expect(
            refreshExisting?.map(\.bundleIdentifier)
                == ["a.one", "a.two", "a.three", "a.four", "a.five"],
            "re-adding an existing custom app must refresh in place",
            failures: &failures
        )
        let removed = CustomWorkspaceAppList.removing(at: 0, from: pinSeed)
        expect(
            removed?.map(\.bundleIdentifier)
                == ["a.two", "a.three", "a.four", "a.five"],
            "custom app remove must drop the chosen slot",
            failures: &failures
        )
        let appendWhenRoom = CustomWorkspaceAppList.adding(
            CustomWorkspaceApp(
                bundleIdentifier: "a.four",
                applicationPath: "/Applications/Four.app",
                displayName: "Four"
            ),
            to: Array(pinSeed.prefix(2))
        )
        expect(
            appendWhenRoom?.map(\.bundleIdentifier)
                == ["a.one", "a.two", "a.four"],
            "custom app add must append when under capacity",
            failures: &failures
        )
        let missingCustomApp = CustomWorkspaceApp(
            bundleIdentifier: "a.missing",
            applicationPath:
                "/private/tmp/ToubarReplaceMissingCustomApp-\(UUID().uuidString).app",
            displayName: "Missing"
        )
        let fallbackCustomAppURL = URL(
            fileURLWithPath: "/Applications/Fallback.app",
            isDirectory: true
        )
        do {
            try await CustomWorkspaceAppLauncher.open(
                missingCustomApp,
                fileManager: .default,
                resolveBundleIdentifier: { _ in fallbackCustomAppURL },
                openApplication: { _ in
                    throw CustomAppOpenTestError.rejected
                }
            )
            failures.append("自定义 App completion error 不得被忽略")
        } catch CustomAppOpenTestError.rejected {
            // Expected: completion errors must reach the caller.
        } catch {
            failures.append("自定义 App 返回了意外错误：\(error)")
        }
        expect(
            WorkspaceTouchBarLayout.totalUnits == 10
                && WorkspaceTouchBarLayout.quotaUnits == 4
                && WorkspaceTouchBarLayout.appsUnits == 6
                && WorkspaceTouchBarLayout.minimumContentWidth == 400
                && WorkspaceTouchBarLayout.designReferenceBarWidth == 1_010
                && WorkspaceTouchBarLayout.maximumContentWidth == 1_010
                && WorkspaceTouchBarLayout.switcherWidth == 44
                && WorkspaceTouchBarLayout.zoneContentInset == 6
                && WorkspaceTouchBarLayout.slotVerticalInset == 3
                && WorkspaceTouchBarLayout.trayTrailingSafeInset == 12
                && WorkspaceTouchBarLayout.quotaGroupMinimumWidth == 144
                && WorkspaceTouchBarLayout.quotaGroupTwoBarMinimumWidth == 104
                && WorkspaceTouchBarLayout.quotaGroupSpacing == 4
                && WorkspaceTouchBarStyle.controlHeight == 30
                && WorkspaceTouchBarStyle.cornerRadius == 7
                && WorkspaceTouchBarStyle.trayCornerRadius == 8
                && WorkspaceTouchBarStyle.agentIconSize == 22
                && WorkspaceTouchBarStyle.itemSpacing == 6
                && WorkspaceTouchBarStyle.canvasInset == 4,
            "Workspace quota 4|6 geometry must stay stable",
            failures: &failures
        )
        let settingsPreferred = WorkspaceTouchBarLayout.preferredContentSize(
            mirrorPixelSize: TouchBarPreferences.defaultMirrorPixelSize,
            backingScaleFactor: 2
        )
        expect(
            abs(
                settingsPreferred.width
                    - WorkspaceTouchBarLayout.maximumContentWidth
            ) < 0.5
                && abs(settingsPreferred.height - 35) < 0.5,
            "preferred Workspace width must cap at hardware-class maximumContentWidth",
            failures: &failures
        )
        let narrowPreferred = WorkspaceTouchBarLayout.preferredContentWidth(
            mirrorPixelSize: CGSize(width: 400, height: 60),
            backingScaleFactor: 2
        )
        expect(
            narrowPreferred == WorkspaceTouchBarLayout.minimumContentWidth,
            "preferred width must not fall below minimumContentWidth",
            failures: &failures
        )
        let midMirrorPreferred = WorkspaceTouchBarLayout.preferredContentWidth(
            mirrorPixelSize: CGSize(width: 1_600, height: 70),
            backingScaleFactor: 2
        )
        expect(
            abs(midMirrorPreferred - 800) < 0.5,
            "preferred width must track mirror points when below the hardware cap",
            failures: &failures
        )
        let strip = WorkspaceTouchBarLayout.stripFrames(
            in: NSRect(
                x: 0,
                y: 0,
                width: WorkspaceTouchBarLayout.designReferenceBarWidth,
                height: 30
            )
        )
        let stripUsable = strip.tray.width
            - WorkspaceTouchBarLayout.trayTrailingSafeInset
        let expectedQuotaWidth = floor(
            stripUsable * CGFloat(WorkspaceTouchBarLayout.quotaUnits)
                / CGFloat(WorkspaceTouchBarLayout.totalUnits)
        )
        expect(
            abs(strip.switcher.width - WorkspaceTouchBarLayout.switcherWidth) < 1
                && strip.tray.minX > strip.switcher.maxX
                && abs(strip.quota.width - expectedQuotaWidth) < 1
                && abs(
                    strip.quota.width + strip.apps.width - stripUsable
                ) < 1
                && abs(
                    strip.switcher.width + WorkspaceTouchBarLayout.switcherContentGap
                        + strip.tray.width
                        + WorkspaceTouchBarStyle.canvasInset * 2
                        - WorkspaceTouchBarLayout.designReferenceBarWidth
                ) < 2,
            "full bar strip: switcher outside; quota 4/10; apps 6/10",
            failures: &failures
        )
        expect(
            abs(
                WorkspaceTouchBarLayout.preferredTrayWidth(
                    mirrorPixelSize: TouchBarPreferences.defaultMirrorPixelSize,
                    backingScaleFactor: 2
                )
                    - (
                        WorkspaceTouchBarLayout.maximumContentWidth
                            - WorkspaceTouchBarLayout.switcherWidth
                            - WorkspaceTouchBarLayout.switcherContentGap
                    )
            ) < 0.5,
            "physical tray width must exclude the escape-slot return control",
            failures: &failures
        )
        let workspaceItemProbe = WorkspaceTouchBarContentView(
            quotaView: NSView(),
            customView: NSView()
        )
        expect(
            abs(
                workspaceItemProbe.intrinsicContentSize.width
                    - WorkspaceTouchBarLayout.preferredTrayWidth()
            ) < 0.5
                && workspaceItemProbe.intrinsicContentSize.width
                    >= WorkspaceTouchBarLayout.minimumContentWidth
                        - WorkspaceTouchBarLayout.switcherWidth
                        - WorkspaceTouchBarLayout.switcherContentGap
                && abs(
                    workspaceItemProbe.intrinsicContentSize.height
                        - WorkspaceTouchBarStyle.controlHeight
                ) < 0.5,
            "Workspace tray item must size to remaining width after the escape-slot return",
            failures: &failures
        )
        expect(
            WorkspaceReturnItemView().fittingSize.width
                <= WorkspaceTouchBarLayout.switcherWidth + 1,
            "physical Workspace return must stay a compact escape-replacement control",
            failures: &failures
        )
        let chromeProbe = WorkspaceChromeButton(
            frame: NSRect(x: 0, y: 0, width: 44, height: 28)
        )
        chromeProbe.highlight(true)
        expect(
            chromeProbe.layer?.borderWidth == 1
                && chromeProbe.layer?.backgroundColor != nil,
            "Workspace chrome button must show pressed chrome while highlighted",
            failures: &failures
        )
        chromeProbe.highlight(false)
        expect(
            chromeProbe.layer?.borderWidth == 0,
            "Workspace chrome button must clear pressed chrome after release",
            failures: &failures
        )
        expect(
            WorkspaceTouchBarStyle.failureSymbolName == nil,
            "undisplayed directories must not use a warning symbol",
            failures: &failures
        )
        let barWidth: CGFloat = 1_000
        let barBounds = NSRect(x: 0, y: 0, width: barWidth, height: 30)
        let fullStrip = WorkspaceTouchBarLayout.stripFrames(in: barBounds)
        let usableTray = fullStrip.tray.width
            - WorkspaceTouchBarLayout.trayTrailingSafeInset
        let expectedFullQuota = floor(
            usableTray * CGFloat(WorkspaceTouchBarLayout.quotaUnits)
                / CGFloat(WorkspaceTouchBarLayout.totalUnits)
        )
        expect(
            fullStrip.tray.maxX <= barWidth - WorkspaceTouchBarStyle.canvasInset + 0.5
                && fullStrip.switcher.minX
                    >= WorkspaceTouchBarStyle.canvasInset - 0.5,
            "strip must stay inside canvas insets",
            failures: &failures
        )
        expect(
            fullStrip.quota.maxX <= fullStrip.apps.minX + 0.5,
            "Workspace quota|apps regions must be separate and ordered",
            failures: &failures
        )
        expect(
            abs(fullStrip.quota.width - expectedFullQuota) < 1,
            "quota region must be 4/10 of usable tray",
            failures: &failures
        )
        expect(
            abs(
                fullStrip.quota.width + fullStrip.apps.width - usableTray
            ) < 1,
            "two zones must cover the usable tray width",
            failures: &failures
        )
        expect(
            WorkspaceTouchBarLayout.customSlotCount(appCount: 2) == 3
                && WorkspaceTouchBarLayout.customSlotCount(appCount: 0) == 1
                && WorkspaceTouchBarLayout.customSlotCount(appCount: 5) == 6,
            "slot counts: apps+settings or empty label",
            failures: &failures
        )
        let quotaPlate = QuotaPlateView(
            frame: NSRect(x: 0, y: 0, width: 360, height: 30)
        )
        var openedProvider: QuotaProviderID?
        quotaPlate.onOpenProvider = { openedProvider = $0 }
        quotaPlate.display(.empty)
        quotaPlate.layoutSubtreeIfNeeded()
        expect(
            quotaPlate.groupViews.isEmpty && openedProvider == nil,
            "empty quota plate must not open a provider",
            failures: &failures
        )
        let now = Date(timeIntervalSince1970: 1_000_000)
        let grokBuild = QuotaPool(
            provider: .grokBuild,
            windows: [
                QuotaWindow(
                    kind: .fiveHour,
                    remaining: 41,
                    limit: 100,
                    resetAt: now.addingTimeInterval(3 * 3600 + 21 * 60),
                    cycle: 5 * 3600
                ),
                QuotaWindow(
                    kind: .weekly,
                    remaining: 78,
                    limit: 100,
                    resetAt: now.addingTimeInterval(4 * 86400),
                    cycle: 7 * 86400
                ),
            ],
            fetchedAt: now
        )
        let grokBots = QuotaPool(
            provider: .grokBots,
            windows: [
                QuotaWindow(
                    kind: .fiveHour,
                    remaining: 20,
                    limit: 100,
                    resetAt: now.addingTimeInterval(24 * 3600),
                    cycle: 5 * 3600
                )
            ],
            fetchedAt: now
        )
        let codex = QuotaPool(
            provider: .codex,
            windows: [
                QuotaWindow(
                    kind: .weekly,
                    remaining: 80,
                    limit: 100,
                    resetAt: now.addingTimeInterval(72 * 3600),
                    cycle: 7 * 86400
                )
            ],
            fetchedAt: now
        )
        let decision = QuotaRecommendationEngine.recommend(
            pools: [codex, grokBuild, grokBots],
            now: now
        )
        expect(
            decision?.provider == .grokBuild
                && decision?.highlightedKind == .fiveHour,
            "soon-reset leftover quota must outrank fuller weekly allotments",
            failures: &failures
        )
        let botsRisk = QuotaRecommendationEngine.wasteRisk(
            window: grokBots.windows[0],
            now: now
        )
        let codexRisk = QuotaRecommendationEngine.wasteRisk(
            window: codex.windows[0],
            now: now
        )
        expect(
            botsRisk > codexRisk,
            "a nearer empty-ish window must outrank a distant fuller weekly window",
            failures: &failures
        )
        let emptyDecision = QuotaRecommendationEngine.recommend(
            pools: [
                QuotaPool(
                    provider: .codex,
                    windows: [
                        QuotaWindow(
                            kind: .weekly,
                            remaining: 0,
                            limit: 100,
                            resetAt: now.addingTimeInterval(3600),
                            cycle: 7 * 86400
                        )
                    ],
                    fetchedAt: now
                )
            ],
            now: now
        )
        expect(
            emptyDecision == nil,
            "exhausted pools must not be recommended",
            failures: &failures
        )
        let boardState = QuotaBoardState.from(
            pools: [codex, grokBuild, grokBots],
            now: now,
            hiddenProviderIDs: []
        )
        expect(
            boardState.groups.count == 3
                && boardState.recommendedProvider == .grokBuild
                && boardState.groups.contains(where: {
                    $0.provider == .grokBuild
                        && $0.isRecommended
                        && $0.fiveHour.isHighlighted
                        && $0.fiveHour.valueText == "41%"
                        && $0.reset.valueText == "4d0h"
                })
                && boardState.groups.contains(where: {
                    $0.provider == .codex
                        && $0.weekly.valueText == "80%"
                        && $0.reset.valueText == "3d0h"
                })
                && boardState.groups.contains(where: {
                    $0.provider == .grokBots
                        && $0.reset.ratio == nil
                        && $0.reset.valueText == "—"
                }),
            "quota board must show every pool as three bars, mark the recommended 5h, and time reset from the weekly window",
            failures: &failures
        )
        let hiddenCodex = QuotaBoardState.from(
            pools: [codex, grokBuild, grokBots],
            now: now,
            hiddenProviderIDs: [QuotaProviderID.codex.rawValue]
        )
        expect(
            hiddenCodex.groups.count == 2
                && hiddenCodex.groups.contains(where: {
                    $0.provider == .grokBuild
                })
                && hiddenCodex.groups.contains(where: {
                    $0.provider == .grokBots
                })
                && !hiddenCodex.groups.contains(where: {
                    $0.provider == .codex
                }),
            "hidden quota providers must not appear on the board",
            failures: &failures
        )
        let weeklyOnlyBoard = QuotaBoardState.from(
            pools: [
                QuotaPool(
                    provider: .codex,
                    windows: [
                        QuotaWindow(
                            kind: .weekly,
                            remaining: 80,
                            limit: 100,
                            resetAt: now.addingTimeInterval(3 * 86400),
                            cycle: 7 * 86400
                        )
                    ],
                    fetchedAt: now
                )
            ],
            now: now
        )
        expect(
            weeklyOnlyBoard.groups.count == 1
                && weeklyOnlyBoard.groups[0].fiveHour.isAvailable == false
                && weeklyOnlyBoard.groups[0].weekly.valueText == "80%"
                && !weeklyOnlyBoard.groups[0].tooltip.contains("5h"),
            "pools without a 5h window must not expose a 5h quota metric",
            failures: &failures
        )
        let weeklyOnlyPlate = QuotaPlateView(
            frame: NSRect(x: 0, y: 0, width: 360, height: 30)
        )
        weeklyOnlyPlate.display(weeklyOnlyBoard)
        weeklyOnlyPlate.layoutSubtreeIfNeeded()
        expect(
            weeklyOnlyPlate.groupViews.count == 1
                && abs(
                    weeklyOnlyPlate.groupViews[0].frame.width
                        - WorkspaceTouchBarLayout.quotaGroupTwoBarMinimumWidth
                ) < 1
                && weeklyOnlyPlate.groupViews[0].frame.width
                    < WorkspaceTouchBarLayout.quotaGroupMinimumWidth,
            "a lone two-bar group must use the narrower card width",
            failures: &failures
        )
        let twoGroupFit = WorkspaceTouchBarLayout.quotaScrollArrangement(
            plateWidth: 360,
            groupCount: 2
        )
        expect(
            twoGroupFit.needsScroll == false
                && abs(twoGroupFit.contentWidth - 360) < 0.5
                && twoGroupFit.groupWidths.count == 2
                && twoGroupFit.groupWidths.allSatisfy {
                    $0 >= WorkspaceTouchBarLayout.quotaGroupMinimumWidth
                },
            "two three-bar groups that fit must fill the plate without scrolling",
            failures: &failures
        )
        let threeGroupScroll = WorkspaceTouchBarLayout.quotaScrollArrangement(
            plateWidth: 360,
            groupCount: 3
        )
        expect(
            threeGroupScroll.needsScroll
                && threeGroupScroll.contentWidth > 360
                && threeGroupScroll.groupWidths.allSatisfy {
                    abs(
                        $0 - WorkspaceTouchBarLayout.quotaGroupMinimumWidth
                    ) < 0.5
                },
            "three three-bar groups must keep a readable width and scroll in the 4/10 plate",
            failures: &failures
        )
        let mixedWidths = WorkspaceTouchBarLayout.quotaScrollArrangement(
            plateWidth: 360,
            showsFiveHourPerGroup: [true, false]
        )
        expect(
            mixedWidths.needsScroll == false
                && mixedWidths.groupWidths.count == 2
                && abs(
                    mixedWidths.groupWidths[1]
                        - WorkspaceTouchBarLayout.quotaGroupTwoBarMinimumWidth
                ) < 0.5
                && mixedWidths.groupWidths[0]
                    > mixedWidths.groupWidths[1] + 0.5,
            "two-bar groups must stay narrower than three-bar groups on the plate",
            failures: &failures
        )
        quotaPlate.display(boardState)
        quotaPlate.layoutSubtreeIfNeeded()
        expect(
            quotaPlate.groupViews.count == 3
                && quotaPlate.needsHorizontalScroll
                && quotaPlate.contentWidth > quotaPlate.bounds.width
                && quotaPlate.groupViews.allSatisfy { view in
                    let expected = WorkspaceTouchBarLayout.quotaGroupMinimumWidth(
                        showsFiveHour: view.state?.fiveHour.isAvailable == true
                    )
                    return abs(view.frame.width - expected) < 1
                        && view.frame.maxX <= quotaPlate.contentWidth + 0.5
                }
                && (quotaPlate.groupViews.last?.frame.maxX ?? 0)
                    > quotaPlate.bounds.width
                && (
                    quotaPlate.groupViews.first {
                        $0.state?.provider == .codex
                    }?.frame.width
                        ?? 0
                )
                    < WorkspaceTouchBarLayout.quotaGroupMinimumWidth,
            "quota plate must size two-bar cards narrower and scroll overflow",
            failures: &failures
        )
        openedProvider = nil
        quotaPlate.groupViews.first { $0.state?.provider == .grokBuild }?
            .onActivate?(.grokBuild)
        expect(
            openedProvider == .grokBuild,
            "tapping a quota group must open that provider",
            failures: &failures
        )
        let appsZone = WorkspaceTouchBarLayout.zoneContentRect(
            WorkspaceTouchBarLayout.stripFrames(
                in: NSRect(
                    x: 0,
                    y: 0,
                    width: WorkspaceTouchBarLayout.designReferenceBarWidth,
                    height: 30
                )
            ).apps
        )
        let appsView = WorkspaceCustomAppsView(
            frame: NSRect(
                x: 0,
                y: 0,
                width: appsZone.width,
                height: 30
            )
        )
        appsView.display(
            apps: [
                CustomWorkspaceApp(
                    bundleIdentifier: "com.apple.finder",
                    applicationPath: "/System/Library/CoreServices/Finder.app",
                    displayName: "Finder"
                ),
                CustomWorkspaceApp(
                    bundleIdentifier: "com.apple.Safari",
                    applicationPath: "/Applications/Safari.app",
                    displayName: "Safari"
                ),
                CustomWorkspaceApp(
                    bundleIdentifier: "com.apple.TextEdit",
                    applicationPath: "/System/Applications/TextEdit.app",
                    displayName: "TextEdit"
                ),
            ]
        )
        appsView.layoutSubtreeIfNeeded()
        let settingsFrame = appsView.settingsButtonFrame
        expect(
            settingsFrame.width > 20
                && settingsFrame.maxX <= appsView.bounds.maxX + 0.5
                && settingsFrame.minX >= appsView.bounds.minX - 0.5,
            "settings gear must sit fully inside the apps zone",
            failures: &failures
        )
        expect(
            QuotaDisplayFormatting.percent(0.41) == "41%"
                && QuotaDisplayFormatting.countdown(3 * 3600 + 21 * 60) == "3h21m"
                && QuotaDisplayFormatting.countdown(72 * 3600) == "3d0h",
            "quota display formatting must keep compact countdown text",
            failures: &failures
        )
        expect(
            WorkspaceTouchBarStyle.providerIcon(for: .codex) != nil
                && WorkspaceTouchBarStyle.providerIcon(for: .grokBuild) != nil
                && WorkspaceTouchBarStyle.providerIcon(for: .grokBots) != nil
                && WorkspaceTouchBarStyle.providerIcon(for: .cursor) != nil
                && WorkspaceTouchBarStyle.providerIcon(for: .antigravity) != nil
                && WorkspaceTouchBarStyle.providerIcon(for: .openrouter) != nil
                && WorkspaceTouchBarStyle.providerIcon(for: .copilot) != nil
                && WorkspaceTouchBarStyle.providerIcon(for: .opencode) != nil
                && WorkspaceTouchBarStyle.providerIcon(for: .ollama) != nil
                && WorkspaceTouchBarStyle.providerIcon(for: .devin) != nil
                && QuotaProviderID.antigravity.iconResourceName
                    == "antigravity"
                && QuotaProviderID.openrouter.iconResourceName
                    == "openrouter"
                && QuotaProviderID.grokBots.iconResourceName == "grokBots",
            "quota providers must ship matching brand icons",
            failures: &failures
        )
        expect(
            QuotaProviderLaunch.matchingCustomApp(
                provider: .codex,
                apps: [
                    CustomWorkspaceApp(
                        bundleIdentifier: "com.openai.codex",
                        applicationPath: "/Applications/Codex.app",
                        displayName: "Codex"
                    )
                ]
            )?.displayName == "Codex",
            "recommended tap must resolve a matching pinned app",
            failures: &failures
        )
        let openUsageFixture = """
        {
          "schema": "openusage.limits.v1",
          "providers": {
            "codex": {
              "fetchedAt": "2026-09-08T13:42:50.000Z",
              "resources": {
                "session": {
                  "kind": "consumption",
                  "limit": 100,
                  "remaining": 100,
                  "resetsAt": "2026-09-08T18:42:48.000Z",
                  "windowSeconds": 18000
                },
                "weekly": {
                  "kind": "consumption",
                  "limit": 100,
                  "remaining": 95,
                  "resetsAt": "2026-09-15T05:15:54.000Z",
                  "windowSeconds": 604800
                },
                "credits": {
                  "kind": "balance",
                  "available": 999
                }
              }
            },
            "grok": {
              "fetchedAt": "2026-09-08T13:44:43.559Z",
              "resources": {
                "weekly": {
                  "kind": "consumption",
                  "limit": 100,
                  "remaining": 63,
                  "resetsAt": "2026-09-09T14:01:32.864Z",
                  "windowSeconds": 604800
                }
              }
            },
            "cursor": {
              "fetchedAt": "2026-09-08T13:42:51.000Z",
              "resources": {
                "grokBot": {
                  "kind": "consumption",
                  "limit": 100,
                  "remaining": 100,
                  "windowSeconds": 604800
                },
                "totalUsage": {
                  "kind": "consumption",
                  "limit": 20,
                  "remaining": 0
                },
                "autoUsage": {
                  "kind": "consumption",
                  "unit": "percent",
                  "limit": 100,
                  "remaining": 75,
                  "windowSeconds": 2678400
                }
              }
            },
            "antigravity": {
              "displayName": "Antigravity",
              "fetchedAt": "2026-09-08T13:42:50.000Z",
              "resources": {
                "geminiSession": {
                  "kind": "consumption",
                  "unit": "percent",
                  "limit": 100,
                  "remaining": 80,
                  "windowSeconds": 18000
                },
                "geminiWeekly": {
                  "kind": "consumption",
                  "unit": "percent",
                  "limit": 100,
                  "remaining": 90,
                  "windowSeconds": 604800
                }
              }
            },
            "openrouter": {
              "displayName": "OpenRouter",
              "fetchedAt": "2026-09-08T13:42:50.000Z",
              "resources": {
                "credits": {
                  "kind": "consumption",
                  "unit": "usd",
                  "limit": 35,
                  "remaining": 4
                },
                "keyLimit": {
                  "kind": "consumption",
                  "unit": "usd",
                  "limit": 0.01,
                  "remaining": 0.01
                },
                "balance": {
                  "kind": "balance",
                  "unit": "usd",
                  "available": 12
                }
              }
            }
          }
        }
        """.data(using: .utf8)!
        do {
            let envelope = try OpenUsageLimitsMapper.decodeEnvelope(
                from: openUsageFixture
            )
            let mapped = OpenUsageLimitsMapper.pools(
                from: envelope,
                now: OpenUsageDateParser.date(
                    from: "2026-09-08T13:44:43.000Z"
                ) ?? Date()
            )
            let mappedIDs = mapped.map(\.provider)
            expect(
                mappedIDs == [
                    .grokBuild, .grokBots, .codex, .cursor, .antigravity,
                    .openrouter,
                ],
                "OpenUsage mapper must emit every consumption provider, not only the first three",
                failures: &failures
            )
            let mappedCodex = mapped.first { $0.provider == .codex }
            let mappedGrok = mapped.first { $0.provider == .grokBuild }
            let mappedBots = mapped.first { $0.provider == .grokBots }
            expect(
                mappedCodex?.windows.contains(where: {
                    $0.kind == .fiveHour && abs($0.remainingRatio - 1) < 0.001
                }) == true
                    && mappedCodex?.windows.contains(where: {
                        $0.kind == .weekly && abs($0.remainingRatio - 0.95) < 0.001
                    }) == true,
                "OpenUsage Codex session maps to 5h and weekly remaining",
                failures: &failures
            )
            expect(
                mappedGrok?.windows.contains(where: {
                    $0.kind == .weekly && abs($0.remainingRatio - 0.63) < 0.001
                }) == true
                    && mappedGrok?.windows.contains(where: {
                        $0.kind == .fiveHour
                    }) != true,
                "OpenUsage Grok SuperGrok maps to Grok Build weekly only",
                failures: &failures
            )
            expect(
                mappedBots?.windows.contains(where: {
                    $0.kind == .weekly && abs($0.remainingRatio - 1) < 0.001
                }) == true,
                "OpenUsage Cursor grokBot maps to Grok Bots weekly",
                failures: &failures
            )
            let mappedCursor = mapped.first { $0.provider == .cursor }
            let mappedAntigravity = mapped.first { $0.provider == .antigravity }
            let mappedOpenRouter = mapped.first { $0.provider == .openrouter }
            expect(
                mappedCursor?.title == "Cursor"
                    && mappedCursor?.windows.contains(where: {
                        $0.kind == .weekly && abs($0.remainingRatio - 0.75) < 0.001
                    }) == true,
                "Cursor keeps its own usage pool besides Grok Bots",
                failures: &failures
            )
            expect(
                mappedAntigravity?.title == "Antigravity"
                    && mappedAntigravity?.windows.contains(where: {
                        $0.kind == .fiveHour && abs($0.remainingRatio - 0.8) < 0.001
                    }) == true
                    && mappedAntigravity?.windows.contains(where: {
                        $0.kind == .weekly && abs($0.remainingRatio - 0.9) < 0.001
                    }) == true,
                "Antigravity session and weekly must both appear",
                failures: &failures
            )
            expect(
                mappedOpenRouter?.title == "OpenRouter"
                    && mappedOpenRouter?.windows.contains(where: {
                        $0.kind == .weekly && abs($0.remainingRatio - (4.0 / 35.0)) < 0.001
                    }) == true
                    && mappedOpenRouter?.windows.contains(where: {
                        abs($0.limit - 0.01) < 0.0001
                    }) != true,
                "OpenRouter credits must show and keyLimit must be ignored",
                failures: &failures
            )
        } catch {
            failures.append(
                "OpenUsage fixture JSON failed to decode: \(error)"
            )
        }
        expect(
            WorkspaceFloatingSwitcherView.Gesture.shouldToggle(
                duration: 0.1,
                distance: 0
            ),
            "short stationary switcher presses must toggle Workspace",
            failures: &failures
        )
        expect(
            !WorkspaceFloatingSwitcherView.Gesture.shouldToggle(
                duration: 0.5,
                distance: 0
            ) && !WorkspaceFloatingSwitcherView.Gesture.shouldToggle(
                duration: 0.1,
                distance: 12
            ),
            "long presses and drags must not toggle Workspace",
            failures: &failures
        )
        expect(
            Array(QuotaProviderID.preferredDisplayOrder.prefix(3))
                == [.grokBuild, .grokBots, .codex],
            "known quota providers must keep their leading display order",
            failures: &failures
        )
        expect(
            TouchBarPreferences.settingsWindowAutosaveName
                == "ToubarReplaceSettingsWindow",
            "settings window resize persistence name changed unexpectedly",
            failures: &failures
        )
        expect(
            TouchBarHoverOpacity.normal == 1
                && TouchBarHoverOpacity.hovered == 0.3,
            "desktop hover opacity defaults changed unexpectedly",
            failures: &failures
        )
        expect(
            TouchBarHoverOpacity.targetAlpha(isMouseInside: false)
                == TouchBarHoverOpacity.normal
                && TouchBarHoverOpacity.targetAlpha(isMouseInside: true)
                == TouchBarHoverOpacity.hovered,
            "desktop window must drop to 30% opacity while the cursor is inside",
            failures: &failures
        )
        expect(
            TouchBarHoverOpacity.isMouseInside(
                windowFrame: CGRect(x: 100, y: 0, width: 1_000, height: 40),
                mouseLocation: CGPoint(x: 120, y: 10)
            )
                && !TouchBarHoverOpacity.isMouseInside(
                    windowFrame: CGRect(x: 100, y: 0, width: 1_000, height: 40),
                    mouseLocation: CGPoint(x: 50, y: 10)
                ),
            "hover opacity must follow the desktop window frame, not physical Touch Bar",
            failures: &failures
        )
        if let firstImage = makeTestImage(width: 1),
            let secondImage = makeTestImage(width: 2),
            let latestImage = makeTestImage(width: 3)
        {
            let probe = SmokeFrameDeliveryProbe()
            let coalescer = TouchBarFrameDeliveryCoalescer { image in
                probe.deliveredWidths.append(image.width)
            }
            coalescer.submit(firstImage)
            coalescer.submit(secondImage)
            coalescer.submit(latestImage)
            await Task.yield()
            await Task.yield()
            expect(
                probe.deliveredWidths == [3],
                "main-actor frame delivery must coalesce queued frames to the latest",
                failures: &failures
            )
        } else {
            failures.append("could not create frame-coalescing smoke-test images")
        }
        expect(
            TouchBarSystemState.isControlStripExplicitlyEmpty(
                fullCustomized: [],
                miniCustomized: []
            ),
            "empty Control Strip must be detected",
            failures: &failures
        )
        expect(
            !TouchBarSystemState.isControlStripExplicitlyEmpty(
                fullCustomized: ["com.apple.system.volume"],
                miniCustomized: []
            ),
            "non-empty Control Strip must not be reported as empty",
            failures: &failures
        )
        expect(
            !TouchBarSystemState.isControlStripExplicitlyEmpty(
                fullCustomized: nil,
                miniCustomized: []
            ),
            "missing Control Strip settings must not be reported as empty",
            failures: &failures
        )

        for presentationMode in [
            "app",
            "appWithControlStrip",
            "quickActions",
            "quickActionsWithControlStrip",
            "workflows",
            "workflowsWithControlStrip",
        ] {
            expect(
                TouchBarSystemState.allowsEmptyContent(
                    presentationMode: presentationMode
                ),
                "\(presentationMode) must allow empty content",
                failures: &failures
            )
        }
        for presentationMode in [
            "fullControlStrip",
            "functionKeys",
            "spaces",
            "spacesWithControlStrip",
        ] {
            expect(
                !TouchBarSystemState.allowsEmptyContent(
                    presentationMode: presentationMode
                ),
                "\(presentationMode) must not allow empty content",
                failures: &failures
            )
        }
        expect(
            !TouchBarSystemState.allowsEmptyContent(presentationMode: nil),
            "missing presentation mode must not allow empty content",
            failures: &failures
        )

        // Apple Silicon / no-Touch-Bar software Workspace policies.
        expect(
            !TouchBarHardwareCapability.softwareWorkspaceMode(
                canPresentSystemModal: true,
                canCreateDisplayStream: true,
                canInstantiateDisplayStream: true
            ),
            "usable physical Touch Bar stack must not enter software Workspace mode",
            failures: &failures
        )
        expect(
            TouchBarHardwareCapability.softwareWorkspaceMode(
                canPresentSystemModal: false,
                canCreateDisplayStream: true,
                canInstantiateDisplayStream: true
            ),
            "missing system-modal present must enter software Workspace mode",
            failures: &failures
        )
        expect(
            TouchBarHardwareCapability.softwareWorkspaceMode(
                canPresentSystemModal: true,
                canCreateDisplayStream: false,
                canInstantiateDisplayStream: false
            ),
            "missing display-stream symbol must enter software Workspace mode",
            failures: &failures
        )
        expect(
            TouchBarHardwareCapability.softwareWorkspaceMode(
                canPresentSystemModal: true,
                canCreateDisplayStream: true,
                canInstantiateDisplayStream: false
            ),
            "stream symbol without instantiable stream must enter software Workspace mode",
            failures: &failures
        )
        expect(
            WorkspaceStartupScenePolicy.scene(storedRawValue: nil) == .workspace
                && WorkspaceStartupScenePolicy.scene(storedRawValue: "mirror")
                    == .mirror
                && WorkspaceStartupScenePolicy.scene(storedRawValue: "bogus")
                    == .workspace,
            "未配置或非法值时启动场景默认为 Workspace",
            failures: &failures
        )
        expect(
            SoftwareWorkspaceLaunchPolicy.shouldEnterWorkspaceAtLaunch(
                usesSoftwareWorkspace: true,
                preferredScene: .workspace
            )
                && SoftwareWorkspaceLaunchPolicy.shouldEnterWorkspaceAtLaunch(
                    usesSoftwareWorkspace: false,
                    preferredScene: .workspace
                )
                && !SoftwareWorkspaceLaunchPolicy.shouldEnterWorkspaceAtLaunch(
                    usesSoftwareWorkspace: false,
                    preferredScene: .mirror
                )
                && !SoftwareWorkspaceLaunchPolicy.shouldEnterWorkspaceAtLaunch(
                    usesSoftwareWorkspace: true,
                    preferredScene: .mirror
                ),
            "启动是否进入 Workspace 只看启动场景偏好，与有无物理栏无关",
            failures: &failures
        )
        expect(
            SoftwareWorkspaceLaunchPolicy.shouldStartHardwareCapture(
                usesSoftwareWorkspace: false
            )
                && !SoftwareWorkspaceLaunchPolicy.shouldStartHardwareCapture(
                    usesSoftwareWorkspace: true
                ),
            "硬件模式启动 Workspace 仍要开显示流；软件模式不能开",
            failures: &failures
        )
        expect(
            TouchBarResumePolicy.action(
                usesSoftwareWorkspace: true,
                restoreWorkspace: false
            ) == .restoreSoftwareWorkspace,
            "软件 Workspace 唤醒后不能重启捕获流",
            failures: &failures
        )
        expect(
            TouchBarResumePolicy.action(
                usesSoftwareWorkspace: false,
                restoreWorkspace: false
            ) == .restartHardwareCapture,
            "物理栏从镜像睡眠后只恢复捕获流",
            failures: &failures
        )
        expect(
            TouchBarResumePolicy.action(
                usesSoftwareWorkspace: false,
                restoreWorkspace: true
            ) == .restoreHardwareWorkspace,
            "物理栏从 Workspace 睡眠后要重新 present Workspace",
            failures: &failures
        )
        expect(
            WorkspaceSleepPausePolicy.latchedResumeToWorkspace(
                alreadyPaused: false,
                latchedResume: false,
                sceneIsWorkspace: true
            )
                && WorkspaceSleepPausePolicy.latchedResumeToWorkspace(
                    alreadyPaused: true,
                    latchedResume: true,
                    sceneIsWorkspace: false
                )
                && !WorkspaceSleepPausePolicy.latchedResumeToWorkspace(
                    alreadyPaused: false,
                    latchedResume: false,
                    sceneIsWorkspace: false
                ),
            "睡眠多次通知不能把 Workspace 唤醒闩锁冲成镜像",
            failures: &failures
        )
        expect(
            WorkspaceAsyncSessionPolicy.canUpdate(
                capturedGeneration: 4,
                currentGeneration: 4,
                scene: .workspace
            ),
            "当前 Workspace generation 应允许异步回写",
            failures: &failures
        )
        expect(
            !WorkspaceAsyncSessionPolicy.canUpdate(
                capturedGeneration: 3,
                currentGeneration: 4,
                scene: .workspace
            ) && !WorkspaceAsyncSessionPolicy.canUpdate(
                capturedGeneration: 4,
                currentGeneration: 4,
                scene: .mirror
            ),
            "旧 generation 或已关闭 Workspace 不得异步回写",
            failures: &failures
        )
        expect(
            SoftwareWorkspaceLaunchPolicy.effectiveSwitcherDisplayMode(
                usesSoftwareWorkspace: true,
                preferred: .touchBar
            ) == .floating
                && SoftwareWorkspaceLaunchPolicy.effectiveSwitcherDisplayMode(
                    usesSoftwareWorkspace: true,
                    preferred: .touchBar,
                    scene: .workspace
                ) == .touchBar
                && SoftwareWorkspaceLaunchPolicy.effectiveSwitcherDisplayMode(
                    usesSoftwareWorkspace: false,
                    preferred: .touchBar
                ) == .touchBar
                && SoftwareWorkspaceLaunchPolicy.effectiveSwitcherDisplayMode(
                    usesSoftwareWorkspace: false,
                    preferred: .touchBar,
                    scene: .workspace
                ) == .touchBar
                && SoftwareWorkspaceLaunchPolicy.effectiveSwitcherDisplayMode(
                    usesSoftwareWorkspace: false,
                    preferred: .floating,
                    scene: .workspace
                ) == .floating,
            "software uses floating only in mirror; hardware honors preference in both scenes; Workspace does not force an extra desktop switcher",
            failures: &failures
        )
        expect(
            MirrorClickThroughPolicy.ignoresMouseEvents(
                usesSoftwareWorkspace: false,
                scene: .mirror,
                showsWorkspaceFallback: false
            )
                && MirrorClickThroughPolicy.ignoresMouseEvents(
                    usesSoftwareWorkspace: false,
                    scene: .workspace,
                    showsWorkspaceFallback: false
                ),
            "hardware mirror and physical Workspace must stay click-through",
            failures: &failures
        )
        expect(
            !MirrorClickThroughPolicy.ignoresMouseEvents(
                usesSoftwareWorkspace: true,
                scene: .workspace,
                showsWorkspaceFallback: true
            )
                && !MirrorClickThroughPolicy.ignoresMouseEvents(
                    usesSoftwareWorkspace: false,
                    scene: .workspace,
                    showsWorkspaceFallback: true
                ),
            "desktop Workspace fallback must accept mouse events",
            failures: &failures
        )
        expect(
            MirrorClickThroughPolicy.ignoresMouseEvents(
                usesSoftwareWorkspace: true,
                scene: .mirror,
                showsWorkspaceFallback: false
            ),
            "software idle/mirror surface must stay click-through",
            failures: &failures
        )
        // Live probe: when this Mac has a usable stack, software mode must stay off
        // (Intel Touch Bar regression guard). Soft machines correctly report true.
        if TouchBarHardwareCapability.canPresentSystemModal
            && TouchBarHardwareCapability.canInstantiateDisplayStream
        {
            expect(
                !TouchBarHardwareCapability.usesSoftwareWorkspace,
                "live hardware probe must keep software Workspace mode off",
                failures: &failures
            )
        }

        return failures
    }

    private static func expect(
        _ condition: @autoclosure () -> Bool,
        _ message: String,
        failures: inout [String]
    ) {
        if !condition() {
            failures.append(message)
        }
    }

    private static func makeTestImage(width: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        return CGContext(
            data: nil,
            width: width,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )?.makeImage()
    }
}
