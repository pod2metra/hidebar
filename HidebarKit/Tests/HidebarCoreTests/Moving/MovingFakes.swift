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
final class MoveFakeBar: EventPosting, ItemLocating, WindowLocating, MoveClock {
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
    /// What `postCommandDrag` reports; false simulates events that could not be created.
    var dragPosts = true
    /// Every wait moves it forward by the time waited; `readCost` is what each frame read takes.
    let uptime = TestUptime()
    var readCost = 0
    /// When set, a drag lands on the next wait like a real drop: the item whose centre was pressed
    /// ends up centred on the release point. Without it only scripted frames ever change.
    var dragsLand = false
    private var pendingDrag: CommandDrag?
    /// How much narrower a window is than the item's frame on each side (1 on macOS 26).
    var windowInset = 0.0
    private(set) var drags: [CommandDrag] = []
    private var windowIDs: [MenuBarItemID: Int] = [:]

    /// A stable window number per item, handed out in the order items are first asked about.
    private func windowID(of id: MenuBarItemID) -> Int {
        let known = windowIDs[id] ?? 100 + windowIDs.count
        windowIDs[id] = known
        return known
    }

    /// Items that have a frame but no window the window server can name.
    var windowless: Set<MenuBarItemID> = []

    func window(of id: MenuBarItemID) -> WindowTarget? {
        guard !windowless.contains(id) else { return nil }
        return frames[id].map { frame in
            WindowTarget(
                windowID: windowID(of: id), ownerPID: 688,
                frame: ItemFrame(
                    x: frame.x + windowInset, y: frame.y, width: frame.width - 2 * windowInset,
                    height: frame.height))
        }
    }

    private func landPendingDrag() {
        guard let drag = pendingDrag else { return }
        pendingDrag = nil
        guard let pressed = frames.first(where: { windowID(of: $0.key) == drag.item.windowID }) else {
            return
        }
        frames[pressed.key] = ItemFrame(
            x: drag.release.x - pressed.value.width / 2, y: pressed.value.y,
            width: pressed.value.width, height: pressed.value.height)
    }

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

    func postCommandDrag(_ drag: CommandDrag) -> Bool {
        guard dragPosts else { return false }
        cursor = CommandDrag.pressPoint
        log.append(.down(CommandDrag.pressPoint))
        cursor = drag.release
        log.append(.up(drag.release))
        drags.append(drag)
        pendingDrag = dragsLand ? drag : nil
        return true
    }

    func postClick(at point: CursorPoint) -> Bool {
        cursor = point
        log.append(.click(point))
        return clickPosts
    }

    func frame(of id: MenuBarItemID) -> ItemFrame? {
        lookups += 1
        uptime.advance(by: readCost)
        return frames[id]
    }

    func wait(milliseconds: Int) {
        uptime.advance(by: milliseconds)
        waits += 1
        log.append(.wait(milliseconds))
        landPendingDrag()
        onWait(waits)
    }
}

func moveID(_ name: String) -> MenuBarItemID {
    MenuBarItemID(ownerBundleID: "test.\(name)", title: "")
}

func moveItem(_ name: String, movable: Bool = true) -> MenuBarItem {
    MenuBarItem(
        id: moveID(name), frame: ItemFrame(x: 0, y: 0, width: 10, height: 20), isMovable: movable)
}
