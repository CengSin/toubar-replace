import CoreGraphics
import Foundation

private final class MeasuredDisplayStream: TouchBarDisplayStream, @unchecked Sendable {
    private let stream: any TouchBarDisplayStream
    private let probe: CaptureLifecycleProbe
    private var lastNativeStarts = 0

    var stopBehavior: TouchBarDisplayStreamStopBehavior { stream.stopBehavior }

    init(stream: any TouchBarDisplayStream, probe: CaptureLifecycleProbe) {
        self.stream = stream
        self.probe = probe
    }

    func start() -> CGError {
        let result = stream.start()
        if result == .success {
            probe.didStart(nativeStarts: stream.nativeStartCount - lastNativeStarts)
            lastNativeStarts = stream.nativeStartCount
        }
        return result
    }

    func stop() -> CGError {
        let result = stream.stop()
        if result == .success { probe.didStop() }
        return result
    }

    func shutdown() -> CGError {
        let result = stream.shutdown()
        if result == .success { probe.didShutdown() }
        return result
    }
}

private final class WeakMeasuredStream {
    weak var value: MeasuredDisplayStream?
    init(_ value: MeasuredDisplayStream) { self.value = value }
}

private final class CaptureLifecycleProbe: @unchecked Sendable {
    let queue = DispatchQueue(label: "com.toubarreplace.capture-lifecycle-verifier")
    private let lock = NSLock()
    private var handles: [WeakMeasuredStream] = []
    private var starts = 0
    private var stops = 0
    private var nativeStarts = 0
    private var shutdowns = 0
    private var running = 0
    private var maximumRunning = 0
    private var rawFrames = 0
    private var deliveredFrames = 0
    private var stoppedEvents = 0
    private var errors: [String] = []

    func didStart(nativeStarts: Int) {
        lock.withLock {
            starts += 1
            self.nativeStarts += nativeStarts
            running += 1
            maximumRunning = max(maximumRunning, running)
        }
    }

    func didShutdown() { lock.withLock { shutdowns += 1 } }

    func didStop() {
        lock.withLock {
            stops += 1
            running -= 1
        }
    }

    func makeCapture() -> TouchBarCapture {
        let live = TouchBarCaptureDependencies.live
        return TouchBarCapture(
            onFrame: { [self] _ in lock.withLock { deliveredFrames += 1 } },
            onNotice: { _ in },
            onError: { [self] error in lock.withLock { errors.append(error.localizedDescription) } },
            dependencies: TouchBarCaptureDependencies(
                makeStream: { [self] queue, handler in
                    guard let stream = live.makeStream(queue, { [self] status, surface in
                        lock.withLock {
                            if status == .frameComplete && surface != nil { rawFrames += 1 }
                            if status == .stopped { stoppedEvents += 1 }
                        }
                        handler(status, surface)
                    }) else { return nil }
                    let measured = MeasuredDisplayStream(stream: stream, probe: self)
                    lock.withLock { handles.append(WeakMeasuredStream(measured)) }
                    return measured
                },
                getTouchBarStatus: live.getTouchBarStatus,
                setTouchBarStatus: live.setTouchBarStatus,
                schedule: live.schedule
            ),
            workerQueue: queue
        )
    }

    func flush() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async { continuation.resume() }
        }
    }

    var hasReleasedStreams: Bool {
        lock.withLock { !handles.isEmpty && handles.allSatisfy { $0.value == nil } }
    }

    func result(expectedCycles: Int) -> (passed: Bool, data: Data) {
        lock.withLock {
            let retained = handles.filter { $0.value != nil }.count
            let passed = handles.count == 1 && starts == expectedCycles && stops == expectedCycles
                && nativeStarts == 1 && shutdowns == 1
                && running == 0 && maximumRunning == 1 && retained == 0 && stoppedEvents == 1
                && rawFrames > 0 && errors.isEmpty
            let values: [String: Any] = [
                "passed": passed, "stream_creations": handles.count,
                "successful_starts": starts, "successful_stops": stops,
                "native_starts": nativeStarts, "native_shutdowns": shutdowns,
                "running_streams": running, "maximum_running_streams": maximumRunning,
                "retained_streams": retained, "raw_frames": rawFrames,
                "delivered_frames": deliveredFrames, "stopped_events": stoppedEvents,
                "errors": errors,
            ]
            return (passed, (try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys])) ?? Data())
        }
    }
}

@main
private struct CaptureLifecycleVerifier {
    static func main() async {
        let stress = CommandLine.arguments.contains("--stress")
        let cycles = stress ? 100 : 4
        DispatchQueue.global().asyncAfter(deadline: .now() + Double(cycles) * 0.4 + 15) {
            FileHandle.standardError.write(Data("Native capture lifecycle verification timed out\n".utf8))
            exit(124)
        }
        let probe = CaptureLifecycleProbe()
        let capture = probe.makeCapture()
        capture.start()
        try? await Task.sleep(for: .milliseconds(stress ? 2_000 : 400))
        if stress {
            FileHandle.standardOutput.write(Data("{\"phase\":\"ready\"}\n".utf8))
            try? await Task.sleep(for: .seconds(3))
        }
        for _ in 1..<cycles {
            capture.pause()
            capture.start()
            try? await Task.sleep(for: .milliseconds(400))
        }
        capture.stop()
        await probe.flush()
        capture.shutdown()
        for _ in 0..<100 {
            await probe.flush()
            if probe.hasReleasedStreams { break }
            try? await Task.sleep(for: .milliseconds(20))
        }
        let result = probe.result(expectedCycles: cycles)
        FileHandle.standardOutput.write(result.data)
        FileHandle.standardOutput.write(Data("\n".utf8))
        withExtendedLifetime(capture) {}
        exit(result.passed ? EXIT_SUCCESS : EXIT_FAILURE)
    }
}
