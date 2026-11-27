import AppKit

@MainActor
final class CapsuleValidationDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var fixtureWindow: NSWindow?
    private var fixtureEvents: [[String: Any]] = []
    private var pendingNativeRelease: (() -> Void)?

    @objc private func releaseNativeContact() {
        pendingNativeRelease?()
        pendingNativeRelease = nil
    }

    private func recordFixture(_ phase: String) {
        fixtureEvents.append(["phase": phase, "pid": ProcessInfo.processInfo.processIdentifier,
            "frontmost_pid": NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0,
            "system_options": NSApp.currentSystemPresentationOptions.rawValue,
            "window_full_screen": fixtureWindow?.styleMask.contains(.fullScreen) ?? false])
        if let destination = CommandLine.arguments.last,
           let data = try? JSONSerialization.data(withJSONObject: fixtureEvents, options: [.prettyPrinted]) {
            try? data.write(to: URL(fileURLWithPath: destination))
        }
    }

    func windowDidEnterFullScreen(_ notification: Notification) { recordFixture("entered") }
    func windowDidFailToEnterFullScreen(_ window: NSWindow) { recordFixture("failed") }
    func windowDidExitFullScreen(_ notification: Notification) { recordFixture("exited") }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--fullscreen-fixture") {
            startFullScreenFixture()
        } else {
            NSApp.setActivationPolicy(.accessory)
            Task { @MainActor in await verifyCapsule() }
        }
    }

    private func startFullScreenFixture() {
        NSApp.setActivationPolicy(.regular)
        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 600, height: 300),
                              styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
        window.title = "ToubarReplace 全屏回归"
        window.collectionBehavior = [.fullScreenPrimary]
        window.delegate = self
        window.contentView = NSTextField(labelWithString: "正在验证 ToubarReplace 全屏切换时保持显隐状态…")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        fixtureWindow = window
        recordFixture("started")
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            window.toggleFullScreen(nil)
            recordFixture("requested")
            try? await Task.sleep(for: .seconds(8))
            window.toggleFullScreen(nil)
            try? await Task.sleep(for: .seconds(5))
            NSApp.terminate(nil)
        }
    }

    private func verifyCapsule() async {
        var failures: [String] = []
        var blockers: [String] = []
        var samples: [[String: Any]] = []
        @MainActor func check(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message) }
        }
        let root = TouchBarRootView(frame: NSRect(x: 0, y: 0, width: 900, height: 35))
        root.setScene(.workspace)
        root.setWorkspaceFallbackVisible(true)
        let metric = QuotaBarMetric(ratio: 0.5, caption: "周", valueText: "50%", isHighlighted: false)
        let group = QuotaProviderGroupState(provider: .codex, title: "Codex", fiveHour: metric,
            weekly: metric, reset: metric, tooltip: "Codex", isRecommended: false)
        root.workspaceView.showQuota(QuotaBoardState(groups: [group], recommendedProvider: nil))
        let capsule = DesktopCapsuleView(content: root)
        let host = DesktopGlassHostView(content: capsule, usesCapsuleShape: true)
        let panel = NSPanel(contentRect: capsule.frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.ignoresMouseEvents = true
        panel.isMovableByWindowBackground = false
        panel.minSize = DesktopCapsuleLayout.minimumSize
        panel.contentView = host
        let controller = DesktopCapsuleController(window: panel, view: capsule)
        controller.configure(pixelSize: CGSize(width: 1_800, height: 70), backingScaleFactor: 2)
        let screen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1_440, height: 900)
        panel.setFrameOrigin(CGPoint(x: screen.minX + 80, y: screen.minY + 80))
        let origin = panel.frame.origin
        controller.start()
        controller.setExpanded(false)
        root.workspaceView.onCollapse = { controller.setExpanded(false) }
        let hideButton = root.workspaceView.subviews.compactMap { $0 as? DesktopCapsuleButton }.first

        func pointerGesture(drag: Bool = false) {
            let location = CGPoint(x: 24, y: panel.frame.height / 2)
            let timestamp = ProcessInfo.processInfo.systemUptime
            guard let down = NSEvent.mouseEvent(with: .leftMouseDown, location: location, modifierFlags: [],
                timestamp: timestamp, windowNumber: panel.windowNumber, context: nil,
                eventNumber: 1, clickCount: 1, pressure: 1),
                let up = NSEvent.mouseEvent(with: .leftMouseUp, location: location, modifierFlags: [],
                timestamp: timestamp + 0.05, windowNumber: panel.windowNumber, context: nil,
                eventNumber: 2, clickCount: 1, pressure: 0) else {
                failures.append("native pointer event creation failed")
                return
            }
            let move = drag ? NSEvent.mouseEvent(with: .leftMouseDragged, location: CGPoint(x: 100, y: 24),
                modifierFlags: [], timestamp: timestamp + 0.02, windowNumber: panel.windowNumber,
                context: nil, eventNumber: 3, clickCount: 1, pressure: 1) : nil
            pendingNativeRelease = {
                if let move { NSApp.postEvent(move, atStart: false) }
                NSApp.postEvent(up, atStart: false)
            }
            let release = Timer(timeInterval: 0.05, target: self, selector: #selector(releaseNativeContact),
                                userInfo: nil, repeats: false)
            RunLoop.main.add(release, forMode: .common)
            RunLoop.main.add(release, forMode: .eventTracking)
            panel.sendEvent(down)
            release.invalidate()
            pendingNativeRelease = nil
        }

        let wake = DesktopWakeTouchBarController()
        var wakeCount = 0
        wake.onWake = {
            wakeCount += 1
            if !controller.isExpanded { controller.show() }
        }
        let fixedPosition = TouchBarPreferences.displayPosition
        pointerGesture()
        pointerGesture(drag: true)
        check(!controller.isExpanded && panel.isVisible && panel.alphaValue == 0
              && panel.frame.origin == origin && panel.ignoresMouseEvents
              && TouchBarPreferences.displayPosition == fixedPosition,
              "pointer clicks and drags must neither reveal nor move the hidden interface or change its position setting")

        for theme in DesktopTheme.allCases {
            host.apply(theme: theme)
            capsule.apply(theme: theme)
            root.apply(theme: theme)
            check(panel.isVisible && panel.alphaValue == 0 && panel.frame.size == CGSize(width: 900, height: 35),
                  "\(theme): the hidden window must stay ordered and fully transparent at its configured size")
            wake.wakeView.button.performClick(nil)
            try? await Task.sleep(for: .milliseconds(80))
            let intermediateWidth = panel.frame.width
            let intermediateAlpha = root.superview?.alphaValue ?? 0
            samples.append(["theme": "\(theme)", "phase": "expanding", "width": intermediateWidth,
                            "content_alpha": intermediateAlpha, "window_alpha": panel.alphaValue])
            check(intermediateWidth > 48 && intermediateWidth < 900 && intermediateAlpha > 0 && intermediateAlpha < 1,
                  "\(theme): real window must expand and reveal content simultaneously")
            try? await Task.sleep(for: .milliseconds(800))
            check(panel.isVisible && panel.frame.size == CGSize(width: 900, height: 35)
                  && panel.frame.origin == origin && panel.alphaValue == 1,
                  "\(theme): expanded window must match configured total width at a fixed origin")
            check(root.frame.size == CGSize(width: 900, height: 35) && root.superview?.alphaValue == 1
                  && capsule.subviews.count == (theme == .smoke ? 2 : 1),
                  "\(theme): workspace must use the full configured size without extra desktop controls")
            check(hideButton?.accessibilityPerformPress() == true, "the Workspace hide button must handle the press")
            try? await Task.sleep(for: .milliseconds(800))
            check(!controller.isExpanded && panel.isVisible && panel.alphaValue == 0 && panel.frame.size == CGSize(width: 900, height: 35)
                  && panel.frame.origin == origin && root.superview?.isHidden == true,
                  "\(theme): the hide button must make the entire window transparent at its configured position")
        }

        controller.toggle()
        try? await Task.sleep(for: .milliseconds(80))
        controller.toggle()
        check(panel.isVisible && panel.alphaValue == 0 && !controller.isAnimating && panel.frame.origin == origin,
              "hiding during a reveal must immediately make the window transparent and cancel the animation")
        try? await Task.sleep(for: .milliseconds(800))
        check(panel.isVisible && panel.alphaValue == 0, "a cancelled reveal must stay transparent after its animation deadline")
        controller.configure(pixelSize: CGSize(width: 2_000, height: 140), backingScaleFactor: 2)
        check(panel.isVisible && panel.alphaValue == 0 && panel.frame.origin == origin,
              "changing dimensions while hidden must retain visibility and position")
        controller.toggle()
        try? await Task.sleep(for: .milliseconds(800))
        check(panel.frame.size == CGSize(width: 1_000, height: 70) && panel.frame.origin == origin,
              "real window must apply updated pixel dimensions while preserving its left origin")

        controller.setExpanded(false, animated: false)

        let wakePanel = NSPanel(contentRect: wake.wakeView.frame, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
        wakePanel.contentView = wake.wakeView
        wakePanel.setFrameOrigin(CGPoint(x: screen.minX + 80, y: screen.minY + 200))
        wakePanel.orderFrontRegardless()
        let contactPoint = CGPoint(x: wake.wakeView.frame.width * 0.73, y: 15)
        let contactTime = ProcessInfo.processInfo.systemUptime
        if let down = NSEvent.mouseEvent(with: .leftMouseDown, location: contactPoint, modifierFlags: [],
                timestamp: contactTime, windowNumber: wakePanel.windowNumber, context: nil,
                eventNumber: 1, clickCount: 1, pressure: 1),
           let up = NSEvent.mouseEvent(with: .leftMouseUp, location: contactPoint, modifierFlags: [],
                timestamp: contactTime + 0.1, windowNumber: wakePanel.windowNumber, context: nil,
                eventNumber: 2, clickCount: 1, pressure: 0) {
            let beforeWakeCount = wakeCount
            pendingNativeRelease = {
                check(wake.isTrackingTouch && !controller.isExpanded,
                      "touch-down must retain the wake layer until the finger lifts")
                NSApp.postEvent(up, atStart: true)
            }
            let release = Timer(timeInterval: 0.1, target: self, selector: #selector(releaseNativeContact),
                                userInfo: nil, repeats: false)
            RunLoop.main.add(release, forMode: .common)
            RunLoop.main.add(release, forMode: .eventTracking)
            wakePanel.sendEvent(down)
            check(controller.isExpanded && wakeCount == beforeWakeCount + 1 && !wake.isTrackingTouch,
                  "a native wake-region button must expand exactly once on touch release")
            check(DesktopTouchBarPolicy.presentation(running: true, paused: false,
                expanded: controller.isExpanded, animating: controller.isAnimating,
                trackingWakeTouch: wake.isTrackingTouch) == .wake,
                "native wake input must keep normal controls gated while the expansion animates")
        } else { failures.append("native wake-region pointer event creation failed") }
        try? await Task.sleep(for: .milliseconds(800))
        wakePanel.orderOut(nil)
        check(DesktopTouchBarPolicy.presentation(running: true, paused: false,
            expanded: controller.isExpanded, animating: controller.isAnimating,
            trackingWakeTouch: wake.isTrackingTouch) == .scene,
            "normal controls may restore only after native wake release and settled expansion")

        pointerGesture()
        pointerGesture(drag: true)
        check(controller.isExpanded && panel.frame.origin == origin && panel.ignoresMouseEvents,
              "the expanded hardware capsule must also pass through pointer clicks and drags")

        func findCapsule(in view: NSView) -> DesktopCapsuleView? {
            if let capsule = view as? DesktopCapsuleView { return capsule }
            for child in view.subviews {
                if let capsule = findCapsule(in: child) { return capsule }
            }
            return nil
        }
        let savedStartup = WorkspacePreferences.startupScene
        let savedPixels = TouchBarPreferences.mirrorPixelSize
        let savedPosition = TouchBarPreferences.displayPosition
        for scene in [WorkspaceStartupScene.mirror, .workspace] {
            WorkspacePreferences.startupScene = scene
            let appController = TouchBarWindowController()
            appController.setDisplayPosition(.bottom)
            appController.setMirrorPixelSize(CGSize(width: 1_800, height: 70))
            appController.start()
            if let appWindow = appController.window, let host = appWindow.contentView,
               let appCapsule = findCapsule(in: host), let appRoot = appCapsule.content as? TouchBarRootView {
                let initialOrigin = appWindow.frame.origin
                let initialScene = appRoot.scene
                let startedExpanded = appCapsule.isExpanded
                if !startedExpanded {
                    check(appWindow.isVisible && appWindow.alphaValue == 0 && appWindow.ignoresMouseEvents,
                          "production \(scene): a collapsed startup window must be transparent before a manual wake")
                    appController.toggleDesktopCapsule()
                    try? await Task.sleep(for: .milliseconds(850))
                }
                check(appWindow.isVisible && appWindow.alphaValue == 1 && appCapsule.isExpanded
                      && appWindow.frame.size == CGSize(width: 900, height: 35)
                      && appCapsule.subviews.count == (appRoot.desktopTheme == .smoke ? 2 : 1),
                      "production \(scene): the expanded window must show the complete configured interface")
                appController.toggleDesktopCapsule()
                check(appWindow.isVisible && appWindow.alphaValue == 0 && !appCapsule.isExpanded && appWindow.ignoresMouseEvents,
                      "production \(scene): a manually hidden window must be transparent and pass clicks through")
                appController.toggleDesktopCapsule()
                try? await Task.sleep(for: .milliseconds(850))
                check(appCapsule.isExpanded && appRoot.scene == initialScene
                      && appWindow.isVisible && appWindow.alphaValue == 1 && appWindow.frame.size == appCapsule.expandedSize
                      && appWindow.frame.origin == initialOrigin,
                      "production \(scene): manual activation must expand to configured dimensions while preserving scene and origin")
                check(appController.mirrorPixelSize == CGSize(width: 1_800, height: 70)
                      && appController.displayPosition == .bottom,
                      "production animation must preserve configured pixel dimensions and positioning policy")
                if !TouchBarHardwareCapability.usesSoftwareWorkspace {
                    check(appWindow.ignoresMouseEvents, "production hardware content must pass through pointer events")
                }
                appController.toggleDesktopCapsule()
                check(appWindow.isVisible && appWindow.alphaValue == 0 && !appCapsule.isExpanded && appRoot.scene == initialScene,
                      "production \(scene): manual hiding must preserve the scene")
                appController.setMirrorPixelSize(CGSize(width: 2_000, height: 140))
                check(appWindow.isVisible && appWindow.alphaValue == 0 && appWindow.frame.size == CGSize(width: 1_000, height: 70)
                      && appWindow.frame.origin == initialOrigin,
                      "production \(scene): changing settings while hidden must preserve the position and hidden state")
                appController.toggleDesktopCapsule()
                try? await Task.sleep(for: .milliseconds(850))
                check(appWindow.isVisible && appWindow.alphaValue == 1 && appCapsule.isExpanded && appRoot.scene == initialScene
                      && appWindow.frame.size == CGSize(width: 1_000, height: 70) && appWindow.frame.origin == initialOrigin,
                      "production \(scene): manual activation must restore the configured interface")
                if !TouchBarHardwareCapability.usesSoftwareWorkspace {
                    check(appWindow.ignoresMouseEvents, "manual activation must retain hardware mouse pass-through")
                }
                samples.append(["phase": "production_controller", "scene": String(describing: scene),
                                "started_expanded": startedExpanded, "window_alpha": appWindow.alphaValue,
                                "software_fallback": TouchBarHardwareCapability.usesSoftwareWorkspace,
                                "width": appWindow.frame.width, "height": appWindow.frame.height,
                                "visible": appWindow.isVisible, "pointer_transparent": appWindow.ignoresMouseEvents])
            } else { failures.append("production capsule view hierarchy is missing") }
            appController.stop()
            appController.window?.orderOut(nil)
            try? await Task.sleep(for: .milliseconds(100))
        }
        WorkspacePreferences.startupScene = savedStartup
        TouchBarPreferences.mirrorPixelSize = savedPixels
        TouchBarPreferences.displayPosition = savedPosition

        let windowChecksPassed = failures.isEmpty
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.loginwindow" {
            blockers.append("macOS is at the login/lock screen; unlock the desktop to verify a real full-screen Space")
        } else {
            controller.start()
            let spaceMonitor = DesktopSpaceVisibilityMonitor(window: panel) { expanded in
                controller.setExpanded(expanded)
            }
            spaceMonitor.start()
            defer { spaceMonitor.stop() }
            let fixture = Process()
            fixture.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            let fixtureReport = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/private/tmp/report.json")
                .deletingLastPathComponent().appendingPathComponent("fixture-report.json").path
            try? FileManager.default.removeItem(atPath: fixtureReport)
            fixture.arguments = ["-n", Bundle.main.bundlePath, "--args", "--fullscreen-fixture", fixtureReport]
            func fixtureEvents() -> [[String: Any]] {
                guard let data = try? Data(contentsOf: URL(fileURLWithPath: fixtureReport)),
                      let events = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return [] }
                return events
            }
            do {
                try fixture.run()
                for _ in 0..<40 {
                    try? await Task.sleep(for: .milliseconds(100))
                    if fixtureEvents().contains(where: { $0["phase"] as? String == "entered" }) { break }
                }
                let enteredFullScreen = fixtureEvents().contains(where: {
                    $0["phase"] as? String == "entered" && $0["window_full_screen"] as? Bool == true
                })
                check(enteredFullScreen, "fixture must enter a real macOS full-screen Space")
                try? await Task.sleep(for: .milliseconds(650))
                check(!controller.isExpanded && panel.isVisible && panel.alphaValue == 0
                      && panel.ignoresMouseEvents && panel.frame.size == CGSize(width: 1_000, height: 70),
                      "entering full screen must make the window transparent at its configured size")
                samples.append(["phase": "full_screen", "width": panel.frame.width, "height": panel.frame.height,
                                "window_alpha": panel.alphaValue, "ordered": panel.isVisible,
                                "fixture_full_screen": enteredFullScreen,
                                "frontmost_pid": NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0,
                                "system_options": NSApp.currentSystemPresentationOptions.rawValue])
                if enteredFullScreen {
                    for scene in [WorkspaceStartupScene.mirror, .workspace] {
                        WorkspacePreferences.startupScene = scene
                        let startup = TouchBarWindowController()
                        startup.setMirrorPixelSize(CGSize(width: 1_800, height: 70))
                        startup.start()
                        if let startupWindow = startup.window, let host = startupWindow.contentView,
                           let startupCapsule = findCapsule(in: host) {
                            check(startupWindow.isVisible && startupWindow.alphaValue == 0 && !startupCapsule.isExpanded
                                  && startupWindow.ignoresMouseEvents
                                  && startupWindow.frame.size == startupCapsule.expandedSize,
                                  "production \(scene): launching in full screen must make the configured window transparent")
                            samples.append(["phase": "full_screen_startup", "scene": String(describing: scene),
                                            "window_alpha": startupWindow.alphaValue, "width": startupWindow.frame.width])
                        } else { failures.append("full-screen startup view hierarchy is missing") }
                        startup.stop()
                        startup.window?.orderOut(nil)
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                    WorkspacePreferences.startupScene = savedStartup
                    TouchBarPreferences.mirrorPixelSize = savedPixels
                }
                wake.wakeView.button.performClick(nil)
                try? await Task.sleep(for: .milliseconds(1_200))
                check(controller.isExpanded && panel.isVisible && panel.alphaValue == 1 && panel.frame.width == 1_000,
                      "manual activation in full screen must show the complete interface")
                check(hideButton?.accessibilityPerformPress() == true && panel.isVisible && panel.alphaValue == 0,
                      "the hide button must make the window transparent again in the same full-screen Space")
                for _ in 0..<110 {
                    try? await Task.sleep(for: .milliseconds(100))
                    if fixtureEvents().contains(where: { $0["phase"] as? String == "exited" }) { break }
                }
                check(fixtureEvents().contains(where: {
                    $0["phase"] as? String == "exited" && $0["window_full_screen"] as? Bool == false
                }), "fixture must return to a normal desktop Space")
                try? await Task.sleep(for: .milliseconds(650))
                check(controller.isExpanded && panel.isVisible && panel.alphaValue == 1 && panel.frame.size == CGSize(width: 1_000, height: 70),
                      "returning to the desktop must automatically restore the opaque window and configured geometry")
                samples.append(["phase": "returned_to_desktop", "window_alpha": panel.alphaValue,
                                "width": panel.frame.width])
                if let identifier = fixtureEvents().last?["pid"] as? Int32 {
                    NSRunningApplication(processIdentifier: identifier)?.terminate()
                }
            } catch { failures.append("full-screen fixture launch failed: \(error)") }
        }

        controller.stop()
        panel.orderOut(nil)
        let report: [String: Any] = ["passed": failures.isEmpty && blockers.isEmpty,
            "window_checks_passed": windowChecksPassed, "failures": failures, "blockers": blockers, "samples": samples]
        let output = CommandLine.arguments.dropFirst().first ?? "/private/tmp/toubarreplace-capsule-report.json"
        if let data = try? JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: URL(fileURLWithPath: output))
        }
        print(failures.isEmpty ? "Desktop capsule window checks passed" : failures.joined(separator: "\n"))
        blockers.forEach { print($0) }
        NSApp.terminate(nil)
    }
}

@main
enum CapsuleValidationMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = CapsuleValidationDelegate()
        application.delegate = delegate
        application.run()
    }
}
