public enum MoveOutcome: Equatable, Sendable {
    /// The item's frame changed after the drag.
    case moved
    /// The item must not be dragged. No event was posted and the cursor was not touched.
    case unmovable
    /// Every attempt left the item where it was, or the item or its anchor could not be located.
    case failed
}

public enum MovePlanResult: Equatable, Sendable {
    /// Every step moved its item and the layout was handed to `onConfirmed`.
    case confirmed
    /// Step `stepIndex` ended with `outcome` and nothing was confirmed. Later steps did not run,
    /// except when every step moved but the final check failed: then `outcome` is `.failed` and
    /// `stepIndex` is the first step whose item is not where the step put it.
    case stopped(stepIndex: Int, outcome: MoveOutcome)
}

/// Drags menu bar items with synthetic Command-clicks, the way Ice does: Command-down aimed at the
/// item's window, Command-up aimed at the anchor's window at its edge, then poll until the item's
/// frame changes.
///
/// Rules held here: an unmovable item gets no events at all; every attempt that posts events puts
/// the cursor back where it was, whether or not the item moved; a layout is handed to
/// `onConfirmed` only after the whole plan is confirmed by the items' own frames; user input is
/// suppressed by the `InputGate` from the first drag until the plan ends, on every path; once the
/// gate is overdue no attempt, poll or drag starts, so a stuck move ends as `.failed`. The check
/// before a drag comes after the frame reads, which are what can take long.
@MainActor
public final class MoveExecutor {
    /// Extra attempts after the first one, so an item is dragged at most `maxRetries + 1` times.
    public static let maxRetries = 2
    /// Frame polls after one drag.
    public static let pollLimit = 10
    /// Asks for the windows a drag names, per attempt, while the bar re-lays out.
    public static let windowPollLimit = 10
    public static let pollIntervalMilliseconds = 25

    private let poster: any EventPosting
    private let locator: any ItemLocating
    private let windows: any WindowLocating
    private let clock: any MoveClock
    private let inputGate: InputGate

    /// `locator` tells where an item is (to see it move), `windows` which window to name in the
    /// drag. `inputGate` is the one the event tap adapter consults; it has no default, so a
    /// composition cannot leave rule 4 switched off by forgetting it.
    public init(
        poster: any EventPosting, locator: any ItemLocating, windows: any WindowLocating,
        clock: any MoveClock, inputGate: InputGate
    ) {
        self.poster = poster
        self.locator = locator
        self.windows = windows
        self.clock = clock
        self.inputGate = inputGate
    }

    public func move(_ step: MoveStep) -> MoveOutcome {
        guard step.item.isMovable else { return .unmovable }
        inputGate.begin()
        defer { inputGate.end() }
        for _ in 0...Self.maxRetries {
            guard !inputGate.isOverdue else { return .failed }
            if attempt(step) { return .moved }
        }
        return .failed
    }

    /// Runs `steps` in order and stops at the first one that is not `.moved`.
    ///
    /// `onConfirmed` is called once, with `layout`, after the last step; it is the place to persist.
    /// An error it throws propagates: the items did move, but the layout was not saved.
    public func execute(
        _ steps: [MoveStep], confirming layout: Layout, onConfirmed: (Layout) throws -> Void
    ) rethrows -> MovePlanResult {
        inputGate.begin()
        defer { inputGate.end() }
        return try run(steps, confirming: layout, onConfirmed: onConfirmed)
    }

    private func run(
        _ steps: [MoveStep], confirming layout: Layout, onConfirmed: (Layout) throws -> Void
    ) rethrows -> MovePlanResult {
        for (index, step) in steps.enumerated() {
            let outcome = move(step)
            guard outcome == .moved else { return .stopped(stepIndex: index, outcome: outcome) }
        }
        if let misplaced = steps.firstIndex(where: { !isInPlace($0) }) {
            return .stopped(stepIndex: misplaced, outcome: .failed)
        }
        try onConfirmed(layout)
        return .confirmed
    }

    /// A step counts as done when its item changed x, but a neighbour that changed width moves
    /// items too. Read again once the plan is over: the item must sit on its side of the anchor.
    private func isInPlace(_ step: MoveStep) -> Bool {
        guard let item = locator.frame(of: step.item.id), let anchor = locator.frame(of: step.anchor)
        else { return false }
        switch step.side {
        case .leftOf: return item.x < anchor.x
        case .rightOf: return item.x > anchor.x
        }
    }

    private func attempt(_ step: MoveStep) -> Bool {
        let id = step.item.id
        guard let before = locator.frame(of: id),
            let (item, anchor) = awaitWindows(of: id, and: step.anchor)
        else { return false }
        let savedCursor = poster.cursorPosition()
        defer { poster.setCursorPosition(savedCursor) }
        guard !inputGate.isOverdue else { return false }
        let posted = poster.postCommandDrag(CommandDrag(item: item, anchor: anchor, side: step.side))
        return posted && awaitMove(of: id, from: before)
    }

    /// Windows of the item and of the anchor. A bar that is still re-laying out after the last
    /// drag may not have them yet, so they are asked for again, at most `windowPollLimit` times.
    private func awaitWindows(
        of item: MenuBarItemID, and anchor: MenuBarItemID
    ) -> (item: WindowTarget, anchor: WindowTarget)? {
        for _ in 0..<Self.windowPollLimit {
            guard !inputGate.isOverdue else { return nil }
            if let found = windows.window(of: item), let beside = windows.window(of: anchor) {
                return (found, beside)
            }
            clock.wait(milliseconds: Self.pollIntervalMilliseconds)
        }
        return nil
    }

    private func awaitMove(of id: MenuBarItemID, from before: ItemFrame) -> Bool {
        for _ in 0..<Self.pollLimit {
            guard !inputGate.isOverdue else { return false }
            clock.wait(milliseconds: Self.pollIntervalMilliseconds)
            if let now = locator.frame(of: id), now.x != before.x { return true }
        }
        return false
    }
}
