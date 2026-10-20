import CoreGraphics
import HidebarCore

/// Posts real Command-clicks. Every event carries `InputGate.syntheticEventTag`, so the input
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

    public func postCommandMouseDown(at point: CursorPoint) {
        post(.leftMouseDown, at: point)
    }

    public func postCommandMouseUp(at point: CursorPoint) {
        post(.leftMouseUp, at: point)
    }

    private func post(_ type: CGEventType, at point: CursorPoint) {
        let event = CGEvent(
            mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: type,
            mouseCursorPosition: CGPoint(x: point.x, y: point.y), mouseButton: .left)
        event?.flags = .maskCommand
        event?.setIntegerValueField(.eventSourceUserData, value: InputGate.syntheticEventTag)
        event?.post(tap: .cghidEventTap)
    }
}
