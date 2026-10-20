@testable import HidebarCore

enum MoveEvent: Equatable {
    case down(CursorPoint)
    case up(CursorPoint)
    case click(CursorPoint)
    case setCursor(CursorPoint)
    case wait(Int)
}

/// One object playing poster, locator and clock, so a test sees the events in the order they happened.
/// Posting an event warps the cursor to its point, like a real posted event does.
@MainActor
final class MoveFakeBar: EventPosting, ItemLocating, MoveClock {
    var frames: [MenuBarItemID: ItemFrame] = [:]
    var cursor = CursorPoint(x: 900, y: 500)
    private(set) var log: [MoveEvent] = []
    private(set) var cursorReads = 0
    private(set) var lookups = 0
    private(set) var waits = 0
    /// Called after every wait with the 1-based wait count since creation.
    var onWait: (Int) -> Void = { _ in }
    /// What `postClick` reports; false simulates an event that could not be posted.
    var clickPosts = true

    var clicks: [CursorPoint] { log.compactMap { if case .click(let point) = $0 { point } else { nil } } }
    var downs: [CursorPoint] { log.compactMap { if case .down(let point) = $0 { point } else { nil } } }
    var ups: [CursorPoint] { log.compactMap { if case .up(let point) = $0 { point } else { nil } } }
    var restores: [CursorPoint] {
        log.compactMap { if case .setCursor(let point) = $0 { point } else { nil } }
    }

    func cursorPosition() -> CursorPoint {
        cursorReads += 1
        return cursor
    }

    func setCursorPosition(_ point: CursorPoint) {
        cursor = point
        log.append(.setCursor(point))
    }

    func postCommandMouseDown(at point: CursorPoint) {
        cursor = point
        log.append(.down(point))
    }

    func postCommandMouseUp(at point: CursorPoint) {
        cursor = point
        log.append(.up(point))
    }

    func postClick(at point: CursorPoint) -> Bool {
        cursor = point
        log.append(.click(point))
        return clickPosts
    }

    func frame(of id: MenuBarItemID) -> ItemFrame? {
        lookups += 1
        return frames[id]
    }

    func wait(milliseconds: Int) {
        waits += 1
        log.append(.wait(milliseconds))
        onWait(waits)
    }
}

func moveID(_ name: String) -> MenuBarItemID {
    MenuBarItemID(ownerBundleID: "test.\(name)", title: "")
}

func moveItem(_ name: String, movable: Bool = true) -> MenuBarItem {
    MenuBarItem(
        id: moveID(name), frame: ItemFrame(x: 0, y: 0, width: 10, height: 20), isMovable: movable,
        isHidable: true)
}
