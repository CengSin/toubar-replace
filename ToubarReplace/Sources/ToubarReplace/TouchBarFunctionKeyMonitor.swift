import CoreGraphics
import Foundation

@MainActor
final class MainThreadTicker: NSObject {
    private let action: () -> Void
    private var timer: Timer?

    init(interval: TimeInterval, tolerance: TimeInterval = 0, action: @escaping () -> Void) {
        self.action = action
        super.init()
        let timer = Timer(
            timeInterval: interval,
            target: self,
            selector: #selector(tick),
            userInfo: nil,
            repeats: true
        )
        timer.tolerance = tolerance
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func invalidate() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func tick() {
        action()
    }
}

@MainActor
final class TouchBarFunctionKeyMonitor {
    private let readFlags: () -> CGEventFlags
    private let onChange: (Bool) -> Void
    private var timer: MainThreadTicker?
    private(set) var isPressed = false
    var onStateChanged: ((Bool) -> Void)?

    var isMonitoring: Bool { timer != nil }

    init(
        readFlags: @escaping () -> CGEventFlags = {
            CGEventSource.flagsState(.hidSystemState)
        },
        onChange: @escaping (Bool) -> Void
    ) {
        self.readFlags = readFlags
        self.onChange = onChange
    }

    func start() {
        if timer == nil {
            timer = MainThreadTicker(interval: 1.0 / 30, tolerance: 0.005) { [weak self] in
                self?.refresh()
            }
        }
        refresh()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        update(isPressed: false)
    }

    func refresh() {
        guard isMonitoring else { return }
        update(isPressed: readFlags().contains(.maskSecondaryFn))
    }

    private func update(isPressed: Bool) {
        guard self.isPressed != isPressed else { return }
        self.isPressed = isPressed
        onChange(isPressed)
        onStateChanged?(isPressed)
    }
}
