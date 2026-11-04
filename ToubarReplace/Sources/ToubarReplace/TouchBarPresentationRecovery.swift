import CoreGraphics
import Foundation

@MainActor
final class TouchBarPresentationRecovery {
    private let delay: Duration
    private let isFunctionKeyPressed: () -> Bool
    private let reconcile: () -> Bool
    private var task: Task<Void, Never>?
    private var isReconciling = false

    init(
        delay: Duration = .milliseconds(350),
        isFunctionKeyPressed: @escaping () -> Bool = {
            CGEventSource.flagsState(.hidSystemState).contains(.maskSecondaryFn)
        },
        reconcile: @escaping () -> Bool
    ) {
        self.delay = delay
        self.isFunctionKeyPressed = isFunctionKeyPressed
        self.reconcile = reconcile
    }

    func schedule() {
        guard !isReconciling else { return }
        cancel()
        task = Task { @MainActor [weak self] in
            var attempts = 0
            while !Task.isCancelled {
                guard let delay = self?.delay else { return }
                do { try await Task.sleep(for: delay) }
                catch { return }
                guard !Task.isCancelled, let self else { return }
                if self.isFunctionKeyPressed() { continue }
                self.isReconciling = true
                let finished = self.reconcile()
                self.isReconciling = false
                if finished { return }
                attempts += 1
                if attempts >= 3 { return }
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
