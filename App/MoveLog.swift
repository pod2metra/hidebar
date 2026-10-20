import HidebarCore
import os

/// Debug trace of every drag: what the executor reads and posts, and whether the post succeeded.
/// The wrappers delegate to the real poster, locator and window finder and only log.
private let moveLog = Logger(subsystem: "app.hidebar.Hidebar", category: "move")

@MainActor
struct LoggingPoster: EventPosting {
    let base: any EventPosting

    func cursorPosition() -> CursorPoint { base.cursorPosition() }

    func setCursorPosition(_ point: CursorPoint) {
        base.setCursorPosition(point)
        moveLog.debug("cursor restored to x=\(point.x) y=\(point.y)")
    }

    func postCommandDrag(_ drag: CommandDrag) -> Bool {
        let posted = base.postCommandDrag(drag)
        moveLog.debug(
            "drag item window=\(drag.item.windowID) pid=\(drag.item.ownerPID) anchor window=\(drag.anchor.windowID) pid=\(drag.anchor.ownerPID) release x=\(drag.release.x) y=\(drag.release.y) posted=\(posted)"
        )
        return posted
    }

    func postClick(at point: CursorPoint) -> Bool {
        let posted = base.postClick(at: point)
        moveLog.debug("click at x=\(point.x) y=\(point.y) posted=\(posted)")
        return posted
    }
}

@MainActor
struct LoggingWindows: WindowLocating {
    let base: any WindowLocating

    func window(of id: MenuBarItemID) -> WindowTarget? {
        let window = base.window(of: id)
        let text = window.map {
            "window=\($0.windowID) pid=\($0.ownerPID) x=\($0.frame.x) w=\($0.frame.width)"
        }
        moveLog.debug(
            "window of \(id.ownerBundleID, privacy: .public)/\(id.title, privacy: .public) -> \(text ?? "nil", privacy: .public)"
        )
        return window
    }
}

@MainActor
struct LoggingLocator: ItemLocating {
    let base: any ItemLocating

    func frame(of id: MenuBarItemID) -> ItemFrame? {
        let frame = base.frame(of: id)
        let text = frame.map { "x=\($0.x) y=\($0.y) w=\($0.width) h=\($0.height)" } ?? "nil"
        moveLog.debug(
            "locate \(id.ownerBundleID, privacy: .public)/\(id.title, privacy: .public) -> \(text, privacy: .public)"
        )
        return frame
    }
}
