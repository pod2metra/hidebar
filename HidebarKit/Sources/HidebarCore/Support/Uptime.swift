import Foundation

/// Milliseconds on a monotonic clock, readable from any thread. Only differences mean anything.
public typealias Uptime = @Sendable () -> Int

/// The system's monotonic clock: it does not jump when the wall clock is set.
public func systemUptimeMilliseconds() -> Int {
    Int(DispatchTime.now().uptimeNanoseconds / 1_000_000)
}
