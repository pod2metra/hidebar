import CoreGraphics
import HidebarCore

extension CGEventPoster {
    /// Posts a plain left click, tagged like every other synthetic event. Nothing is posted
    /// unless both halves of the click could be created.
    public func postClick(at point: CursorPoint) -> Bool {
        let types: [CGEventType] = [.leftMouseDown, .leftMouseUp]
        return AllOrNothing.deliver(types.map { clickEvent($0, at: point) }) {
            $0.post(tap: .cghidEventTap)
        }
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
