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
        check(!controller.isExpanded && !panel.isVisible && panel.frame.origin == origin && panel.ignoresMouseEvents
              && TouchBarPreferences.displayPosition == fixedPosition,
              "pointer clicks and drags must neither reveal nor move the hidden interface or change its position setting")

        for theme in [DesktopTheme.black, .glass] {
            host.apply(theme: theme)
            capsule.apply(theme: theme)
            root.apply(theme: theme)
            check(!panel.isVisible && panel.frame.size == CGSize(width: 900, height: 35),
                  "\(theme): hidden state must remove the entire window and retain configured geometry")
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
                  && capsule.subviews.count == 1,
                  "\(theme): workspace must use the full configured size without extra desktop controls")
            controller.toggle()
            try? await Task.sleep(for: .milliseconds(800))
            check(!panel.isVisible && panel.frame.size == CGSize(width: 900, height: 35)
                  && panel.frame.origin == origin && root.superview?.isHidden == true,
                  "\(theme): hiding must remove the entire real window and retain its configured position")
        }

        controller.toggle()
        try? await Task.sleep(for: .milliseconds(80))
        controller.toggle()
        check(!panel.isVisible && !controller.isAnimating && panel.frame.origin == origin,
              "hiding during a reveal must immediately remove the window and cancel the animation")
        try? await Task.sleep(for: .milliseconds(800))
        check(!panel.isVisible, "a cancelled reveal must stay hidden after its previous animation deadline")
        controller.configure(pixelSize: CGSize(width: 2_000, height: 140), backingScaleFactor: 2)
        check(!panel.isVisible && panel.frame.origin == origin,
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
                check(appWindow.isVisible && appCapsule.isExpanded
                      && appWindow.frame.size == CGSize(width: 900, height: 35) && appCapsule.subviews.count == 1,
                      "production \(scene): startup must show the complete configured interface")
                appController.toggleDesktopCapsule()
                check(!appWindow.isVisible && !appCapsule.isExpanded && appWindow.ignoresMouseEvents,
                      "production \(scene): manual hiding must remove the complete window")
                appController.toggleDesktopCapsule()
                try? await Task.sleep(for: .milliseconds(850))
                check(appCapsule.isExpanded && appRoot.scene == initialScene
                      && appWindow.isVisible && appWindow.frame.size == appCapsule.expandedSize
                      && appWindow.frame.origin == initialOrigin,
                      "production \(scene): manual activation must expand to configured dimensions while preserving scene and origin")
                check(appController.mirrorPixelSize == CGSize(width: 1_800, height: 70)
                      && appController.displayPosition == .bottom,
                      "production animation must preserve configured pixel dimensions and positioning policy")
                if !TouchBarHardwareCapability.usesSoftwareWorkspace {
                    check(appWindow.ignoresMouseEvents, "production hardware content must pass through pointer events")
                }
                appController.toggleDesktopCapsule()
                check(!appWindow.isVisible && !appCapsule.isExpanded && appRoot.scene == initialScene,
                      "production \(scene): manual hiding must preserve the scene")
                appController.setMirrorPixelSize(CGSize(width: 2_000, height: 140))
                check(!appWindow.isVisible && appWindow.frame.size == CGSize(width: 1_000, height: 70)
                      && appWindow.frame.origin == initialOrigin,
                      "production \(scene): changing settings while hidden must preserve the position and hidden state")
                appController.toggleDesktopCapsule()
                try? await Task.sleep(for: .milliseconds(850))
                check(appWindow.isVisible && appCapsule.isExpanded && appRoot.scene == initialScene
                      && appWindow.frame.size == CGSize(width: 1_000, height: 70) && appWindow.frame.origin == initialOrigin,
                      "production \(scene): manual activation must restore the configured interface")
                if !TouchBarHardwareCapability.usesSoftwareWorkspace {
                    check(appWindow.ignoresMouseEvents, "manual activation must retain hardware mouse pass-through")
                }
                samples.append(["phase": "production_controller", "scene": String(describing: scene),
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
            controller.setExpanded(true, animated: false)
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
                check(controller.isExpanded && panel.isVisible && panel.frame.size == CGSize(width: 1_000, height: 70),
                      "entering full screen must preserve the visible interface and configured geometry")
                samples.append(["phase": "full_screen", "width": panel.frame.width, "height": panel.frame.height,
                                "visible": panel.isVisible,
                                "system_full_screen": NSApp.currentSystemPresentationOptions.contains(.fullScreen),
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
                            check(startupWindow.isVisible && startupCapsule.isExpanded
                                  && startupWindow.frame.size == startupCapsule.expandedSize,
                                  "production \(scene): launching in full screen must show the configured interface")
                            samples.append(["phase": "full_screen_startup", "scene": String(describing: scene),
                                            "visible": startupWindow.isVisible, "width": startupWindow.frame.width])
                        } else { failures.append("full-screen startup view hierarchy is missing") }
                        startup.stop()
                        startup.window?.orderOut(nil)
                        try? await Task.sleep(for: .milliseconds(100))
                    }
                    WorkspacePreferences.startupScene = savedStartup
                    TouchBarPreferences.mirrorPixelSize = savedPixels
                }
                controller.setExpanded(false, animated: false)
                wake.wakeView.button.performClick(nil)
                try? await Task.sleep(for: .milliseconds(1_200))
                check(controller.isExpanded && panel.isVisible && panel.frame.width == 1_000,
                      "manual activation in full screen must show the complete interface")
                controller.setExpanded(false, animated: false)
                for _ in 0..<110 {
                    try? await Task.sleep(for: .milliseconds(100))
                    if fixtureEvents().contains(where: { $0["phase"] as? String == "exited" }) { break }
                }
                check(fixtureEvents().contains(where: {
                    $0["phase"] as? String == "exited" && $0["window_full_screen"] as? Bool == false
                }), "fixture must return to a normal desktop Space")
                try? await Task.sleep(for: .milliseconds(650))
                check(!controller.isExpanded && !panel.isVisible && panel.frame.size == CGSize(width: 1_000, height: 70),
                      "leaving full screen must preserve a manually hidden interface")
                samples.append(["phase": "returned_to_desktop", "visible": panel.isVisible,
                                "width": panel.frame.width])
                wake.wakeView.button.performClick(nil)
                try? await Task.sleep(for: .milliseconds(850))
                check(controller.isExpanded && panel.isVisible && panel.frame.size == CGSize(width: 1_000, height: 70),
                      "manual activation after leaving full screen must restore the complete interface")
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
