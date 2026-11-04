import Foundation

@MainActor
enum TouchBarPresentationRecoverySmokeTest {
    static func failures() async -> [String] {
        var failures: [String] = []
        var pressed = true
        var attached = false
        var checks = 0
        var repairs = 0
        let recovery = TouchBarPresentationRecovery(
            delay: .milliseconds(1),
            isFunctionKeyPressed: { pressed }
        ) {
            checks += 1
            if !attached { repairs += 1; attached = true }
            return attached
        }

        func waitForChecks(_ count: Int) async {
            for _ in 0..<100 {
                if checks >= count { return }
                try? await Task.sleep(for: .milliseconds(2))
            }
        }

        recovery.schedule()
        try? await Task.sleep(for: .milliseconds(15))
        if checks != 0 { failures.append("held Fn must defer all modal recovery") }
        pressed = false
        await waitForChecks(1)
        if checks != 1 || repairs != 1 {
            failures.append("Fn release must recover a modal that never attached")
        }
        recovery.schedule()
        await waitForChecks(2)
        if repairs != 1 { failures.append("an attached modal must survive application activation untouched") }

        for cycle in 1...100 {
            attached = false
            pressed = true
            recovery.schedule()
            recovery.schedule()
            pressed = false
            await waitForChecks(cycle + 2)
        }
        recovery.cancel()
        if checks != 102 || repairs != 101 {
            failures.append("100 activation and Fn cycles must each recover exactly once")
        }

        attached = false
        recovery.schedule()
        recovery.cancel()
        try? await Task.sleep(for: .milliseconds(15))
        if checks != 102 { failures.append("dismissal must cancel pending modal recovery") }

        var failedAttempts = 0
        var boundedRecovery: TouchBarPresentationRecovery?
        boundedRecovery = TouchBarPresentationRecovery(
            delay: .milliseconds(1), isFunctionKeyPressed: { false }
        ) {
            failedAttempts += 1
            boundedRecovery?.schedule()
            return false
        }
        boundedRecovery?.schedule()
        for _ in 0..<100 {
            if failedAttempts >= 3 { break }
            try? await Task.sleep(for: .milliseconds(2))
        }
        try? await Task.sleep(for: .milliseconds(15))
        boundedRecovery?.cancel()
        if failedAttempts != 3 {
            failures.append("failed presentation must stop after three attempts even with reentrant callbacks")
        }
        boundedRecovery = nil
        return failures
    }
}
