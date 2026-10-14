import AppKit
import TouchBarPrivateAPI

struct DesktopSpaceSnapshot: Equatable {
    enum Kind {
        case desktop
        case fullScreen
    }

    let displayID: UInt32
    let spaceID: UInt64
    let kind: Kind

    init?(displayID: UInt32, spaceID: UInt64, spaceType: Int32) {
        guard spaceID != 0 else { return nil }
        switch spaceType {
        case 0: kind = .desktop
        case 4: kind = .fullScreen
        default: return nil
        }
        self.displayID = displayID
        self.spaceID = spaceID
    }
}

struct DesktopSpaceVisibilityPolicy {
    private(set) var lastSnapshot: DesktopSpaceSnapshot?

    mutating func expansion(for snapshot: DesktopSpaceSnapshot?) -> Bool? {
        guard let snapshot, snapshot != lastSnapshot else { return nil }
        lastSnapshot = snapshot
        return snapshot.kind == .desktop
    }
}

@MainActor
final class DesktopSpaceVisibilityMonitor {
    private weak var window: NSWindow?
    private let onExpansionChanged: (Bool) -> Void
    private var policy = DesktopSpaceVisibilityPolicy()
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    private var refreshTask: Task<Void, Never>?
    private var isRunning = false

    init(window: NSWindow, onExpansionChanged: @escaping (Bool) -> Void) {
        self.window = window
        self.onExpansionChanged = onExpansionChanged
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.activeSpaceDidChangeNotification,
                     NSWorkspace.didActivateApplicationNotification,
                     NSWorkspace.sessionDidBecomeActiveNotification,
                     NSWorkspace.screensDidWakeNotification,
                     NSWorkspace.didWakeNotification] {
            observe(name, center: center)
        }
        observe(NSApplication.didChangeScreenParametersNotification, center: .default)
        refresh()
    }

    func stop() {
        isRunning = false
        refreshTask?.cancel()
        refreshTask = nil
        for (center, observer) in observers { center.removeObserver(observer) }
        observers.removeAll()
        policy = DesktopSpaceVisibilityPolicy()
    }

    func refresh() {
        guard isRunning else { return }
        refreshTask?.cancel()
        updateVisibility()
        refreshTask = Task { @MainActor [weak self] in
            for delay in [150, 300, 450, 600] {
                do { try await Task.sleep(for: .milliseconds(delay)) }
                catch { return }
                guard let self, self.isRunning, !Task.isCancelled else { return }
                self.updateVisibility()
            }
        }
    }

    private func observe(_ name: Notification.Name, center: NotificationCenter) {
        let observer = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
        observers.append((center, observer))
    }

    private func updateVisibility() {
        guard let window else { return }
        let screen = NSScreen.screens.max { first, second in
            let firstIntersection = first.frame.intersection(window.frame)
            let secondIntersection = second.frame.intersection(window.frame)
            return firstIntersection.width * firstIntersection.height
                < secondIntersection.width * secondIntersection.height
        }
        guard let screen,
              let display = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        else { return }
        var spaceID: UInt64 = 0
        var spaceType: Int32 = -1
        guard TBRGetCurrentSpaceForDisplay(display.uint32Value, &spaceID, &spaceType) else { return }
        let snapshot = DesktopSpaceSnapshot(displayID: display.uint32Value, spaceID: spaceID, spaceType: spaceType)
        if let expanded = policy.expansion(for: snapshot) { onExpansionChanged(expanded) }
    }
}
