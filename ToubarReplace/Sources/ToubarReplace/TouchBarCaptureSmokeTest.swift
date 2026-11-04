import CoreGraphics
import Foundation

private final class SmokeTouchBarDisplayStream: TouchBarDisplayStream, @unchecked Sendable {
    private let identifier: Int
    private let probe: SmokeTouchBarCaptureProbe

    var stopBehavior: TouchBarDisplayStreamStopBehavior { probe.stopBehavior }

    init(identifier: Int, probe: SmokeTouchBarCaptureProbe) {
        self.identifier = identifier
        self.probe = probe
    }

    deinit { probe.record("release:\(identifier)") }

    func start() -> CGError { probe.startStream(identifier) }
    func stop() -> CGError { probe.stopStream(identifier) }
}

private final class SmokeTouchBarCaptureProbe: @unchecked Sendable {
    private struct StreamRecord {
        weak var stream: SmokeTouchBarDisplayStream?
        let queue: DispatchQueue
        let onEvent: TouchBarCaptureDependencies.EventHandler
    }

    private struct ScheduledWork {
        let queue: DispatchQueue
        let seconds: Int
        let work: @Sendable () -> Void
    }

    private let lock = NSLock()
    private let queue = DispatchQueue(label: "com.toubarreplace.capture-smoke-test")
    private var records: [Int: StreamRecord] = [:]
    private var scheduled: [ScheduledWork] = []
    private var events: [String] = []
    private var errors: [TouchBarCaptureError] = []
    private var unavailableCreations: Int
    private var startResults: [CGError]
    private var stopResults: [CGError]
    let stopBehavior: TouchBarDisplayStreamStopBehavior

    init(unavailableCreations: Int = 0, startResults: [CGError] = [], stopResults: [CGError] = [],
         stopBehavior: TouchBarDisplayStreamStopBehavior = .awaitStoppedEvent) {
        self.unavailableCreations = unavailableCreations
        self.startResults = startResults
        self.stopResults = stopResults
        self.stopBehavior = stopBehavior
    }

    var creationCount: Int { lock.withLock { records.count } }
    var receivedErrors: [TouchBarCaptureError] { lock.withLock { errors } }

    func count(_ event: String) -> Int {
        lock.withLock { events.filter { $0 == event }.count }
    }

    func isRetained(_ identifier: Int) -> Bool {
        lock.withLock { records[identifier]?.stream != nil }
    }

    func record(_ event: String) { lock.withLock { events.append(event) } }

    func startStream(_ identifier: Int) -> CGError {
        lock.withLock {
            events.append("start:\(identifier)")
            return startResults.isEmpty ? .success : startResults.removeFirst()
        }
    }

    func stopStream(_ identifier: Int) -> CGError {
        lock.withLock {
            events.append("stop:\(identifier)")
            return stopResults.isEmpty ? .success : stopResults.removeFirst()
        }
    }

    func makeCapture() -> TouchBarCapture {
        TouchBarCapture(
            onFrame: { [self] _ in record("frame") },
            onNotice: { [self] _ in record("notice") },
            onError: { [self] error in lock.withLock { errors.append(error) } },
            dependencies: TouchBarCaptureDependencies(
                makeStream: { [self] queue, onEvent in
                    lock.withLock {
                        if unavailableCreations > 0 {
                            unavailableCreations -= 1
                            return nil
                        }
                        let identifier = records.count + 1
                        let stream = SmokeTouchBarDisplayStream(identifier: identifier, probe: self)
                        records[identifier] = StreamRecord(stream: stream, queue: queue, onEvent: onEvent)
                        return stream
                    }
                },
                schedule: { [self] queue, delay, work in
                    guard case let .seconds(seconds) = delay else { return }
                    lock.withLock { scheduled.append(ScheduledWork(queue: queue, seconds: seconds, work: work)) }
                }
            ),
            workerQueue: queue
        )
    }

    func emit(_ status: CGDisplayStreamFrameStatus, from identifier: Int) {
        guard let record = lock.withLock({ records[identifier] }) else { return }
        record.queue.async { record.onEvent(status, nil) }
    }

    @discardableResult
    func fireTimer(seconds: Int) -> Bool {
        let timer = lock.withLock { () -> ScheduledWork? in
            guard let index = scheduled.firstIndex(where: { $0.seconds == seconds }) else { return nil }
            return scheduled.remove(at: index)
        }
        guard let timer else { return false }
        timer.queue.async(execute: timer.work)
        return true
    }

    func flush() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { continuation.resume() }
        }
    }
}

enum TouchBarCaptureSmokeTest {
    static func failures() async -> [String] {
        var failures: [String] = []

        func expect(_ condition: Bool, _ message: String) {
            if !condition { failures.append(message) }
        }

        var stopSignals = TouchBarStopSignalTracker()
        expect(!stopSignals.consume(status: .frameComplete, displayTime: 0, hasSurface: false),
               "an empty frame without a successful stop must remain a capture diagnostic")
        stopSignals.recordSuccessfulStop()
        expect(!stopSignals.consume(status: .frameComplete, displayTime: 10, hasSurface: false)
               && !stopSignals.consume(status: .frameComplete, displayTime: 0, hasSurface: true),
               "stop-signal filtering must preserve invalid timestamped frames and real surfaces")
        expect(stopSignals.consume(status: .frameComplete, displayTime: 0, hasSurface: false)
               && !stopSignals.consume(status: .frameComplete, displayTime: 0, hasSurface: false),
               "each successful DFR stop must consume exactly one zero-time empty stop notification")

        do {
            let probe = SmokeTouchBarCaptureProbe()
            let capture = probe.makeCapture()
            capture.start()
            capture.start()
            await probe.flush()
            expect(probe.creationCount == 1 && probe.count("start:1") == 1,
                   "capture start must be idempotent")

            capture.pause()
            capture.pause()
            await probe.flush()
            expect(probe.isRetained(1) && probe.count("stop:1") == 1,
                   "pause must retain the stopping stream")

            for _ in 0..<100 {
                capture.start()
                capture.pause()
            }
            capture.start()
            await probe.flush()
            expect(probe.creationCount == 1 && probe.isRetained(1) && probe.count("stop:1") == 1,
                   "rapid pause and resume must wait for stopped without creating overlapping streams")
            probe.emit(.frameComplete, from: 1)
            await probe.flush()
            expect(probe.receivedErrors.isEmpty,
                   "frames from a stopping stream must be discarded")

            probe.emit(.stopped, from: 1)
            await probe.flush()
            expect(!probe.isRetained(1) && probe.count("release:1") == 1
                   && probe.creationCount == 2 && probe.count("start:2") == 1,
                   "stopped must release the old stream and honor the latest resume request")

            probe.emit(.stopped, from: 1)
            probe.emit(.frameIdle, from: 1)
            expect(probe.fireTimer(seconds: 5), "the first stream must have a startup health check")
            await probe.flush()
            expect(probe.creationCount == 2 && probe.isRetained(2) && probe.count("stop:2") == 0,
                   "old stopped callbacks and startup checks must leave the replacement stream intact")

            expect(probe.fireTimer(seconds: 5), "the replacement stream must have its own startup check")
            await probe.flush()
            expect(probe.receivedErrors == [.streamStartupTimedOut] && probe.count("stop:2") == 1,
                   "stale idle frames must not satisfy the replacement stream startup check")
            expect(probe.fireTimer(seconds: 1), "a startup timeout must schedule a retry")
            await probe.flush()
            expect(probe.creationCount == 2 && probe.isRetained(2),
                   "a retry must retain a stream whose stopped acknowledgement is delayed")
            probe.emit(.stopped, from: 2)
            await probe.flush()
            expect(probe.creationCount == 3 && !probe.isRetained(2) && probe.isRetained(3),
                   "an elapsed retry must resume once the old stream confirms stopped")

            capture.stop()
            await probe.flush()
            expect(probe.isRetained(3),
                   "full stop must retain the stream while awaiting stopped")
            probe.emit(.stopped, from: 3)
            await probe.flush()
            expect(!probe.isRetained(3) && probe.creationCount == 3,
                   "full stop must release its stream without reconnecting")
        }

        do {
            let probe = SmokeTouchBarCaptureProbe()
            let capture = probe.makeCapture()
            capture.start()
            await probe.flush()
            probe.emit(.frameIdle, from: 1)
            probe.fireTimer(seconds: 5)
            await probe.flush()
            expect(probe.count("stop:1") == 0 && probe.receivedErrors.isEmpty,
                   "an idle but healthy stream must not be restarted by its startup check")

            probe.emit(.stopped, from: 1)
            probe.emit(.stopped, from: 1)
            await probe.flush()
            expect(!probe.isRetained(1) && probe.receivedErrors == [.streamStopped]
                   && probe.creationCount == 1,
                   "an unexpected stop must release its stream and schedule a single reconnect")
            capture.stop()
            capture.start()
            await probe.flush()
            probe.fireTimer(seconds: 1)
            await probe.flush()
            expect(probe.creationCount == 2 && probe.count("start:2") == 1 && probe.isRetained(2),
                   "a retry from an earlier capture session must not create or replace a stream")
            capture.stop()
            await probe.flush()
            probe.emit(.stopped, from: 2)
            await probe.flush()
        }

        do {
            let probe = SmokeTouchBarCaptureProbe()
            let capture = probe.makeCapture()
            capture.start()
            await probe.flush()
            probe.emit(.stopped, from: 1)
            await probe.flush()
            probe.fireTimer(seconds: 1)
            await probe.flush()
            expect(probe.creationCount == 2 && probe.isRetained(2),
                   "an unexpected stop must reconnect within the same capture session")

            probe.emit(.stopped, from: 1)
            probe.emit(.frameIdle, from: 1)
            probe.emit(.frameComplete, from: 1)
            probe.fireTimer(seconds: 5)
            await probe.flush()
            expect(probe.creationCount == 2 && probe.isRetained(2) && probe.count("stop:2") == 0
                   && probe.receivedErrors == [.streamStopped],
                   "callbacks and timeouts from a previous stream in the same session must be discarded")
            probe.fireTimer(seconds: 5)
            await probe.flush()
            expect(probe.count("stop:2") == 1 && probe.receivedErrors.last == .streamStartupTimedOut,
                   "late idle callbacks must not hide a new stream startup timeout in the same session")
            probe.emit(.stopped, from: 2)
            await probe.flush()
            expect(probe.creationCount == 2 && !probe.isRetained(2),
                   "an acknowledged timeout stop must honor the retry delay")
            probe.fireTimer(seconds: 1)
            await probe.flush()
            expect(probe.creationCount == 3 && probe.isRetained(3),
                   "a timed-out stream must reconnect after both stop acknowledgement and retry delay")
            capture.stop()
            await probe.flush()
            probe.emit(.stopped, from: 3)
            await probe.flush()
        }

        do {
            let probe = SmokeTouchBarCaptureProbe(unavailableCreations: 1, startResults: [.failure])
            let capture = probe.makeCapture()
            capture.start()
            await probe.flush()
            expect(probe.creationCount == 0 && probe.receivedErrors == [.streamUnavailable],
                   "stream creation failure must report the error and remain retryable")
            capture.pause()
            await probe.flush()
            probe.fireTimer(seconds: 1)
            await probe.flush()
            expect(probe.creationCount == 0, "pause must cancel a pending creation retry")

            capture.start()
            await probe.flush()
            expect(probe.creationCount == 1 && !probe.isRetained(1) && probe.count("release:1") == 1
                   && probe.receivedErrors.last == .streamStartFailed(CGError.failure.rawValue),
                   "a stream that failed to start must release without waiting for stopped")
            probe.fireTimer(seconds: 1)
            await probe.flush()
            expect(probe.creationCount == 2 && probe.isRetained(2),
                   "a failed start must retry with a new stream")
            capture.stop()
            await probe.flush()
            probe.emit(.stopped, from: 2)
            await probe.flush()
        }

        do {
            let probe = SmokeTouchBarCaptureProbe(stopResults: [.failure, .success])
            let capture = probe.makeCapture()
            capture.start()
            await probe.flush()
            capture.restart()
            capture.restart()
            await probe.flush()
            expect(probe.creationCount == 1 && probe.isRetained(1) && probe.count("stop:1") == 1
                   && probe.receivedErrors == [.streamStopFailed(CGError.failure.rawValue)],
                   "a failed stop must retain the stream and coalesce restart requests")
            probe.fireTimer(seconds: 1)
            await probe.flush()
            expect(probe.count("stop:1") == 2 && probe.creationCount == 1 && probe.isRetained(1),
                   "a failed stop must retry stopping the same stream before replacement")
            probe.emit(.stopped, from: 1)
            await probe.flush()
            expect(probe.creationCount == 2 && !probe.isRetained(1) && probe.isRetained(2),
                   "a successful stop retry must allow the latest requested restart")
            capture.stop()
            await probe.flush()
            probe.emit(.stopped, from: 2)
            await probe.flush()
        }

        do {
            let probe = SmokeTouchBarCaptureProbe(stopBehavior: .retainForReuse)
            let capture = probe.makeCapture()
            capture.start()
            await probe.flush()
            for _ in 0..<100 {
                capture.pause()
                capture.start()
            }
            await probe.flush()
            expect(probe.creationCount == 1 && probe.isRetained(1)
                   && probe.count("start:1") == 101 && probe.count("stop:1") == 100,
                   "DFR streams without stopped notifications must reuse one object through 100 pause cycles")
            probe.fireTimer(seconds: 5)
            probe.emit(.frameIdle, from: 1)
            await probe.flush()
            expect(probe.count("stop:1") == 100 && probe.receivedErrors.isEmpty,
                   "a resumed DFR stream must accept current activity and ignore an old startup timer")
            capture.stop()
            await probe.flush()
            expect(probe.isRetained(1) && probe.count("stop:1") == 101,
                   "stopping DFR capture must suspend and retain its object without writing Touch Bar status")
            capture.shutdown()
            await probe.flush()
            expect(probe.isRetained(1) && probe.count("stop:1") == 102,
                   "shutdown must physically stop a suspended DFR stream and await its acknowledgement")
            probe.emit(.stopped, from: 1)
            await probe.flush()
            expect(!probe.isRetained(1) && probe.count("release:1") == 1,
                   "a retained DFR stream must release when a real stopped notification arrives")
            withExtendedLifetime(capture) {}
        }

        do {
            let probe = SmokeTouchBarCaptureProbe(startResults: [.success, .failure, .success],
                                                 stopResults: [.failure, .success],
                                                 stopBehavior: .retainForReuse)
            let capture = probe.makeCapture()
            capture.start()
            await probe.flush()
            capture.pause()
            capture.start()
            await probe.flush()
            probe.fireTimer(seconds: 1)
            await probe.flush()
            expect(probe.creationCount == 1 && probe.isRetained(1)
                   && probe.receivedErrors == [.streamStopFailed(CGError.failure.rawValue),
                                               .streamStartFailed(CGError.failure.rawValue)],
                   "DFR stop and resume failures must preserve the same owned stream")
            probe.fireTimer(seconds: 1)
            await probe.flush()
            expect(probe.creationCount == 1 && probe.count("start:1") == 3 && probe.isRetained(1),
                   "a failed DFR resume must retry without allocating another display stream")
            capture.stop()
            await probe.flush()
            probe.emit(.stopped, from: 1)
            await probe.flush()
            withExtendedLifetime(capture) {}
        }

        return failures
    }
}
