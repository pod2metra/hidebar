import Synchronization

/// Decides whether an input event reaches the system while a move runs (rule 4): user input is
/// ignored, events the app posted itself pass. The system adapter asks it from an event tap on
/// another thread, so the state is lock-protected.
///
/// `begin` and `end` nest: a move inside a plan keeps input suppressed until the outermost `end`.
///
/// Suppression has a total bound: once the outermost `begin` is `maxSuppressionMilliseconds` old the
/// gate lets user input through again, whatever the move is stuck on. The thread that made the
/// moves can be blocked (a hung app answers Accessibility only after its timeout), so the tap
/// thread must be able to give input back without it. `isOverdue` tells the movers to stop too.
public final class InputGate: Sendable {
    /// Stored in `eventSourceUserData` of every event the app posts, so the tap can tell them apart.
    public static let syntheticEventTag: Int64 = 0x4844_4252
    /// Enough for a long plan, short enough that a hung app cannot keep the keyboard for long.
    public static let defaultMaxSuppressionMilliseconds = 10_000

    private struct State {
        var depth = 0
        var startedAt = 0

        mutating func open(at now: Int) {
            if depth == 0 { startedAt = now }
            depth += 1
        }
    }

    private let state = Mutex(State())
    private let maxSuppressionMilliseconds: Int
    private let uptime: Uptime

    public init(
        maxSuppressionMilliseconds: Int = defaultMaxSuppressionMilliseconds,
        uptime: @escaping Uptime = systemUptimeMilliseconds
    ) {
        self.maxSuppressionMilliseconds = maxSuppressionMilliseconds
        self.uptime = uptime
    }

    public var suppressUserInput: Bool {
        state.withLock { $0.depth > 0 && !hasExpired($0) }
    }

    /// True while a `begin` is open and the bound has passed: no more moves should be started.
    public var isOverdue: Bool {
        state.withLock { $0.depth > 0 && hasExpired($0) }
    }

    public func begin() {
        let now = uptime()
        state.withLock { $0.open(at: now) }
    }

    /// An `end` without a matching `begin` leaves the gate open.
    public func end() {
        state.withLock { $0.depth = max($0.depth - 1, 0) }
    }

    private func hasExpired(_ state: State) -> Bool {
        uptime() - state.startedAt >= maxSuppressionMilliseconds
    }

    public func shouldPass(isSynthetic: Bool) -> Bool {
        isSynthetic || !suppressUserInput
    }

    public static func isSynthetic(userData: Int64) -> Bool {
        userData == syntheticEventTag
    }

    /// Raw values of `CGEventType.tapDisabledByTimeout` and `.tapDisabledByUserInput`.
    public static let tapDisabledByTimeoutRaw: UInt32 = 0xFFFF_FFFE
    public static let tapDisabledByUserInputRaw: UInt32 = 0xFFFF_FFFF

    /// `true` when the event type says the system switched the tap off. A tap that stays off
    /// stops dropping user input, so the adapter must turn it back on.
    public static func shouldReenable(eventTypeRaw: UInt32) -> Bool {
        eventTypeRaw == Self.tapDisabledByTimeoutRaw || eventTypeRaw == Self.tapDisabledByUserInputRaw
    }
}
