import CoreGraphics
import Foundation
import IOSurface
import TouchBarPrivateAPI

enum TouchBarDisplayStreamStopBehavior: Sendable {
    case awaitStoppedEvent
    case retainForReuse
}

struct TouchBarStopSignalTracker {
    private var pendingStops = 0

    mutating func recordSuccessfulStop() { pendingStops += 1 }

    mutating func consume(status: CGDisplayStreamFrameStatus, displayTime: UInt64, hasSurface: Bool) -> Bool {
        guard pendingStops > 0, status == .frameComplete, displayTime == 0, !hasSurface else { return false }
        pendingStops -= 1
        return true
    }
}

protocol TouchBarDisplayStream: AnyObject, Sendable {
    var stopBehavior: TouchBarDisplayStreamStopBehavior { get }
    var nativeStartCount: Int { get }
    func start() -> CGError
    func stop() -> CGError
    func shutdown() -> CGError
}

extension TouchBarDisplayStream {
    var stopBehavior: TouchBarDisplayStreamStopBehavior { .awaitStoppedEvent }
    var nativeStartCount: Int { 0 }
    func shutdown() -> CGError { stop() }
}

struct TouchBarCaptureDependencies: Sendable {
    typealias EventHandler = @Sendable (CGDisplayStreamFrameStatus, IOSurfaceRef?) -> Void

    let makeStream: @Sendable (DispatchQueue, @escaping EventHandler) -> (any TouchBarDisplayStream)?
    let getTouchBarStatus: @Sendable () -> Int32
    let setTouchBarStatus: @Sendable (Int32) -> Void
    let schedule: @Sendable (DispatchQueue, DispatchTimeInterval, @escaping @Sendable () -> Void) -> Void

    static let live = Self(
        makeStream: { SystemTouchBarDisplayStream(queue: $0, onEvent: $1) },
        getTouchBarStatus: { TBRGetTouchBarStatus() },
        setTouchBarStatus: { TBRSetTouchBarStatus($0) },
        schedule: { queue, delay, work in
            queue.asyncAfter(deadline: .now() + delay, execute: work)
        }
    )
}

private final class RetainedTouchBarSurface {
    let surface: IOSurfaceRef

    init(_ surface: IOSurfaceRef) {
        self.surface = surface
        IOSurfaceIncrementUseCount(surface)
    }

    deinit { IOSurfaceDecrementUseCount(surface) }
}

private final class SystemTouchBarDisplayStream: TouchBarDisplayStream, @unchecked Sendable {
    private var stream: CGDisplayStream?
    private var retainedUntilStopped: SystemTouchBarDisplayStream?
    private(set) var nativeStartCount = 0
    private var isFinishing = false
    private var stopRequested = false
    private var isDelivering = false
    private var latestSurface: RetainedTouchBarSurface?
    private var stopSignals = TouchBarStopSignalTracker()
    private let onEvent: TouchBarCaptureDependencies.EventHandler

    var stopBehavior: TouchBarDisplayStreamStopBehavior { .retainForReuse }

    init?(queue: DispatchQueue, onEvent: @escaping TouchBarCaptureDependencies.EventHandler) {
        self.onEvent = onEvent
        guard let handle = TBRCreateTouchBarDisplayStream(
            queue,
            { [weak self] status, displayTime, surface, _ in
                guard let self, !self.isFinishing else { return }
                let didStop = status == .stopped || self.stopSignals.consume(
                    status: status, displayTime: displayTime, hasSurface: surface != nil
                )
                if didStop {
                    self.isFinishing = true
                    queue.async { [self] in
                        latestSurface = nil
                        stream = nil
                        retainedUntilStopped = nil
                        onEvent(.stopped, nil)
                    }
                } else if status == .frameComplete, let surface {
                    if self.latestSurface.map({ IOSurfaceGetID($0.surface) }) != IOSurfaceGetID(surface) {
                        self.latestSurface = RetainedTouchBarSurface(surface)
                    }
                    if self.isDelivering { self.onEvent(status, surface) }
                } else if status == .frameBlank
                    || (status == .frameComplete && displayTime == 0 && surface == nil) {
                    self.latestSurface = nil
                    if self.isDelivering { self.onEvent(.frameBlank, nil) }
                } else if self.isDelivering {
                    self.onEvent(status, surface)
                }
            }
        ) else { return nil }
        stream = handle.takeRetainedValue()
    }

    func start() -> CGError {
        guard let stream, !stopRequested, !isFinishing else { return .failure }
        isDelivering = true
        if nativeStartCount > 0 {
            if let latestSurface { onEvent(.frameComplete, latestSurface.surface) }
            return .success
        }
        retainedUntilStopped = self
        let result = TBRStartDisplayStream(stream)
        if result == .success { nativeStartCount += 1 }
        else {
            isDelivering = false
            retainedUntilStopped = nil
        }
        return result
    }

    func stop() -> CGError {
        isDelivering = false
        return .success
    }

    func shutdown() -> CGError {
        isDelivering = false
        guard let stream else { return .success }
        guard !stopRequested else { return .success }
        let result = TBRStopDisplayStream(stream)
        if result == .success {
            stopRequested = true
            stopSignals.recordSuccessfulStop()
        }
        return result
    }
}
