import Testing

@testable import HidebarCore

private struct PersistError: Error {}

/// Poster, locator and clock in one: records whether the gate was closed at every call and moves
/// the item on the first wait, so a move succeeds.
@MainActor
private final class GateProbe: EventPosting, ItemLocating, WindowLocating, MoveClock {
    let gate: InputGate
    private(set) var samples: [Bool] = []
    private var frames: [MenuBarItemID: ItemFrame] = [
        moveID("item"): ItemFrame(x: 100, y: 0, width: 10, height: 20),
        moveID("anchor"): ItemFrame(x: 50, y: 0, width: 20, height: 20),
    ]

    init(gate: InputGate) { self.gate = gate }

    private func sample() { samples.append(gate.suppressUserInput) }

    func cursorPosition() -> CursorPoint { sample(); return CursorPoint(x: 0, y: 0) }
    func setCursorPosition(_ point: CursorPoint) { sample() }
    func postCommandDrag(_ drag: CommandDrag) -> Bool { sample(); return true }
    func postClick(at point: CursorPoint) -> Bool { sample(); return true }
    func frame(of id: MenuBarItemID) -> ItemFrame? { sample(); return frames[id] }

    func window(of id: MenuBarItemID) -> WindowTarget? {
        sample()
        return frames[id].map { WindowTarget(windowID: 1, ownerPID: 688, frame: $0) }
    }

    func wait(milliseconds: Int) {
        sample()
        frames[moveID("item")] = ItemFrame(x: 60, y: 0, width: 10, height: 20)
    }
}

@MainActor @Suite struct MoveExecutorGateTests {
    private let gate = InputGate()
    private let probe: GateProbe
    private let executor: MoveExecutor

    init() {
        probe = GateProbe(gate: gate)
        executor = MoveExecutor(
            poster: probe, locator: probe, windows: probe, clock: probe, inputGate: gate)
    }

    private func step(movable: Bool = true) -> MoveStep {
        MoveStep(item: moveItem("item", movable: movable), anchor: moveID("anchor"), side: .rightOf)
    }

    private var layout: Layout {
        try! Layout(visible: [moveID("item")], hidden: [], groups: [])
    }

    @Test func moveSuppressesUserInputThroughoutAndReleasesIt() {
        #expect(executor.move(step()) == .moved)
        #expect(!probe.samples.isEmpty)
        #expect(probe.samples.allSatisfy { $0 })
        #expect(!gate.suppressUserInput)
    }

    @Test func failedMoveReleasesTheGate() {
        let stuck = MoveStep(item: moveItem("item"), anchor: moveID("missing"), side: .leftOf)
        #expect(executor.move(stuck) == .failed)
        #expect(!gate.suppressUserInput)
    }

    @Test func unmovableItemNeverClosesTheGate() {
        #expect(executor.move(step(movable: false)) == .unmovable)
        #expect(probe.samples.isEmpty)
        #expect(!gate.suppressUserInput)
    }

    @Test func planKeepsTheGateClosedUntilTheLayoutIsPersisted() {
        var closedWhenPersisting: [Bool] = []
        let result = executor.execute([step()], confirming: layout) { _ in
            closedWhenPersisting.append(gate.suppressUserInput)
        }
        #expect(result == .confirmed)
        #expect(closedWhenPersisting == [true])
        #expect(!gate.suppressUserInput)
    }

    @Test func stoppedPlanReleasesTheGate() {
        let result = executor.execute([step(movable: false)], confirming: layout) { _ in }
        #expect(result == .stopped(stepIndex: 0, outcome: .unmovable))
        #expect(!gate.suppressUserInput)
    }

    @Test func persistErrorStillReleasesTheGate() {
        #expect(throws: PersistError.self) {
            try executor.execute([step()], confirming: layout) { _ in throw PersistError() }
        }
        #expect(!gate.suppressUserInput)
    }

    @Test func emptyPlanReleasesTheGate() {
        _ = executor.execute([], confirming: layout) { _ in }
        #expect(!gate.suppressUserInput)
    }
}
