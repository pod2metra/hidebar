import CoreGraphics
import Foundation
import HidebarCore

/// Posts real mouse events.
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
    public func postCommandDrag(_ drag: CommandDrag) -> Bool {
        LocalEventFilter.permitAll()
        let events = [
            event(.leftMouseDown, at: CommandDrag.pressPoint, aimedAt: drag.item, to: drag.item),
            event(.leftMouseUp, at: drag.release, aimedAt: drag.anchor, to: drag.item),
        ]
        return AllOrNothing.deliver(events, using: send)
    }
}
