import AppKit

enum DesktopCapsuleSmokeTest {
    @MainActor
    static func failures() -> [String] {
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message) }
        }

        let desktop = DesktopSpaceSnapshot(displayID: 1, spaceID: 10, spaceType: 0)
        let fullScreen = DesktopSpaceSnapshot(displayID: 1, spaceID: 20, spaceType: 4)
        let anotherDesktop = DesktopSpaceSnapshot(displayID: 1, spaceID: 30, spaceType: 0)
        let anotherFullScreen = DesktopSpaceSnapshot(displayID: 1, spaceID: 40, spaceType: 4)
        let secondDisplayDesktop = DesktopSpaceSnapshot(displayID: 2, spaceID: 10, spaceType: 0)
        var visibility = DesktopSpaceVisibilityPolicy()
        check(visibility.expansion(for: desktop) == true,
              "launching on a normal desktop must show the interface")
        check(visibility.expansion(for: desktop) == nil,
              "repeated desktop notifications must preserve manual hiding")
        check(visibility.expansion(for: fullScreen) == false,
              "entering a fullscreen or tiled Space must hide the interface")
        check(visibility.expansion(for: fullScreen) == nil,
              "manual wake inside the same fullscreen Space must remain effective")
        check(visibility.expansion(for: anotherFullScreen) == false,
              "switching to a different fullscreen Space must hide a manually woken interface")
        check(visibility.expansion(for: desktop) == true,
              "returning to the desktop must reveal the interface even after manual hiding")
        check(visibility.expansion(for: anotherDesktop) == true,
              "arriving on another normal desktop must reveal the interface")
        check(visibility.expansion(for: nil) == nil && visibility.lastSnapshot == anotherDesktop,
              "unavailable Space data must preserve both visibility and the last known Space")
        check(visibility.expansion(for: anotherDesktop) == nil,
              "recovering data for the same Space must preserve manual visibility")
        check(visibility.expansion(for: secondDisplayDesktop) == true,
              "moving the interface to another display must follow that display's current Space")
        check(DesktopSpaceSnapshot(displayID: 1, spaceID: 0, spaceType: 0) == nil
              && DesktopSpaceSnapshot(displayID: 1, spaceID: 50, spaceType: 2) == nil,
              "invalid and transitional Space types must not be mistaken for a desktop")
        var fullScreenLaunch = DesktopSpaceVisibilityPolicy()
        check(fullScreenLaunch.expansion(for: fullScreen) == false,
              "launching while already in fullscreen must hide the interface")

        let pixels = CGSize(width: 2_300, height: 70)
        let retinaSize = DesktopCapsuleLayout.expandedSize(pixelSize: pixels, backingScaleFactor: 2)
        check(retinaSize == CGSize(width: 1_150, height: 35),
              "the complete desktop interface must use both configured pixel dimensions")
        check(DesktopCapsuleLayout.expandedSize(pixelSize: pixels, backingScaleFactor: 1).width == 2_300,
              "configured capsule width must follow the current display scale")
        check(DesktopCapsuleLayout.expandedSize(pixelSize: CGSize(width: 1, height: 1), backingScaleFactor: 2)
              == DesktopCapsuleLayout.minimumSize,
              "small configured dimensions must retain valid window geometry")
        check(DesktopCapsuleLayout.expandedSize(pixelSize: CGSize(width: 1_800, height: 160), backingScaleFactor: 2)
              == CGSize(width: 900, height: 80),
              "expanded capsule must retain larger configured content heights")

        let origin = CGPoint(x: -1_350, y: -200)
        let openFrame = DesktopCapsuleLayout.frame(origin: origin, size: retinaSize)
        let revealingFrame = DesktopCapsuleLayout.frame(origin: origin, size: CGSize(width: 48, height: 35))
        check(openFrame.minX == revealingFrame.minX && openFrame.minY == revealingFrame.minY
              && revealingFrame.maxX < openFrame.maxX,
              "the left anchor must stay fixed while revealing content on secondary displays")
        let contentFrame = DesktopCapsuleLayout.contentFrame(expandedSize: retinaSize)
        check(contentFrame.origin == .zero && contentFrame.size == retinaSize,
              "content must occupy the full configured width and height")
        check(DesktopCapsuleLayout.contentAlpha(width: 48, expandedWidth: 1_150) == 0
              && DesktopCapsuleLayout.contentAlpha(width: 350, expandedWidth: 1_150) > 0
              && DesktopCapsuleLayout.contentAlpha(width: 350, expandedWidth: 1_150) < 1
              && DesktopCapsuleLayout.contentAlpha(width: 1_150, expandedWidth: 1_150) == 1,
              "content must fade in while the capsule expands rather than after it settles")

        var spring = DesktopCapsuleSpring(value: 48)
        spring.target = 1_150
        var maximum: CGFloat = 0
        for _ in 0..<120 {
            spring.advance(by: 1 / 120)
            maximum = max(maximum, spring.value)
        }
        check(maximum > 1_150 && maximum < 1_190 && spring.isSettled && spring.value == 1_150,
              "capsule expansion must spring with a restrained overshoot and settle at the configured width")
        spring.target = 48
        for _ in 0..<120 { spring.advance(by: 1 / 120) }
        check(spring.isSettled && spring.value == 48, "the reveal spring must settle at its latest target")
        spring.target = 1_150
        for _ in 0..<12 { spring.advance(by: 1 / 120) }
        let interruptedValue = spring.value
        let interruptedVelocity = spring.velocity
        spring.target = 48
        check(spring.value == interruptedValue && spring.velocity == interruptedVelocity,
              "rapid reverse must preserve the displayed width and spring velocity")
        for _ in 0..<180 { spring.advance(by: 1 / 120) }
        check(spring.value == 48 && spring.isSettled, "interrupted expansion must finish at the latest collapse target")

        let content = NSView()
        let capsule = DesktopCapsuleView(content: content)
        capsule.expandedSize = retinaSize
        for theme in [DesktopTheme.black, .glass] {
            capsule.apply(theme: theme)
            capsule.frame.size = retinaSize
            capsule.setExpanded(false)
            capsule.updateReveal(width: retinaSize.width)
            capsule.needsLayout = true
            capsule.layoutSubtreeIfNeeded()
            check(capsule.subviews.count == 1 && content.superview?.isHidden == true
                  && capsule.hitTest(CGPoint(x: 24, y: 24)) == nil,
                  "both themes must have only the content container with no extra desktop controls")
            capsule.frame.size = retinaSize
            capsule.setExpanded(true)
            capsule.updateReveal(width: retinaSize.width)
            capsule.needsLayout = true
            capsule.layoutSubtreeIfNeeded()
            check(content.frame.size == retinaSize && content.superview?.alphaValue == 1
                  && capsule.layer?.cornerRadius == 17.5,
                  "both themes must reveal the content at the complete configured size")
            capsule.contentAcceptsMouseEvents = false
            check(capsule.hitTest(CGPoint(x: 24, y: 24)) == nil,
                  "the hardware mirror must pass pointer events through its full content area")
        }
        check(DesktopTouchBarPolicy.presentation(running: true, paused: false, expanded: false,
            animating: false, trackingWakeTouch: false) == .wake, "collapsed capsule must present the full-width wake layer")
        check(DesktopTouchBarPolicy.presentation(running: true, paused: false, expanded: true,
            animating: true, trackingWakeTouch: false) == .wake, "normal controls must wait for expansion to finish")
        check(DesktopTouchBarPolicy.presentation(running: true, paused: false, expanded: true,
            animating: false, trackingWakeTouch: true) == .wake, "normal controls must wait for the waking finger to lift")
        check(DesktopTouchBarPolicy.presentation(running: true, paused: false, expanded: true,
            animating: false, trackingWakeTouch: false) == .scene, "settled expansion must restore the prior scene")
        check(DesktopTouchBarPolicy.presentation(running: false, paused: false, expanded: true,
            animating: false, trackingWakeTouch: false) == .inactive
            && DesktopTouchBarPolicy.presentation(running: true, paused: true, expanded: false,
                animating: false, trackingWakeTouch: false) == .inactive,
            "stopping and sleep must release the wake layer")
        check(DesktopTouchBarPolicy.ignoresPointer(expanded: false, animating: false, softwareControls: true)
            && DesktopTouchBarPolicy.ignoresPointer(expanded: true, animating: false, softwareControls: false)
            && !DesktopTouchBarPolicy.ignoresPointer(expanded: true, animating: false, softwareControls: true),
            "collapsed and hardware capsules must pass through pointer events; software content remains usable")

        let wake = DesktopWakeTouchBarController()
        check(wake.touchBar.defaultItemIdentifiers == [DesktopWakeTouchBarController.wakeIdentifier]
            && wake.touchBar.escapeKeyReplacementItemIdentifier == DesktopWakeTouchBarController.escapeIdentifier
            && DesktopWakeTouchBarController.placement == 1 && DesktopWakeTouchBarController.presentationMode == "app",
            "wake mode must own one full-width item and route the Escape slot to the same wake action")
        var wakePresses = 0
        wake.onWake = { wakePresses += 1 }
        for region in [wake.wakeView, wake.escapeView] {
            region.layoutSubtreeIfNeeded()
            for fraction in [0.001, 0.25, 0.5, 0.75, 0.999] {
                check(region.hitTest(CGPoint(x: region.bounds.width * fraction, y: 15)) === region.button,
                    "every sampled wake-region position, including its edges, must target the wake button")
            }
            region.button.performClick(nil)
        }
        check(wakePresses == 2, "main wake region and Escape must trigger only the shared wake action")
        return failures
    }
}
