import Testing

@testable import HidebarCore

/// The gate gives up after 1000 ms; a move that is stuck on slow reads must stop, not start over.
@MainActor @Suite struct MoveExecutorDeadlineTests {
    private let bar = MoveFakeBar()
    private let gate: InputGate
    private let executor: MoveExecutor

    init() {
        gate = InputGate(maxSuppressionMilliseconds: 1000, uptime: bar.uptime.reader)
        executor = MoveExecutor(
            poster: bar, locator: bar, windows: bar, clock: bar, inputGate: gate)
        bar.frames[moveID("item")] = ItemFrame(x: 100, y: 0, width: 10, height: 20)
        bar.frames[moveID("other")] = ItemFrame(x: 200, y: 0, width: 10, height: 20)
        bar.frames[moveID("anchor")] = ItemFrame(x: 50, y: 0, width: 20, height: 20)
    }

    private func step(_ name: String = "item") -> MoveStep {
        MoveStep(item: moveItem(name), anchor: moveID("anchor"), side: .rightOf)
    }

    private var layout: Layout {
        try! Layout(visible: [moveID("item")], hidden: [], groups: [])
    }

    @Test func slowReadsEndTheMoveAsFailedWithoutAnotherAttempt() {
        bar.readCost = 300

        #expect(executor.move(step()) == .failed)

        // Attempt 1 reads one frame (300) and polls three times (625, 950, 1275); the fourth poll
        // and a second attempt are refused.
        #expect(bar.downs.count == 1)
        #expect(bar.waits == 3)
        #expect(bar.restores == [bar.cursor])
        #expect(!gate.suppressUserInput)
        #expect(!gate.isOverdue)
    }

    @Test func noDragIsPostedWhenTheReadsBeforeItOutlastedTheGate() {
        bar.readCost = 1100

        #expect(executor.move(step()) == .failed)

        // The gate was fresh when the attempt began; the read used it up. Nothing was touched.
        #expect(bar.downs.isEmpty)
        #expect(bar.waits == 0)
        #expect(bar.restores.isEmpty)
        #expect(!gate.suppressUserInput)
    }

    @Test func waitingForAWindowStopsOnceTheGateIsOverdue() {
        bar.windowless = [moveID("anchor")]
        bar.onWait = { [bar] _ in bar.uptime.advance(by: 5000) }

        #expect(executor.move(step()) == .failed)

        #expect(bar.waits == 1)
        #expect(bar.downs.isEmpty)
        #expect(!gate.suppressUserInput)
    }

    @Test func aPlanThatRunsOutOfTimeStopsBeforeTheNextStepAndConfirmsNothing() {
        bar.onWait = { [bar] _ in
            bar.uptime.advance(by: 5000)
            bar.frames[moveID("item")] = ItemFrame(x: 60, y: 0, width: 10, height: 20)
        }
        var confirmed = false

        let result = executor.execute([step(), step("other")], confirming: layout) { _ in
            confirmed = true
        }

        #expect(result == .stopped(stepIndex: 1, outcome: .failed))
        #expect(!confirmed)
        #expect(bar.downs.count == 1)
        #expect(!gate.suppressUserInput)
    }

    @Test func aMoveInsideTheBoundIsNotCutShort() {
        bar.readCost = 10
        bar.onWait = { [bar] _ in
            bar.frames[moveID("item")] = ItemFrame(x: 60, y: 0, width: 10, height: 20)
        }

        #expect(executor.move(step()) == .moved)
        #expect(bar.downs.count == 1)
    }
}
