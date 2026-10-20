import Dispatch
import HidebarCore

/// Runs blocking work on one serial queue: a slow Accessibility read cannot pile up
/// behind itself, and the main thread stays free during it.
public final class BackgroundQueue: BackgroundRunning {
    private let queue = DispatchQueue(label: "app.hidebar.discovery", qos: .userInitiated)

    public init() {}

    public func run<Value: Sendable>(_ work: @escaping @Sendable () -> Value) async -> Value {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: work()) }
        }
    }
}
