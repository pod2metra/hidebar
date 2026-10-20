import Testing

@testable import HidebarCore

/// A step counts as done when its item changed x. After the whole plan the frames are read again:
/// an item that merely shifted because a neighbour changed width is not where the plan put it.
/// Scene: anchor at x 50..70, `item` at 100, `second` at 120, all 20 high.
@MainActor @Suite struct MoveExecutorVerifyTests {
    private let bar = MoveFakeBar()
    private let gate = InputGate()

    init() {
        place("anchor", x: 50, width: 20)
        place("item", x: 100)
        place("second", x: 120)
    }

    private func place(_ name: String, x: Double, width: Double = 10) {
        bar.frames[moveID(name)] = ItemFrame(x: x, y: 0, width: width, height: 20)
    }

    private func step(_ side: DropSide, item: String = "item") -> MoveStep {
        MoveStep(item: moveItem(item), anchor: moveID("anchor"), side: side)
    }

    private var layout: Layout {
        try! Layout(visible: [moveID("item")], hidden: [moveID("second")], groups: [])
    }

    private func run(
        _ steps: [MoveStep], locator: (any ItemLocating)? = nil, confirmed: inout Int
    ) -> MovePlanResult {
        var count = 0
        let executor = MoveExecutor(poster: bar, locator: locator ?? bar, clock: bar, inputGate: gate)
        let result = executor.execute(steps, confirming: layout) { _ in count += 1 }
        confirmed = count
        return result
    }

    /// Wait number `n` since creation puts `name` at `x`.
    private func land(_ name: String, at x: Double, onWait n: Int) {
        bar.onWait = { [bar] count in
            if count == n { bar.frames[moveID(name)] = ItemFrame(x: x, y: 0, width: 10, height: 20) }
        }
    }

    @Test func anItemThatChangedXButLandedOnTheWrongSideOfItsAnchorFailsThePlan() {
        land("item", at: 40, onWait: 1)
        var confirmed = 0

        let result = run([step(.rightOf)], confirmed: &confirmed)

        #expect(result == .stopped(stepIndex: 0, outcome: .failed))
        #expect(confirmed == 0)
        #expect(!gate.suppressUserInput)
    }

    @Test func anItemDroppedLeftOfTheAnchorMustBeLeftOfIt() {
        land("item", at: 90, onWait: 1)
        var confirmed = 0

        let result = run([step(.leftOf)], confirmed: &confirmed)

        #expect(result == .stopped(stepIndex: 0, outcome: .failed))
        #expect(confirmed == 0)
    }

    @Test func standingOnTheAnchorsXIsNotOnEitherSide() {
        var confirmed = 0
        land("item", at: 50, onWait: 1)
        #expect(run([step(.rightOf)], confirmed: &confirmed) == .stopped(stepIndex: 0, outcome: .failed))

        land("item", at: 50, onWait: 2)
        place("item", x: 100)
        #expect(run([step(.leftOf)], confirmed: &confirmed) == .stopped(stepIndex: 0, outcome: .failed))
        #expect(confirmed == 0)
    }

    @Test func theFirstStepThatNoLongerHoldsAtTheEndIsReported() {
        // Step 1 lands right of the anchor; step 2 lands, then the anchor itself moves away.
        bar.onWait = { [bar] count in
            switch count {
            case 1: bar.frames[moveID("item")] = ItemFrame(x: 75, y: 0, width: 10, height: 20)
            case 2:
                bar.frames[moveID("second")] = ItemFrame(x: 40, y: 0, width: 10, height: 20)
                bar.frames[moveID("anchor")] = ItemFrame(x: 200, y: 0, width: 20, height: 20)
            default: break
            }
        }
        var confirmed = 0

        let result = run([step(.rightOf), step(.leftOf, item: "second")], confirmed: &confirmed)

        #expect(result == .stopped(stepIndex: 0, outcome: .failed))
        #expect(confirmed == 0)
    }

    @Test func aPlanWhoseStepsAllHoldIsConfirmed() {
        bar.onWait = { [bar] count in
            let moved = count == 1 ? ("item", 75.0) : ("second", 40.0)
            bar.frames[moveID(moved.0)] = ItemFrame(x: moved.1, y: 0, width: 10, height: 20)
        }
        var confirmed = 0

        let result = run([step(.rightOf), step(.leftOf, item: "second")], confirmed: &confirmed)

        #expect(result == .confirmed)
        #expect(confirmed == 1)
    }

    @Test func anItemThatCannotBeReadAtTheEndFailsThePlan() {
        land("item", at: 75, onWait: 1)
        let locator = ScriptedLocator(bar)
        // Reads: item, anchor, one poll, then the check starts with the item.
        locator.transform = { count, frame in count == 4 ? nil : frame }
        var confirmed = 0

        let result = run([step(.rightOf)], locator: locator, confirmed: &confirmed)

        #expect(result == .stopped(stepIndex: 0, outcome: .failed))
        #expect(confirmed == 0)
    }

    @Test func anAnchorThatCannotBeReadAtTheEndFailsThePlan() {
        land("item", at: 75, onWait: 1)
        let locator = ScriptedLocator(bar)
        locator.transform = { count, frame in count == 5 ? nil : frame }
        var confirmed = 0

        let result = run([step(.rightOf)], locator: locator, confirmed: &confirmed)

        #expect(result == .stopped(stepIndex: 0, outcome: .failed))
        #expect(confirmed == 0)
    }
}
