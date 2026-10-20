import CoreGraphics
import HidebarCore

/// Posts real mouse events. Every event carries `InputGate.syntheticEventTag`, so the input
/// gate lets it pass and drops the user's own input.
@MainActor
public struct CGEventPoster: EventPosting {
    public init() {}

    public func cursorPosition() -> CursorPoint {
        CGEvent(source: nil).map { CursorPoint(x: $0.location.x, y: $0.location.y) }
            ?? CursorPoint(x: 0, y: 0)
    }

    public func setCursorPosition(_ point: CursorPoint) {
        CGWarpMouseCursorPosition(CGPoint(x: point.x, y: point.y))
    }

    /// Nothing is posted unless both halves of the drag could be created.
    public func postCommandDrag(from start: CursorPoint, to end: CursorPoint) -> Bool {
        let events = [
            event(.leftMouseDown, at: start, flags: .maskCommand),
            event(.leftMouseUp, at: end, flags: .maskCommand),
        ]
        return AllOrNothing.deliver(events) { $0.post(tap: .cghidEventTap) }
    }

    func event(_ type: CGEventType, at point: CursorPoint, flags: CGEventFlags) -> CGEvent? {
        let event = CGEvent(
            mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: type,
            mouseCursorPosition: CGPoint(x: point.x, y: point.y), mouseButton: .left)
        event?.flags = flags
        event?.setIntegerValueField(.eventSourceUserData, value: InputGate.syntheticEventTag)
        return event
    }
}
