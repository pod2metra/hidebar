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
    /// Left mouse button down with the Command flag set.
    func postCommandMouseDown(at point: CursorPoint)
    /// Left mouse button up with the Command flag set.
    func postCommandMouseUp(at point: CursorPoint)
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
