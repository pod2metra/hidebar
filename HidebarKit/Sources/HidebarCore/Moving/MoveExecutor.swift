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
    /// Step `stepIndex` ended with `outcome`; later steps did not run and nothing was confirmed.
    case stopped(stepIndex: Int, outcome: MoveOutcome)
}

/// Drags menu bar items with synthetic Command-clicks, the way Ice does: Command-down on the item,
/// Command-up at the edge of the anchor, then poll until the item's frame changes.
///
/// Rules held here: an unmovable item gets no events at all; every attempt that posts events puts
/// the cursor back where it was, whether or not the item moved; a layout is handed to
/// `onConfirmed` only after the whole plan is confirmed by the items' own frames.
@MainActor
public final class MoveExecutor {
    /// Extra attempts after the first one, so an item is dragged at most `maxRetries + 1` times.
    public static let maxRetries = 2
    /// Frame polls after one drag.
    public static let pollLimit = 10
    public static let pollIntervalMilliseconds = 25

    private let poster: any EventPosting
    private let locator: any ItemLocating
    private let clock: any MoveClock

    public init(poster: any EventPosting, locator: any ItemLocating, clock: any MoveClock) {
        self.poster = poster
        self.locator = locator
        self.clock = clock
    }

    public func move(_ step: MoveStep) -> MoveOutcome {
        guard step.item.isMovable else { return .unmovable }
        for _ in 0...Self.maxRetries {
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
        for (index, step) in steps.enumerated() {
            let outcome = move(step)
            guard outcome == .moved else { return .stopped(stepIndex: index, outcome: outcome) }
        }
        try onConfirmed(layout)
        return .confirmed
    }

    private func attempt(_ step: MoveStep) -> Bool {
        let id = step.item.id
        guard let before = locator.frame(of: id), let anchor = locator.frame(of: step.anchor) else {
            return false
        }
        let savedCursor = poster.cursorPosition()
        defer { poster.setCursorPosition(savedCursor) }
        let y = before.y + before.height / 2
        poster.postCommandMouseDown(at: CursorPoint(x: before.x + before.width / 2, y: y))
        poster.postCommandMouseUp(at: CursorPoint(x: dropX(step.side, anchor: anchor), y: y))
        return awaitMove(of: id, from: before)
    }

    private func dropX(_ side: DropSide, anchor: ItemFrame) -> Double {
        switch side {
        case .leftOf: anchor.x
        case .rightOf: anchor.x + anchor.width
        }
    }

    private func awaitMove(of id: MenuBarItemID, from before: ItemFrame) -> Bool {
        for _ in 0..<Self.pollLimit {
            clock.wait(milliseconds: Self.pollIntervalMilliseconds)
            if let now = locator.frame(of: id), now.x != before.x { return true }
        }
        return false
    }
}
