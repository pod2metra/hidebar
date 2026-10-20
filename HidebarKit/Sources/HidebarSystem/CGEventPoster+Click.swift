import CoreGraphics
import HidebarCore

extension CGEventPoster {
    /// Posts a plain left click. Nothing is posted unless both halves of the click could be created.
    public func postClick(at point: CursorPoint) -> Bool {
        let events = [
            event(.leftMouseDown, at: point, flags: []), event(.leftMouseUp, at: point, flags: []),
        ]
        return AllOrNothing.deliver(events) { $0.post(tap: .cghidEventTap) }
    }
}
