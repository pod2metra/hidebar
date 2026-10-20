import Synchronization

@testable import HidebarCore

/// Test monotonic clock: time moves only through `advance(by:)`.
final class TestUptime: Sendable {
    private let milliseconds = Mutex(0)

    var now: Int { milliseconds.withLock { $0 } }

    var reader: Uptime { { [self] in now } }

    func advance(by amount: Int) {
        milliseconds.withLock { $0 += amount }
    }
}
