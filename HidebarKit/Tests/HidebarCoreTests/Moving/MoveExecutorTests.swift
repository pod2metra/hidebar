import Testing

@testable import HidebarCore

private struct PersistError: Error, Equatable {}

@MainActor @Suite struct MoveExecutorTests {
    private let bar = MoveFakeBar()
    private let savedCursor = CursorPoint(x: 900, y: 500)

    private var executor: MoveExecutor { MoveExecutor(poster: bar, locator: bar, clock: bar) }

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

    @Test func dragPressesOnItemCentreReleasesAtAnchorRightEdgeAndRestoresCursor() {
        scene()
        moveOnWait(1)
        #expect(executor.move(step()) == .moved)
        #expect(
            bar.log == [
                .down(CursorPoint(x: 105, y: 10)), .up(CursorPoint(x: 70, y: 10)), .wait(25),
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
        #expect(bar.log.isEmpty)
        #expect(bar.cursorReads == 0)
    }

    // MARK: execute

    private var layout: Layout {
        try! Layout(visible: [moveID("item")], hidden: [moveID("other")], groups: [])
    }

    @Test func failureOnALaterStepPersistsNothingEvenThoughEarlierStepsMoved() {
        scene()
        place("second", x: 120)
        moveOnWait(1)
        let second = MoveStep(item: moveItem("second"), anchor: moveID("anchor"), side: .leftOf)
        var persisted = 0
        let result = executor.execute([step(), second], confirming: layout) { _ in persisted += 1 }
        #expect(result == .stopped(stepIndex: 1, outcome: .failed))
        #expect(persisted == 0)
    }

    @Test func everyStepMovedPersistsTheLayoutExactlyOnce() {
        scene()
        place("second", x: 120)
        bar.onWait = { [bar] count in
            let target = count == 1 ? "item" : "second"
            bar.frames[moveID(target)] = ItemFrame(x: 40, y: 0, width: 10, height: 20)
        }
        let second = MoveStep(item: moveItem("second"), anchor: moveID("anchor"), side: .leftOf)
        var persisted: [(layout: Layout, downsSoFar: Int)] = []
        let result = executor.execute([step(), second], confirming: layout) { saved in
            persisted.append((saved, bar.downs.count))
        }
        #expect(result == .confirmed)
        #expect(persisted.count == 1)
        #expect(persisted[0].layout == layout)
        #expect(persisted[0].downsSoFar == 2)
    }

    @Test func emptyPlanIsConfirmedAndPersisted() {
        var persisted = 0
        let result = executor.execute([], confirming: layout) { _ in persisted += 1 }
        #expect(result == .confirmed)
        #expect(persisted == 1)
        #expect(bar.log.isEmpty)
    }

    @Test func failedStepStopsThePlanAndPersistsNothing() {
        scene()
        place("second", x: 120)
        let second = MoveStep(item: moveItem("second"), anchor: moveID("anchor"), side: .leftOf)
        var persisted = 0
        let result = executor.execute([step(), second], confirming: layout) { _ in persisted += 1 }
        #expect(result == .stopped(stepIndex: 0, outcome: .failed))
        #expect(persisted == 0)
        #expect(bar.downs.count == 3)
        #expect(bar.cursor == savedCursor)
    }

    @Test func unmovableStepStopsThePlanAfterEarlierStepsAndPersistsNothing() {
        scene()
        moveOnWait(1)
        var persisted = 0
        let result = executor.execute(
            [step(), step(item: "clock", movable: false)], confirming: layout
        ) { _ in persisted += 1 }
        #expect(result == .stopped(stepIndex: 1, outcome: .unmovable))
        #expect(persisted == 0)
        #expect(bar.downs.count == 1)
    }

    @Test func persistErrorPropagatesAfterTheItemsMoved() {
        scene()
        moveOnWait(1)
        do {
            _ = try executor.execute([step()], confirming: layout) { _ in throw PersistError() }
            Issue.record("expected the persist error to propagate")
        } catch {
            #expect(error as? PersistError == PersistError())
            #expect(bar.downs.count == 1)
        }
    }
}
