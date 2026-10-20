import Synchronization

/// Decides whether an input event reaches the system while a move runs (rule 4): user input is
/// ignored, events the app posted itself pass. The system adapter asks it from an event tap on
/// another thread, so the state is lock-protected.
///
/// `begin` and `end` nest: a move inside a plan keeps input suppressed until the outermost `end`.
public final class InputGate: Sendable {
    /// Stored in `eventSourceUserData` of every event the app posts, so the tap can tell them apart.
    public static let syntheticEventTag: Int64 = 0x4844_4252

    private let depth = Mutex<Int>(0)

    public init() {}

    public var suppressUserInput: Bool { depth.withLock { $0 > 0 } }

    public func begin() {
        depth.withLock { $0 += 1 }
    }

    /// An `end` without a matching `begin` leaves the gate open.
    public func end() {
        depth.withLock { $0 = max($0 - 1, 0) }
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
