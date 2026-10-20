import Testing

@testable import HidebarCore

@Suite struct CommandDragTests {
    private func target(_ id: Int, x: Double) -> WindowTarget {
        WindowTarget(
            windowID: id, ownerPID: 688, frame: ItemFrame(x: x, y: 2, width: 30, height: 20))
    }

    @Test func pressPointIsFarOffEveryDisplay() {
        #expect(CommandDrag.pressPoint == CursorPoint(x: 20_000, y: 20_000))
    }

    @Test func releaseOnTheRightIsTheAnchorsRightEdgeAtItsMiddleHeight() {
        let drag = CommandDrag(item: target(1, x: 0), anchor: target(2, x: 100), side: .rightOf)
        #expect(drag.release == CursorPoint(x: 130, y: 12))
    }

    @Test func releaseOnTheLeftIsTheAnchorsLeftEdgeAtItsMiddleHeight() {
        let drag = CommandDrag(item: target(1, x: 0), anchor: target(2, x: 100), side: .leftOf)
        #expect(drag.release == CursorPoint(x: 100, y: 12))
    }

    @Test func dragKeepsBothWindowsToName() {
        let item = target(1, x: 0)
        let anchor = target(2, x: 100)
        let drag = CommandDrag(item: item, anchor: anchor, side: .leftOf)
        #expect(drag.item == item)
        #expect(drag.anchor == anchor)
    }
}
