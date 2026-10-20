import CoreGraphics
import HidebarCore

extension CGEventPoster {
    /// Posts a plain left click, tagged like every other synthetic event. Nothing is posted
    /// unless both halves of the click could be created.
    public func postClick(at point: CursorPoint) -> Bool {
        let types: [CGEventType] = [.leftMouseDown, .leftMouseUp]
        let events = types.compactMap { clickEvent($0, at: point) }
        let complete = events.count == types.count
        (complete ? events : []).forEach { $0.post(tap: .cghidEventTap) }
        return complete
    }

    private func clickEvent(_ type: CGEventType, at point: CursorPoint) -> CGEvent? {
        let event = CGEvent(
            mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: type,
            mouseCursorPosition: CGPoint(x: point.x, y: point.y), mouseButton: .left)
        event?.flags = []
        event?.setIntegerValueField(.eventSourceUserData, value: InputGate.syntheticEventTag)
        return event
    }
}
