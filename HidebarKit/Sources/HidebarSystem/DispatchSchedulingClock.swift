import Dispatch
import HidebarCore

/// A scheduled `DispatchWorkItem` that can still be withdrawn.
@MainActor
final class DispatchCancellable: Cancellable {
    private let workItem: DispatchWorkItem

    init(_ workItem: DispatchWorkItem) {
        self.workItem = workItem
    }

    func cancel() {
        workItem.cancel()
    }
}

/// Runs scheduled actions on the main queue.
@MainActor
public struct DispatchSchedulingClock: SchedulingClock {
    public init() {}

    public func schedule(after delay: Double, action: @escaping @MainActor () -> Void) -> any Cancellable {
        let workItem = DispatchWorkItem { MainActor.assumeIsolated(action) }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
        return DispatchCancellable(workItem)
    }
}
