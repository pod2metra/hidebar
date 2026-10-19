import Foundation

@testable import HidebarCore

/// Test clock: time moves only through `advance(by:)`.
@MainActor
final class ManualClock: SchedulingClock {
    @MainActor
    final class Timer: Cancellable {
        fileprivate let fireAt: Date
        fileprivate let action: @MainActor () -> Void
        private(set) var cancelCount = 0
        fileprivate var fired = false

        fileprivate init(fireAt: Date, action: @escaping @MainActor () -> Void) {
            self.fireAt = fireAt
            self.action = action
        }

        var isCancelled: Bool { cancelCount > 0 }

        func cancel() { cancelCount += 1 }
    }

    private(set) var now = Date(timeIntervalSinceReferenceDate: 0)
    private(set) var timers: [Timer] = []

    var pending: [Timer] { timers.filter { !$0.fired && !$0.isCancelled } }

    func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void) -> any Cancellable {
        let timer = Timer(fireAt: now.addingTimeInterval(delay), action: action)
        timers.append(timer)
        return timer
    }

    /// Moves time forward, firing due timers in order (including ones scheduled meanwhile).
    func advance(by interval: TimeInterval) {
        let target = now.addingTimeInterval(interval)
        while let next = pending.filter({ $0.fireAt <= target }).min(by: { $0.fireAt < $1.fireAt }) {
            now = max(now, next.fireAt)
            next.fired = true
            next.action()
        }
        now = target
    }
}
