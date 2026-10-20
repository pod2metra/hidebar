import Synchronization

/// Bounds a synthetic event sequence in time (rule 4): once the outermost `begin` is
/// `budgetMilliseconds` old, `isOverdue` is true and the movers start nothing more, whatever the
/// move is stuck on. A hung app answers Accessibility only after its timeout, so the bound is
/// checked between steps, never inside one. User input is never blocked.
///
/// `begin` and `end` nest: a move inside a click keeps the one deadline of the outermost `begin`.
public final class MoveDeadline: Sendable {
    /// Enough for a long plan, short enough that a hung app cannot keep the cursor for long.
    public static let defaultBudgetMilliseconds = 10_000

    private struct State {
        var depth = 0
        var startedAt = 0

        mutating func open(at now: Int) {
            if depth == 0 { startedAt = now }
            depth += 1
        }
    }

    private let state = Mutex(State())
    private let budgetMilliseconds: Int
    private let uptime: Uptime

    public init(
        budgetMilliseconds: Int = defaultBudgetMilliseconds,
        uptime: @escaping Uptime = systemUptimeMilliseconds
    ) {
        self.budgetMilliseconds = budgetMilliseconds
        self.uptime = uptime
    }

    /// True while a `begin` is open and the budget is spent: no more events should be started.
    public var isOverdue: Bool {
        state.withLock { $0.depth > 0 && uptime() - $0.startedAt >= budgetMilliseconds }
    }

    public func begin() {
        let now = uptime()
        state.withLock { $0.open(at: now) }
    }

    /// An `end` without a matching `begin` is ignored.
    public func end() {
        state.withLock { $0.depth = max($0.depth - 1, 0) }
    }
}
