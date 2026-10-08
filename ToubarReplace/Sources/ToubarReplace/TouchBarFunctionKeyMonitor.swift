import CoreGraphics
import Foundation

@MainActor
final class TouchBarFunctionKeyMonitor {
    private let readFlags: () -> CGEventFlags
    private let onChange: (Bool) -> Void
    private var timer: Timer?
    private(set) var isPressed = false

    var isMonitoring: Bool { timer != nil }

    init(
        readFlags: @escaping () -> CGEventFlags = {
            CGEventSource.flagsState(.combinedSessionState)
        },
        onChange: @escaping (Bool) -> Void
    ) {
        self.readFlags = readFlags
        self.onChange = onChange
    }

    func start() {
        if timer == nil {
            let timer = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            timer.tolerance = 0.005
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
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
    }
}
