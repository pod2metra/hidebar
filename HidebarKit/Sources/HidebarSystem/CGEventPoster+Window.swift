import CoreGraphics
import Foundation
import HidebarCore

extension CGEventPoster {
    /// Raw field of the window an event is aimed at; CoreGraphics does not name it.
    private static let windowField = CGEventField(rawValue: 0x33)
    /// Time each half of a drag is given to reach the window server before the next one is sent.
    private static let settleSeconds = 0.05

    func event(_ type: CGEventType, at point: CursorPoint, flags: CGEventFlags) -> CGEvent? {
        let event = CGEvent(
            mouseEventSource: CGEventSource(stateID: .hidSystemState), mouseType: type,
            mouseCursorPosition: CGPoint(x: point.x, y: point.y), mouseButton: .left)
        event?.flags = flags
        event?.setIntegerValueField(.eventSourceUserData, value: InputGate.syntheticEventTag)
        return event
    }

    /// A Command-mouse event aimed at `window` and sent to the process owning `owner`'s window.
    /// The window server routes status item events by these fields, not by the pointer position.
    func event(
        _ type: CGEventType, at point: CursorPoint, aimedAt window: WindowTarget, to owner: WindowTarget
    ) -> CGEvent? {
        let event = event(type, at: point, flags: .maskCommand)
        let windowID = Int64(window.windowID)
        event?.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(owner.ownerPID))
        event?.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: windowID)
        event?.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: windowID)
        Self.windowField.map { event?.setIntegerValueField($0, value: windowID) }
        return event
    }

    /// The session tap first, then the owner process, as Ice does.
    func send(_ event: CGEvent) {
        event.post(tap: .cgSessionEventTap)
        event.postToPid(pid_t(event.getIntegerValueField(.eventTargetUnixProcessID)))
        Thread.sleep(forTimeInterval: Self.settleSeconds)
    }
}
