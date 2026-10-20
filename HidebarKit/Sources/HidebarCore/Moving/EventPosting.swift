/// Screen point in points; the core's CoreGraphics-free stand-in for `CGPoint`.
public struct CursorPoint: Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

/// Synthetic input. The adapter posts real `CGEvent`s; tests record the calls.
@MainActor
public protocol EventPosting {
    func cursorPosition() -> CursorPoint
    func setCursorPosition(_ point: CursorPoint)
    /// Left mouse button down at `CommandDrag.pressPoint` aimed at the item's window, then up at
    /// `release` aimed at the anchor's window, both with the Command flag set. All or nothing:
    /// false when either event could not be created, and then neither is posted, so a button is
    /// never left pressed.
    func postCommandDrag(_ drag: CommandDrag) -> Bool
    /// A plain left click (down and up, no modifiers). False when the event could not be created or posted.
    func postClick(at point: CursorPoint) -> Bool
}

/// Live position of an item, read right before and after a drag (Accessibility or window bounds).
@MainActor
public protocol ItemLocating {
    /// `nil` when the item is not on screen (gone, or not found).
    func frame(of id: MenuBarItemID) -> ItemFrame?
}

/// Pause between polls of an item's frame. Synchronous on purpose: the move is a short
/// blocking sequence on the main actor, and tests run it without any real delay.
@MainActor
public protocol MoveClock {
    func wait(milliseconds: Int)
}
