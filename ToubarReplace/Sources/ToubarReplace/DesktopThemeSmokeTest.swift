import AppKit

enum DesktopThemeSmokeTest {
    static func fixture(width: Int = 9, height: Int = 7) -> CGImage? {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let ring = (2...6).contains(x) && (1...5).contains(y)
                    && (x == 2 || x == 6 || y == 1 || y == 5)
                let color: UInt8 = ring ? 80 : (x == 1 && y == 3 ? 12 : 0)
                bytes[offset] = color
                bytes[offset + 1] = color
                bytes[offset + 2] = color
                bytes[offset + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8,
                       bitsPerPixel: 32, bytesPerRow: width * 4, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: MirrorGlassFrameRenderer.bitmapInfo),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    static func rgba(_ image: CGImage) -> [UInt8] {
        guard let data = image.dataProvider?.data else { return [] }
        guard let bytes = CFDataGetBytePtr(data) else { return [] }
        return Array(UnsafeBufferPointer(start: bytes, count: CFDataGetLength(data)))
    }

    static func chromeFixture(horizontalOffset: Int = 0) -> CGImage? {
        let width = 160, height = 30
        var bytes = [UInt8](repeating: 54, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let contentX = x + horizontalOffset
                bytes[offset + 3] = 255
                if (15...35).contains(contentX) && (5...25).contains(y) {
                    let ring = contentX == 15 || contentX == 35 || y == 5 || y == 25
                    bytes[offset] = ring ? 80 : 0
                    bytes[offset + 1] = ring ? 140 : 0
                    bytes[offset + 2] = ring ? 220 : 0
                }
                if (100...110).contains(contentX) && (8...22).contains(y) {
                    bytes[offset] = 255; bytes[offset + 1] = 255; bytes[offset + 2] = 255
                }
                if contentX == 99 && (8...22).contains(y) {
                    bytes[offset] = 128; bytes[offset + 1] = 128; bytes[offset + 2] = 128
                }
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                       bytesPerRow: width * 4, space: space,
                       bitmapInfo: CGBitmapInfo(rawValue: MirrorGlassFrameRenderer.bitmapInfo),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    @MainActor
    static func functionKeyFixture() -> CGImage? {
        guard let context = CGContext(data: nil, width: 768, height: 30,
            bitsPerComponent: 8, bytesPerRow: 768 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: MirrorGlassFrameRenderer.bitmapInfo) else { return nil }
        context.setFillColor(NSColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 768, height: 30))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        for index in 0..<12 {
            let key = CGRect(x: CGFloat(index * 64 + 2), y: 3, width: 60, height: 24)
            context.setFillColor(NSColor(white: 0.21, alpha: 1).cgColor)
            context.addPath(CGPath(roundedRect: key, cornerWidth: 4, cornerHeight: 4, transform: nil))
            context.fillPath()
            let label = NSAttributedString(string: "F\(index + 1)", attributes: [
                .font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.white
            ])
            label.draw(at: NSPoint(x: key.midX - label.size().width / 2, y: 7))
        }
        NSGraphicsContext.restoreGraphicsState()
        return context.makeImage()
    }

    @MainActor
    static func functionKeyFailures() async -> [String] {
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message) }
        }
        guard let functionKeys = functionKeyFixture(), let workspaceCapture = chromeFixture(),
              let mirrorCapture = fixture(),
              let composedKeys = MirrorGlassFrameRenderer().render(functionKeys) else {
            return ["function key capture fixtures must render"]
        }
        let root = TouchBarRootView(frame: NSRect(x: 0, y: 0, width: 500, height: 35))
        let expectedKeys = rgba(composedKeys)
        func waitForComposedKeys() async {
            for _ in 0..<100 {
                if root.surfaceView.currentFrameContents.map(rgba) == expectedKeys { break }
                try? await Task.sleep(for: .milliseconds(5))
            }
        }
        root.apply(theme: .glass)
        root.setScene(.workspace)
        root.displayCapture(image: workspaceCapture)
        var flags: CGEventFlags = .maskShift
        var changes: [Bool] = []
        let monitor = TouchBarFunctionKeyMonitor(readFlags: { flags }) { pressed in
            changes.append(pressed)
            root.setFunctionKeyPressed(pressed)
        }
        monitor.start()
        monitor.start()
        check(monitor.isMonitoring && !monitor.isPressed && changes.isEmpty,
              "non-Fn modifiers and repeated starts must preserve the native glass Workspace")
        flags = [.maskSecondaryFn, .maskShift]
        monitor.refresh()
        monitor.refresh()
        check(changes == [true] && !root.workspaceView.isHidden && root.surfaceView.isHidden
              && root.scene == .workspace && !root.showsWorkspaceFallback,
              "pressing Fn must keep native glass visible until a new function frame has been composed")
        try? await Task.sleep(for: .milliseconds(25))
        check(!root.workspaceView.isHidden && root.surfaceView.currentFrameContents == nil,
              "Fn preparation must not reprocess or reveal the retained original Workspace frame")
        if let delayedWorkspaceCapture = chromeFixture(horizontalOffset: 1) {
            root.displayCapture(image: delayedWorkspaceCapture)
            try? await Task.sleep(for: .milliseconds(25))
            check(!root.workspaceView.isHidden && root.surfaceView.currentFrameContents == nil,
                  "late Workspace captures must remain excluded while preparing the Fn row")
        } else { check(false, "delayed Workspace fixture must render") }
        root.displayCapture(image: functionKeys)
        check(!root.workspaceView.isHidden && root.surfaceView.isHidden,
              "the native glass Workspace must remain visible while function key composition is pending")
        await waitForComposedKeys()
        check(root.surfaceView.currentFrameContents.map(rgba) == expectedKeys
              && root.surfaceView.latestOriginalFrame === functionKeys
              && !root.surfaceView.isHidden && root.workspaceView.isHidden,
              "glass Workspace must render the actual captured F1 through F12 row while Fn is held")
        root.displayCapture(image: workspaceCapture)
        try? await Task.sleep(for: .milliseconds(25))
        check(root.surfaceView.currentFrameContents.map(rgba) == expectedKeys,
              "a reordered old Workspace frame must never replace the visible function key row")
        check(MirrorClickThroughPolicy.ignoresMouseEvents(usesSoftwareWorkspace: false,
              scene: root.scene, showsWorkspaceFallback: root.showsWorkspaceFallback),
              "holding Fn on hardware must retain desktop mouse click-through")
        flags = .maskShift
        monitor.refresh()
        check(changes == [true, false] && !root.workspaceView.isHidden && root.surfaceView.isHidden
              && root.surfaceView.currentFrameContents == nil,
              "releasing Fn must immediately restore native glass Workspace without waiting for a capture")
        root.displayCapture(image: functionKeys)
        for _ in 0..<8 {
            flags = .maskSecondaryFn
            monitor.refresh()
            root.displayCapture(image: functionKeys)
            flags = []
            monitor.refresh()
        }
        try? await Task.sleep(for: .milliseconds(25))
        check(!root.workspaceView.isHidden && root.surfaceView.currentFrameContents == nil,
              "late processed Fn frames must not overwrite Workspace after rapid press and release")
        flags = .maskSecondaryFn
        monitor.refresh()
        root.apply(theme: .black)
        check(root.surfaceView.currentFrameContents === functionKeys && root.workspaceView.isHidden,
              "disabling glass while holding Fn must restore the captured raw function row")
        root.apply(theme: .glass)
        check(root.surfaceView.isHidden && !root.workspaceView.isHidden,
              "reenabling glass must retain native Workspace until the retained function row is composed")
        await waitForComposedKeys()
        check(!root.surfaceView.isHidden && root.workspaceView.isHidden,
              "reenabling glass while Fn is held must keep physical function keys visible")
        root.setWorkspaceFallbackVisible(true)
        check(root.surfaceView.isHidden && !root.workspaceView.isHidden,
              "software Workspace must retain its clickable native controls while Fn is held")
        root.setScene(.mirror)
        check(!root.surfaceView.isHidden && root.workspaceView.isHidden,
              "mirror mode must display physical capture regardless of Fn state")
        root.setWorkspaceFallbackVisible(false)
        root.setScene(.workspace)
        monitor.stop()
        monitor.refresh()
        check(!monitor.isMonitoring && !monitor.isPressed && !root.isFunctionKeyPressed
              && !root.workspaceView.isHidden,
              "stopping Fn monitoring must clear held state and ignore subsequent refreshes")
        monitor.start()
        check(monitor.isPressed && !root.workspaceView.isHidden,
              "starting monitoring with Fn held must prepare retained function capture behind native glass")
        await waitForComposedKeys()
        check(root.workspaceView.isHidden && !root.surfaceView.isHidden,
              "starting monitoring with Fn held must expose the retained function row once composition completes")
        root.displayCapture(error: .blackFrame)
        root.displayCapture(image: workspaceCapture)
        check(!root.hasCaptureDiagnostic && !root.showsFunctionKeyCapture
              && !root.workspaceView.isHidden && root.surfaceView.isHidden,
              "recovering through an old Workspace capture must restore native glass while waiting for Fn composition")
        root.displayCapture(image: functionKeys)
        check(!root.workspaceView.isHidden && root.surfaceView.isHidden,
              "recovering the Fn row must keep native glass visible until composition finishes")
        await waitForComposedKeys()
        check(root.showsFunctionKeyCapture && root.workspaceView.isHidden,
              "a composed function row must restore Fn display after a capture diagnostic")
        root.displayCapture(error: .blackFrame)
        flags = []
        monitor.refresh()
        check(root.hasCaptureDiagnostic && root.surfaceView.hasVisibleDiagnostic
              && !root.surfaceView.isHidden && root.workspaceView.isHidden,
              "Fn release must preserve visible capture diagnostics")
        monitor.stop()

        let blackWorkspace = TouchBarRootView(frame: root.frame)
        blackWorkspace.setScene(.workspace)
        blackWorkspace.displayCapture(image: workspaceCapture)
        blackWorkspace.setFunctionKeyPressed(true)
        blackWorkspace.displayCapture(image: functionKeys)
        check(blackWorkspace.surfaceView.currentFrameContents === functionKeys,
              "Fn tracking must preserve the existing raw capture behavior in black Workspace")
        blackWorkspace.apply(theme: .glass)
        check(!blackWorkspace.workspaceView.isHidden && blackWorkspace.surfaceView.isHidden,
              "enabling glass while Fn is already held must prepare the known function capture behind native glass")
        for _ in 0..<100 {
            if blackWorkspace.showsFunctionKeyCapture { break }
            try? await Task.sleep(for: .milliseconds(5))
        }
        check(blackWorkspace.showsFunctionKeyCapture && blackWorkspace.workspaceView.isHidden
              && blackWorkspace.surfaceView.currentFrameContents.map(rgba) == expectedKeys,
              "enabling glass with Fn held must display the composed retained function row without another capture")

        let returning = TouchBarRootView(frame: root.frame)
        returning.apply(theme: .glass)
        returning.displayCapture(image: mirrorCapture)
        returning.beginSceneTransitionCover()
        returning.setScene(.workspace)
        returning.displayCapture(image: workspaceCapture)
        returning.setFunctionKeyPressed(true)
        returning.displayCapture(image: functionKeys)
        returning.beginSceneTransitionCover()
        returning.setScene(.mirror)
        returning.setFunctionKeyPressed(false)
        returning.scheduleSceneTransitionCoverFade(settle: .milliseconds(1), fadeDuration: 0)
        try? await Task.sleep(for: .milliseconds(25))
        returning.displayCapture(image: functionKeys)
        check(!returning.isWaitingForMirrorCapture && returning.surfaceView.latestOriginalFrame === functionKeys,
              "returning to mirror while Fn is held must accept function keys instead of rejecting them as stale Workspace")
        return failures
    }

    @MainActor
    static func submitWhileDeliveryIsBlocked(_ pipeline: MirrorGlassFramePipeline, image: CGImage) {
        let finished = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            for sequence in 1...20 {
                pipeline.submit(image, token: MirrorGlassFrameToken(generation: 1, sequence: UInt64(sequence)))
                usleep(2_000)
            }
            finished.signal()
        }
        _ = finished.wait(timeout: .now() + 2)
        usleep(50_000)
    }

    @MainActor
    static func failures() async -> [String] {
        var failures: [String] = []
        func check(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message) }
        }
        for theme in [DesktopTheme.black, .glass] {
            for hover in [true, false] {
                for overlap in [true, false] {
                    check(DesktopThemePolicy.targetAlpha(theme: theme, isMouseInside: hover,
                                                         overlapsOtherApp: overlap)
                          == (theme == .glass ? 1 : (hover || overlap ? 0.3 : 1)),
                          "opacity must follow the effective theme for every hover/overlap combination")
                }
            }
        }
        let chrome = WorkspaceChromeButton()
        let blackBackground = chrome.layer?.backgroundColor
        chrome.desktopTheme = .glass
        check(chrome.layer?.backgroundColor != blackBackground, "desktop glass chrome must differ from hardware black chrome")
        chrome.highlight(true)
        check(chrome.layer?.borderWidth == 1, "desktop glass buttons must retain pressed feedback")
        chrome.desktopTheme = .black
        chrome.highlight(false)
        check(chrome.layer?.backgroundColor == blackBackground, "desktop black chrome must restore the original fill")

        let plate = QuotaPlateView(frame: NSRect(x: 0, y: 0, width: 500, height: 30))
        let metric = QuotaBarMetric(ratio: 0.5, caption: "周", valueText: "50%", isHighlighted: false)
        let group = QuotaProviderGroupState(provider: .codex, title: "Codex", fiveHour: metric,
            weekly: metric, reset: metric, tooltip: "fixture", isRecommended: false)
        let board = QuotaBoardState(groups: [group], recommendedProvider: nil)
        plate.display(board)
        let retainedGroup = plate.groupViews.first
        plate.display(board)
        plate.setDesktopTheme(.glass)
        plate.display(board)
        check(plate.groupViews.first === retainedGroup && retainedGroup?.desktopTheme == .glass,
              "unchanged quota content must retain its views and update theme without rebuilding during scene changes")
        var updatedGroup = group
        updatedGroup.isRecommended = true
        updatedGroup.weekly.valueText = "45%"
        plate.display(QuotaBoardState(groups: [updatedGroup], recommendedProvider: .codex))
        check(plate.groupViews.first === retainedGroup && retainedGroup?.state == updatedGroup
              && retainedGroup?.layer?.borderWidth == 1,
              "in-place quota updates must refresh values and recommendation chrome")
        let originalStyle = WorkspacePreferences.quotaMetricDisplayStyle
        WorkspacePreferences.quotaMetricDisplayStyle = originalStyle == .bars ? .percent : .bars
        plate.display(QuotaBoardState(groups: [updatedGroup], recommendedProvider: .codex))
        WorkspacePreferences.quotaMetricDisplayStyle = originalStyle
        check(plate.groupViews.first === retainedGroup,
              "display-style changes must update retained quota controls")
        plate.display(.empty)
        check(plate.groupViews.isEmpty && retainedGroup?.superview == nil,
              "removed providers must release their retained quota views")

        var scrollGroups = [group, group, group]
        for (index, provider) in [QuotaProviderID.codex, .cursor, .claude].enumerated() {
            scrollGroups[index].provider = provider
        }
        let scrollBoard = QuotaBoardState(groups: scrollGroups, recommendedProvider: nil)
        let scrollPlate = QuotaPlateView(frame: NSRect(x: 0, y: 0, width: 360, height: 30))
        scrollPlate.display(scrollBoard)
        var expectedScrollOffset: CGFloat = 0
        for theme in [DesktopTheme.black, .glass, .black] {
            scrollPlate.setDesktopTheme(theme)
            scrollPlate.layoutSubtreeIfNeeded()
            check(scrollPlate.needsHorizontalScroll && scrollPlate.contentWidth > scrollPlate.bounds.width
                  && scrollPlate.groupViews.allSatisfy {
                      abs($0.frame.width - WorkspaceTouchBarLayout.quotaGroupMinimumWidth) < 0.5
                  }, "theme changes must preserve readable card widths and quota overflow")
            guard let scrollView = scrollPlate.subviews.compactMap({ $0 as? NSScrollView }).first else {
                failures.append("quota plate must retain its native scroll view in every theme")
                continue
            }
            check(abs(scrollView.contentView.bounds.origin.x - expectedScrollOffset) < 0.5,
                  "switching theme must retain the current horizontal quota position")
            scrollView.contentView.scroll(to: NSPoint(x: 40, y: 0))
            scrollView.reflectScrolledClipView(scrollView.contentView)
            let offset = scrollView.contentView.bounds.origin.x
            expectedScrollOffset = offset
            check(abs(offset - 40) < 0.5 && !scrollView.hasHorizontalScroller,
                  "quota overflow must expose later cards without drawing scrollbars in every theme")
            scrollPlate.display(scrollBoard)
            scrollPlate.needsLayout = true
            scrollPlate.layoutSubtreeIfNeeded()
            check(abs(scrollView.contentView.bounds.origin.x - offset) < 0.5,
                  "unchanged quota refresh and layout must preserve the scroll position")
        }
        scrollPlate.setFrameSize(NSSize(width: 500, height: 30))
        scrollPlate.layoutSubtreeIfNeeded()
        check(!scrollPlate.needsHorizontalScroll && abs(scrollPlate.contentWidth - 500) < 0.5,
              "quota cards that fit must fill available width without overflow")

        let physicalPlate = QuotaPlateView(frame: NSRect(x: 0, y: 0, width: 360, height: 30))
        let desktopPlate = QuotaPlateView(frame: NSRect(x: 0, y: 0, width: 800, height: 30))
        physicalPlate.display(scrollBoard)
        desktopPlate.display(scrollBoard)
        desktopPlate.setDesktopTheme(.glass)
        desktopPlate.layoutSubtreeIfNeeded()
        var physicalScrollUpdates = 0
        physicalPlate.onScrollStateChanged = { state in
            physicalScrollUpdates += 1
            desktopPlate.mirrorScrollState(state)
        }
        physicalPlate.layoutSubtreeIfNeeded()
        check(physicalPlate.needsHorizontalScroll && desktopPlate.needsHorizontalScroll
              && abs(desktopPlate.contentWidth - physicalPlate.contentWidth * 800 / 360) < 0.5,
              "glass overflow must follow the physical viewport even when the desktop would fit every card")
        let desktopGroups = desktopPlate.groupViews
        let originalGlassFill = desktopGroups.first?.layer?.backgroundColor
        if let physicalScroll = physicalPlate.subviews.compactMap({ $0 as? NSScrollView }).first,
           let desktopScroll = desktopPlate.subviews.compactMap({ $0 as? NSScrollView }).first {
            for offset in [CGFloat(0), 20, 40, 80, 0] {
                physicalScroll.contentView.scroll(to: NSPoint(x: offset, y: 0))
                check(abs(desktopScroll.contentView.bounds.minX - offset * 800 / 360) < 0.5,
                      "physical clip bounds notifications must synchronously drive native glass scrolling")
            }
            physicalScroll.contentView.scroll(to: NSPoint(x: 40, y: 0))
            desktopPlate.setFrameSize(NSSize(width: 600, height: 30))
            desktopPlate.layoutSubtreeIfNeeded()
            check(abs(desktopScroll.contentView.bounds.minX - 40 * 600 / 360) < 0.5,
                  "resizing the desktop must preserve the physical scroll position")
            physicalPlate.setFrameSize(NSSize(width: 500, height: 30))
            physicalPlate.layoutSubtreeIfNeeded()
            check(!desktopPlate.needsHorizontalScroll && desktopScroll.contentView.bounds.minX == 0,
                  "physical viewport changes must update native glass overflow and clamp position")
        } else { check(false, "physical and native glass plates must retain scroll views") }
        check(physicalScrollUpdates >= 5 && desktopPlate.groupViews.count == desktopGroups.count
              && zip(desktopPlate.groupViews, desktopGroups).allSatisfy { $0 === $1 }
              && desktopPlate.groupViews.first?.layer?.backgroundColor == originalGlassFill,
              "Touch Bar scroll synchronization must reuse original native cards and glass styling")
        physicalPlate.onScrollStateChanged = nil
        desktopPlate.mirrorScrollState(nil)
        desktopPlate.layoutSubtreeIfNeeded()
        check(!desktopPlate.needsHorizontalScroll,
              "software fallback must restore independent native viewport layout")

        guard let image = fixture(), let result = MirrorGlassFrameRenderer().render(image) else {
            return failures + ["glass fixture must render"]
        }
        let original = rgba(image)
        let output = rgba(result)
        check(original.count == output.count, "glass composition must preserve dimensions and RGBA layout")
        if output.count == original.count {
            check(output[3] == 0 && output[0..<3].allSatisfy { $0 == 0 },
                  "border-connected background must become premultiplied transparent")
            let center = (3 * 9 + 4) * 4
            check(output[center + 3] == 255 && output[center] == 0,
                  "black foreground details enclosed by a visible shape must remain opaque")
            let button = (3 * 9 + 1) * 4
            check(Array(output[button..<(button + 4)]) == Array(original[button..<(button + 4)]),
                  "a dark button adjacent to the background must retain its original pixels")
            let ring = (3 * 9 + 2) * 4
            check(Array(output[ring..<(ring + 4)]) == Array(original[ring..<(ring + 4)]),
                  "visible foreground pixels must not be altered by background composition")
            check(rgba(image) == original, "glass renderer must not mutate the raw frame")
        }
        let stale = MirrorGlassFrameToken(generation: 1, sequence: 10)
        check(!stale.canDeliver(currentGeneration: 2, deliveredSequence: 0),
              "old theme/capture generation must never overwrite a new theme")
        check(!stale.canDeliver(currentGeneration: 1, deliveredSequence: 11),
              "out-of-order processed frames must be rejected")
        check(stale.canDeliver(currentGeneration: 1, deliveredSequence: 9),
              "current processed frame must be deliverable")

        if let chromeImage = chromeFixture() {
            let rawChrome = rgba(chromeImage)
            for appearance in [MirrorGlassAppearance.light, .dark] {
                if let rendered = MirrorGlassFrameRenderer().render(chromeImage, appearance: appearance) {
                    let bytes = rgba(rendered)
                    check(bytes[3] == 0, "recognized system gray chrome must reveal glass instead of retaining an opaque slab")
                    let glyph = (15 * 160 + 105) * 4
                    check(bytes[glyph] == appearance.foreground && bytes[glyph + 3] == 255,
                          "system monochrome glyphs must adapt to light and dark glass")
                    let edge = (15 * 160 + 99) * 4
                    check(bytes[edge + 3] > 0 && bytes[edge + 3] < 255
                          && bytes[edge] <= bytes[edge + 3],
                          "unmatted glyph edges must retain premultiplied antialias coverage")
                    let detail = (15 * 160 + 25) * 4
                    let brand = (15 * 160 + 15) * 4
                    check(Array(bytes[detail..<(detail + 4)]) == Array(rawChrome[detail..<(detail + 4)])
                          && Array(bytes[brand..<(brand + 4)]) == Array(rawChrome[brand..<(brand + 4)]),
                          "color artwork and its enclosed black details must survive chrome removal")
                } else { check(false, "system chrome fixture must render") }
            }
            check(rgba(chromeImage) == rawChrome, "system chrome composition must preserve the original capture")
        } else { check(false, "system chrome fixture must load") }

        var deliveries: [UInt64] = []
        let pipeline = MirrorGlassFramePipeline { _, token in deliveries.append(token.sequence) }
        submitWhileDeliveryIsBlocked(pipeline, image: image)
        for _ in 0..<100 {
            if deliveries.last == 20 { break }
            try? await Task.sleep(for: .milliseconds(5))
        }
        check(deliveries.last == 20 && deliveries.count <= 2,
              "a busy main actor must receive the latest processed frame without an unbounded callback backlog")

        let surface = TouchBarSurfaceView(frame: NSRect(x: 0, y: 0, width: 100, height: 30))
        surface.display(image: image)
        surface.apply(theme: .glass)
        for _ in 0..<100 {
            if let displayed = surface.currentFrameContents, rgba(displayed).first == 0,
               rgba(displayed).dropFirst(3).first == 0 { break }
            try? await Task.sleep(for: .milliseconds(5))
        }
        let composed = surface.currentFrameContents
        check(composed.map { rgba($0)[3] == 0 } == true,
              "enabling glass must process the retained frame without a new capture callback")
        surface.apply(theme: .black)
        check(surface.currentFrameContents.map { rgba($0) == original } == true,
              "disabling glass must immediately restore the raw retained frame")
        surface.apply(theme: .glass)
        surface.apply(theme: .black)
        try? await Task.sleep(for: .milliseconds(25))
        check(surface.currentFrameContents.map { rgba($0) == original } == true,
              "late glass completion must not replace a restored raw frame")
        surface.apply(theme: .glass)
        surface.clearFrame()
        try? await Task.sleep(for: .milliseconds(25))
        check(surface.currentFrameContents == nil && surface.latestOriginalFrame == nil,
              "clearing a capture session must invalidate pending processed frames")
        surface.setRenderingEnabled(false)
        surface.display(image: image)
        try? await Task.sleep(for: .milliseconds(25))
        check(surface.currentFrameContents == nil && surface.latestOriginalFrame != nil,
              "a hidden hardware capture must retain raw input without spending work on glass composition")
        surface.setRenderingEnabled(true)
        for _ in 0..<100 {
            if surface.currentFrameContents != nil { break }
            try? await Task.sleep(for: .milliseconds(5))
        }
        check(surface.currentFrameContents.map { rgba($0)[3] == 0 } == true,
              "restoring the mirror must process its latest retained raw frame")

        let root = TouchBarRootView(frame: NSRect(x: 0, y: 0, width: 500, height: 35))
        root.surfaceView.display(image: image)
        root.beginSceneTransitionCover()
        root.apply(theme: .glass)
        root.setScene(.workspace)
        root.setWorkspaceFallbackVisible(true)
        check(root.layer?.backgroundColor == NSColor.clear.cgColor
              && root.workspaceView.layer?.backgroundColor == NSColor.clear.cgColor,
              "desktop glass must not be covered by root or Workspace black fills")
        root.apply(theme: .black)
        check(root.layer?.backgroundColor == NSColor.black.cgColor
              && root.surfaceView.desktopTheme == .black,
              "switching theme during a cover must restore black consistently")
        check(root.frame.size == NSSize(width: 500, height: 35)
              && root.scene == .workspace && root.showsWorkspaceFallback,
              "theme updates must preserve frame and scene state")
        root.setWorkspaceFallbackVisible(false)
        root.apply(theme: .glass)
        check(!root.workspaceView.isHidden && root.surfaceView.isHidden && !root.showsWorkspaceFallback,
              "hardware glass Workspace must retain original native chrome with physical input")
        check(MirrorClickThroughPolicy.ignoresMouseEvents(usesSoftwareWorkspace: false,
              scene: root.scene, showsWorkspaceFallback: root.showsWorkspaceFallback),
              "native hardware glass Workspace must retain mouse click-through")
        root.displayCapture(image: image)
        try? await Task.sleep(for: .milliseconds(25))
        check(root.surfaceView.latestOriginalFrame === image && root.surfaceView.currentFrameContents == nil,
              "hardware glass Workspace must retain raw captures without processing pixels for desktop scrolling")
        root.apply(theme: .black)
        check(root.workspaceView.isHidden && !root.surfaceView.isHidden
              && root.surfaceView.currentFrameContents === image,
              "disabling glass must restore the latest raw hardware capture")
        root.apply(theme: .glass)
        check(!root.workspaceView.isHidden && root.surfaceView.isHidden,
              "reenabling glass must restore the original native chrome")
        root.displayCapture(error: .blackFrame)
        check(root.hasCaptureDiagnostic && !root.surfaceView.isHidden
              && root.surfaceView.hasVisibleDiagnostic && root.workspaceView.isHidden
              && root.surfaceView.currentFrameContents == nil,
              "a hardware capture failure must remain visible on glass Workspace")
        root.apply(theme: .black)
        root.apply(theme: .glass)
        check(root.surfaceView.hasVisibleDiagnostic && root.surfaceView.currentFrameContents == nil,
              "theme reprocessing must preserve a current capture diagnostic")
        root.displayCapture(image: image)
        check(!root.hasCaptureDiagnostic && root.surfaceView.isHidden && !root.workspaceView.isHidden,
              "a healthy raw frame must clear the diagnostic and restore native glass Workspace")
        let cover = root.subviews.compactMap { $0 as? TouchBarSurfaceView }
            .first { $0 !== root.surfaceView }
        check(cover?.isHidden == true && cover?.currentFrameContents == nil,
              "glass must not composite the previous scene over native Workspace")
        for index in 0..<12 {
            root.apply(theme: index.isMultiple(of: 2) ? .glass : .black)
            check(cover?.isHidden == true,
                  "theme changes must never revive a discarded scene cover")
        }
        root.apply(theme: .black)
        root.beginSceneTransitionCover()
        check(cover?.isHidden == false, "black transitions must keep the original cover")
        root.scheduleSceneTransitionCoverFade(settle: .zero, fadeDuration: 0)
        try? await Task.sleep(for: .milliseconds(25))
        check(cover?.isHidden == true && cover?.latestOriginalFrame == nil,
              "a completed black transition must remove its snapshot and pending frame")

        let switching = TouchBarRootView(frame: NSRect(x: 0, y: 0, width: 500, height: 35))
        switching.apply(theme: .glass)
        switching.displayCapture(image: image)
        for _ in 0..<100 {
            if switching.surfaceView.currentFrameContents != nil { break }
            try? await Task.sleep(for: .milliseconds(5))
        }
        let retained = switching.surfaceView.currentFrameContents.map(rgba)
        let switchingCover = switching.subviews.compactMap { $0 as? TouchBarSurfaceView }
            .first { $0 !== switching.surfaceView }
        if let workspaceCapture = chromeFixture() {
            check(TouchBarFrameSignature(image: image)?.resembles(TouchBarFrameSignature(image: workspaceCapture)!) == false,
                  "mirror and Workspace fixtures must have distinct capture signatures")
            for _ in 0..<20 {
                switching.beginSceneTransitionCover()
                switching.setScene(.workspace)
                switching.displayCapture(image: workspaceCapture)
                check(switchingCover?.isHidden == true && !switching.workspaceView.isHidden
                      && switching.surfaceView.isHidden
                      && switching.surfaceView.latestOriginalFrame === workspaceCapture,
                      "entering glass Workspace must immediately show native chrome while retaining raw capture")
                switching.beginSceneTransitionCover()
                switching.setScene(.mirror)
                check(switching.isWaitingForMirrorCapture
                      && switching.surfaceView.currentFrameContents.map(rgba) == retained,
                      "returning must immediately restore the last composed mirror without a Workspace raw frame")
                switching.displayCapture(image: workspaceCapture)
                check(switching.surfaceView.currentFrameContents.map(rgba) == retained,
                      "rebuilding hardware must not overwrite the retained mirror")
                switching.scheduleSceneTransitionCoverFade(settle: .milliseconds(10), fadeDuration: 0)
                try? await Task.sleep(for: .milliseconds(20))
                switching.displayCapture(image: workspaceCapture)
                check(switching.surfaceView.latestOriginalFrame !== workspaceCapture,
                      "late Workspace frames must be rejected after settle until a stable mirror arrives")
                switching.displayCapture(image: image)
                check(!switching.isWaitingForMirrorCapture && switching.surfaceView.latestOriginalFrame === image,
                      "a stable mirror must replace retained content after the hardware settles")
                switching.displayCapture(image: workspaceCapture)
                check(switching.surfaceView.latestOriginalFrame === image,
                      "reordered Workspace frames must remain excluded during the bounded return guard")
                for _ in 0..<100 {
                    if switching.surfaceView.currentFrameContents != nil { break }
                    try? await Task.sleep(for: .milliseconds(5))
                }
            }
            switching.beginSceneTransitionCover()
            switching.setScene(.workspace)
            switching.displayCapture(image: workspaceCapture)
            switching.beginSceneTransitionCover()
            switching.setScene(.mirror)
            switching.scheduleSceneTransitionCoverFade(settle: .milliseconds(30), fadeDuration: 0)
            switching.beginSceneTransitionCover()
            switching.setScene(.workspace)
            try? await Task.sleep(for: .milliseconds(40))
            check(switching.scene == .workspace && !switching.workspaceView.isHidden
                  && switching.surfaceView.isHidden
                  && !switching.isWaitingForMirrorCapture && switchingCover?.isHidden == true,
                  "rapid reversal must cancel old settle work without reviving mirror icons")
        }
        let hoverController = TouchBarHoverOpacityController(window: nil)
        hoverController.setTheme(.glass)
        hoverController.start()
        check(!hoverController.hasActiveObservers,
              "glass theme must not install fading mouse observers or overlap timer")
        hoverController.stop()
        failures.append(contentsOf: await functionKeyFailures())
        return failures
    }
}
