import Testing

@testable import HidebarCore

@MainActor @Suite struct MoveExecutorTests {
    private let bar = MoveFakeBar()
    private let savedCursor = CursorPoint(x: 900, y: 500)

    private var executor: MoveExecutor {
        MoveExecutor(poster: bar, locator: bar, windows: bar, clock: bar, deadline: MoveDeadline())
    }

    /// Item at x 100..110, anchor at x 50..70, both 20 high: centre of the item is (105, 10).
    private func place(_ name: String, x: Double, width: Double = 10) {
        bar.frames[moveID(name)] = ItemFrame(x: x, y: 0, width: width, height: 20)
    }

    private func step(_ side: DropSide = .rightOf, item: String = "item", movable: Bool = true) -> MoveStep {
        MoveStep(item: moveItem(item, movable: movable), anchor: moveID("anchor"), side: side)
    }

    private func scene() {
        place("item", x: 100)
        place("anchor", x: 50, width: 20)
    }

    /// Item jumps to x 60 as soon as the `n`-th wait since creation has happened.
    private func moveOnWait(_ n: Int, item: String = "item") {
        bar.onWait = { [bar] count in
            if count == n { bar.frames[moveID(item)] = ItemFrame(x: 60, y: 0, width: 10, height: 20) }
        }
    }

    @Test func dragPressesFarAwayReleasesAtAnchorRightEdgeAndRestoresCursor() {
        scene()
        moveOnWait(1)
        #expect(executor.move(step()) == .moved)
        #expect(
            bar.log == [
                .down(CursorPoint(x: 20_000, y: 20_000)), .up(CursorPoint(x: 70, y: 10)), .wait(25),
                .setCursor(savedCursor),
            ])
        #expect(bar.cursor == savedCursor)
    }

    @Test func dropLeftOfAnchorReleasesAtAnchorLeftEdge() {
        scene()
        moveOnWait(1)
        #expect(executor.move(step(.leftOf)) == .moved)
        #expect(bar.ups == [CursorPoint(x: 50, y: 10)])
    }

    @Test func dragNamesTheWindowOfTheItemAndOfTheAnchor() {
        scene()
        moveOnWait(1)
        #expect(executor.move(step()) == .moved)
        #expect(
            bar.drags == [
                CommandDrag(
                    item: WindowTarget(
                        windowID: 100, ownerPID: 688,
                        frame: ItemFrame(x: 100, y: 0, width: 10, height: 20)),
                    anchor: WindowTarget(
                        windowID: 101, ownerPID: 688,
                        frame: ItemFrame(x: 50, y: 0, width: 20, height: 20)),
                    side: .rightOf)
            ])
    }

    @Test func rightDropFollowsTheAnchorWindowNotItsWiderAccessibilityFrame() {
        scene()
        bar.windowInset = 1
        moveOnWait(1)
        #expect(executor.move(step()) == .moved)
        #expect(bar.ups == [CursorPoint(x: 69, y: 10)])
    }

    @Test func leftDropFollowsTheAnchorWindowNotItsWiderAccessibilityFrame() {
        scene()
        bar.windowInset = 1
        moveOnWait(1)
        #expect(executor.move(step(.leftOf)) == .moved)
        #expect(bar.ups == [CursorPoint(x: 51, y: 10)])
    }

    @Test func itemWithoutAWindowFailsAfterABoundedWaitWithoutAnyEventOrCursorChange() {
        scene()
        bar.windowless = [moveID("item")]
        #expect(executor.move(step()) == .failed)
        #expect(bar.downs.isEmpty)
        #expect(bar.ups.isEmpty)
        #expect(bar.restores.isEmpty)
        #expect(bar.cursorReads == 0)
        #expect(bar.waits == 3 * MoveExecutor.windowPollLimit)
    }

    @Test func anchorWithoutAWindowFailsAfterABoundedWaitWithoutAnyEventOrCursorChange() {
        scene()
        bar.windowless = [moveID("anchor")]
        #expect(executor.move(step()) == .failed)
        #expect(bar.downs.isEmpty)
        #expect(bar.cursorReads == 0)
        #expect(bar.waits == 3 * MoveExecutor.windowPollLimit)
    }

    @Test func windowThatShowsUpWhileTheBarSettlesIsDraggedWithoutBurningAnAttempt() {
        scene()
        bar.windowless = [moveID("anchor")]
        bar.onWait = { [bar] count in
            if count == 2 { bar.windowless = [] }
            if count == 3 { bar.frames[moveID("item")] = ItemFrame(x: 60, y: 0, width: 10, height: 20) }
        }
        #expect(executor.move(step()) == .moved)
        // Two waits for the window, then the first poll after the drag.
        #expect(bar.waits == 3)
        #expect(bar.downs.count == 1)
    }

    @Test func pollsForTheWindowAreSpacedByThePollInterval() {
        scene()
        bar.windowless = [moveID("item")]
        _ = executor.move(step())
        #expect(bar.log.prefix(2) == [.wait(25), .wait(25)])
    }

    @Test func unmovableItemPostsNothingAndTouchesNothing() {
        scene()
        #expect(executor.move(step(movable: false)) == .unmovable)
        #expect(bar.log.isEmpty)
        #expect(bar.cursorReads == 0)
        #expect(bar.lookups == 0)
    }

    @Test func stuckItemFailsAfterThreeAttemptsAndCursorIsRestoredEachTime() {
        scene()
        #expect(executor.move(step()) == .failed)
        #expect(bar.downs.count == 3)
        #expect(bar.ups.count == 3)
        #expect(bar.waits == 30)
        #expect(bar.restores == [savedCursor, savedCursor, savedCursor])
        #expect(bar.cursor == savedCursor)
    }

    @Test func dragThatCouldNotBePostedFailsEachAttemptWithoutPollingAndKeepsTheCursor() {
        scene()
        bar.dragPosts = false
        #expect(executor.move(step()) == .failed)
        #expect(bar.waits == 0)
        #expect(bar.downs.isEmpty)
        #expect(bar.restores == [savedCursor, savedCursor, savedCursor])
        #expect(bar.cursor == savedCursor)
    }

    @Test func itemThatMovesOnTheSecondAttemptStopsRetrying() {
        scene()
        moveOnWait(11)
        #expect(executor.move(step()) == .moved)
        #expect(bar.downs.count == 2)
        #expect(bar.restores == [savedCursor, savedCursor])
        #expect(bar.waits == 11)
    }

    @Test func itemThatMovesOnTheLastPollOfTheLastAttemptIsMoved() {
        scene()
        moveOnWait(30)
        #expect(executor.move(step()) == .moved)
        #expect(bar.downs.count == 3)
        #expect(bar.waits == 30)
    }

    @Test func itemThatMovesOnTheLastPollOfAnAttemptIsNotDraggedAgain() {
        scene()
        moveOnWait(10)
        #expect(executor.move(step()) == .moved)
        #expect(bar.downs.count == 1)
    }

    @Test func frameThatMovesOnlyVerticallyDoesNotCount() {
        scene()
        bar.onWait = { [bar] _ in bar.frames[moveID("item")] = ItemFrame(x: 100, y: 5, width: 10, height: 20) }
        #expect(executor.move(step()) == .failed)
    }

    @Test func itemVanishingForAPollAndReturningMovedIsMoved() {
        scene()
        bar.onWait = { [bar] count in
            bar.frames[moveID("item")] =
                count == 1 ? nil : ItemFrame(x: 60, y: 0, width: 10, height: 20)
        }
        #expect(executor.move(step()) == .moved)
        #expect(bar.downs.count == 1)
    }

    @Test func missingItemFailsWithoutAnyEventOrCursorChange() {
        place("anchor", x: 50, width: 20)
        #expect(executor.move(step()) == .failed)
        #expect(bar.log.isEmpty)
        #expect(bar.cursorReads == 0)
    }

    @Test func missingAnchorFailsWithoutAnyEventOrCursorChange() {
        place("item", x: 100)
        #expect(executor.move(step()) == .failed)
        #expect(bar.downs.isEmpty)
        #expect(bar.restores.isEmpty)
        #expect(bar.cursorReads == 0)
    }
}
