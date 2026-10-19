import Foundation

/// A scheduled action that can be withdrawn before it fires.
@MainActor
public protocol Cancellable: AnyObject {
    func cancel()
}

/// Time source for the core. Waiting goes through `schedule`, never through
/// `Task.sleep`, so tests drive time by hand.
@MainActor
public protocol SchedulingClock {
    /// Runs `action` once, `delay` seconds from now, unless the result is cancelled first.
    func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void) -> any Cancellable
}
