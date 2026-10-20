import Foundation
import Testing

@testable import HidebarCore

/// Scene: separator at x 0..20, items a, b, c (10 wide, 20 high) at x 100, 120, 140.
/// Revealing `a` drops it at the separator's right edge (x 20); it lands at x 22.
@MainActor @Suite struct ClickProxyTests {
    private let bar = MoveFakeBar()
    private let saved = CursorPoint(x: 900, y: 500)
    private let all = [
        discovered("a", x: 100, windowID: 1), discovered("b", x: 120, windowID: 2),
        discovered("c", x: 140, windowID: 3),
    ]

    init() {
        gate = InputGate(uptime: bar.uptime.reader)
        place("sep", x: 0, width: 20)
        place("a", x: 100)
        place("b", x: 120)
        place("c", x: 140)
    }

    private let timer = ManualClock()
    private let gate: InputGate

    private var executor: MoveExecutor {
        MoveExecutor(poster: bar, locator: bar, windows: bar, clock: bar, inputGate: gate)
    }

    private func proxy(
        locator: (any ItemLocating)? = nil, revealSide: DropSide = .rightOf,
        timeout: TimeInterval = 10
    ) -> ClickProxy {
        ClickProxy(
            executor: executor, poster: bar, locator: locator ?? bar, separator: moveID("sep"),
            revealSide: revealSide, clock: timer, inputGate: gate, isMenuOpen: { false },
            restoreTimeout: timeout)
    }

    private func place(_ name: String, x: Double, width: Double = 10) {
        bar.frames[moveID(name)] = ItemFrame(x: x, y: 0, width: width, height: 20)
    }

    /// The `n`-th wait since creation moves `item` to the given x.
    private func moves(_ script: [Int: Double], item: String = "a") {
        bar.onWait = { [bar] count in
            if let x = script[count] { bar.frames[moveID(item)] = ItemFrame(x: x, y: 0, width: 10, height: 20) }
        }
    }

    private let revealed: [MoveEvent] = [
        .down(CommandDrag.pressPoint), .up(CursorPoint(x: 20, y: 10)), .wait(25),
        .setCursor(CursorPoint(x: 900, y: 500)),
    ]

    private func expectRefused(
        _ reason: ClickRefusal, id: String = "a", items: [DiscoveredItem]? = nil,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let proxy = proxy()
        #expect(
            proxy.click(moveID(id), among: items ?? all) == .refused(reason), sourceLocation: sourceLocation)
        #expect(bar.log.isEmpty, sourceLocation: sourceLocation)
        #expect(bar.cursorReads == 0, sourceLocation: sourceLocation)
        #expect(!proxy.hasDisplacedItem, sourceLocation: sourceLocation)
        #expect(timer.timers.isEmpty, sourceLocation: sourceLocation)
    }

    // MARK: happy path

    @Test func revealsClicksAtTheNewCentreThenReturnsTheItemNextToItsRightNeighbour() {
        moves([1: 22, 2: 110])
        let proxy = proxy()
        #expect(proxy.click(moveID("a"), among: all) == .clicked)
        #expect(proxy.hasDisplacedItem)
        #expect(
            bar.log == revealed + [.click(CursorPoint(x: 27, y: 10)), .setCursor(saved)])

        #expect(proxy.menuDidClose() == .restored)
        #expect(!proxy.hasDisplacedItem)
        #expect(
            bar.log == revealed + [
                .click(CursorPoint(x: 27, y: 10)), .setCursor(saved),
                .down(CommandDrag.pressPoint), .up(CursorPoint(x: 120, y: 10)), .wait(25),
                .setCursor(saved),
            ])
        #expect(bar.cursor == saved)
    }

    @Test func revealingToTheLeftOfTheSeparatorDropsAtItsLeftEdge() {
        moves([1: 2])
        #expect(proxy(revealSide: .leftOf).click(moveID("a"), among: all) == .clicked)
        #expect(bar.ups == [CursorPoint(x: 0, y: 10)])
    }

    @Test func rightmostItemGoesBackToTheRightOfItsNearestLeftNeighbour() {
        moves([1: 22, 2: 150], item: "c")
        let proxy = proxy()
        #expect(proxy.click(moveID("c"), among: all) == .clicked)
        #expect(proxy.menuDidClose() == .restored)
        #expect(bar.ups == [CursorPoint(x: 20, y: 10), CursorPoint(x: 130, y: 10)])
    }

    @Test func unmanagedNeighboursAreNeverUsedAsTheHomeAnchor() {
        moves([1: 22, 2: 110])
        let items = [
            discovered("a", x: 100), discovered("b", x: 120, managed: false), discovered("c", x: 140),
        ]
        let proxy = proxy()
        #expect(proxy.click(moveID("a"), among: items) == .clicked)
        #expect(proxy.menuDidClose() == .restored)
        #expect(bar.ups.last == CursorPoint(x: 140, y: 10))

        // `a` now sits at x 110, so the nearest managed icon on the left of `c` ends at 120.
        moves([3: 22, 4: 150], item: "c")
        #expect(proxy.click(moveID("c"), among: items) == .clicked)
        #expect(proxy.menuDidClose() == .restored)
        #expect(bar.ups.last == CursorPoint(x: 120, y: 10))
    }

    @Test func neighbourAtTheSameXCountsAsLeft() {
        place("b", x: 100)
        moves([1: 22, 2: 110])
        let items = [discovered("a", x: 100), discovered("b", x: 100)]
        let proxy = proxy()
        #expect(proxy.click(moveID("a"), among: items) == .clicked)
        #expect(proxy.menuDidClose() == .restored)
        #expect(bar.ups.last == CursorPoint(x: 110, y: 10))
    }

    // MARK: refusals

    @Test func itemAbsentFromTheListIsRefusedWithoutEvents() {
        expectRefused(.notManaged, id: "gone")
    }

    @Test func unmanagedItemIsRefusedEvenWhenItsIdMatches() {
        expectRefused(.notManaged, items: [discovered("a", x: 100, managed: false), discovered("b", x: 120)])
    }

    @Test func unmovableItemIsRefusedWithoutEvents() {
        expectRefused(.unmovable, items: [discovered("a", x: 100, movable: false), discovered("b", x: 120)])
    }

    @Test func itemWithoutAManagedNeighbourIsRefusedBecauseItCouldNotBeReturned() {
        expectRefused(.noHomeAnchor, items: [discovered("a", x: 100)])
        expectRefused(.noHomeAnchor, items: [discovered("a", x: 100), discovered("b", x: 120, managed: false)])
    }

    @Test func itemTheBarCannotLocateIsRefusedWithoutEvents() {
        bar.frames[moveID("a")] = nil
        expectRefused(.notLocated)
    }

    @Test func secondClickIsRefusedWhileAnItemIsAwayAndAllowedAfterItReturned() {
        moves([1: 22, 2: 110])
        let proxy = proxy()
        #expect(proxy.click(moveID("a"), among: all) == .clicked)
        let events = bar.log.count
        #expect(proxy.click(moveID("b"), among: all) == .refused(.displacedItemPending))
        #expect(bar.log.count == events)
        #expect(proxy.menuDidClose() == .restored)
        #expect(proxy.click(moveID("b"), among: all) == .revealFailed)
    }

    // MARK: failures leave the item in its place

    @Test func revealThatNeverMovesTheItemEndsWithoutAReturnDragOrAClick() {
        let proxy = proxy()
        #expect(proxy.click(moveID("a"), among: all) == .revealFailed)
        #expect(bar.downs.count == 3)
        #expect(bar.clicks.isEmpty)
        #expect(!proxy.hasDisplacedItem)
        #expect(timer.timers.isEmpty)
        #expect(proxy.menuDidClose() == .nothingToRestore)
        #expect(bar.cursor == saved)
    }

    @Test func revealThatMovesTheItemTooLateIsDraggedBackAndRetriedOnClose() {
        let locator = ScriptedLocator(bar)
        locator.transform = { count, frame in
            guard let frame else { return nil }
            return count >= 2 ? ItemFrame(x: 22, y: 0, width: frame.width, height: frame.height) : frame
        }
        let proxy = proxy(locator: locator)
        #expect(proxy.click(moveID("a"), among: all) == .revealFailed)
        #expect(bar.downs.count == 6)
        #expect(bar.clicks.isEmpty)
        #expect(proxy.hasDisplacedItem)

        moves([61: 110])
        #expect(proxy.menuDidClose() == .restored)
        #expect(!proxy.hasDisplacedItem)
        #expect(bar.ups.last == CursorPoint(x: 120, y: 10))
        #expect(bar.cursor == saved)
    }

    @Test func failedClickStillReturnsTheItemAndTheCursor() {
        bar.clickPosts = false
        moves([1: 22, 2: 110])
        let proxy = proxy()
        #expect(proxy.click(moveID("a"), among: all) == .clickFailed)
        #expect(!proxy.hasDisplacedItem)
        #expect(timer.timers.isEmpty)
        #expect(
            bar.log == revealed + [
                .click(CursorPoint(x: 27, y: 10)), .setCursor(saved),
                .down(CommandDrag.pressPoint), .up(CursorPoint(x: 120, y: 10)), .wait(25),
                .setCursor(saved),
            ])
    }

    @Test func failedClickWithAStuckReturnKeepsTheItemPendingUntilItCanBeReturned() {
        bar.clickPosts = false
        moves([1: 22])
        let proxy = proxy()
        #expect(proxy.click(moveID("a"), among: all) == .clickFailed)
        #expect(proxy.hasDisplacedItem)
        #expect(bar.cursor == saved)

        #expect(proxy.menuDidClose() == .failed)
        #expect(proxy.hasDisplacedItem)
        moves([62: 110])
        #expect(proxy.menuDidClose() == .restored)
        #expect(!proxy.hasDisplacedItem)
    }

    @Test func itemThatVanishesBeforeTheClickIsNotClickedAndNothingIsLeftPending() {
        let locator = ScriptedLocator(bar)
        locator.transform = { count, frame in count >= 2 ? nil : frame }
        moves([1: 22])
        let proxy = proxy(locator: locator)
        #expect(proxy.click(moveID("a"), among: all) == .clickFailed)
        #expect(bar.log == revealed)
        #expect(bar.clicks.isEmpty)
        #expect(!proxy.hasDisplacedItem)
    }

    // MARK: input gate

    @Test func userInputStaysSuppressedFromTheRevealThroughTheCursorRestore() {
        bar.gate = gate
        moves([1: 22])
        #expect(proxy().click(moveID("a"), among: all) == .clicked)
        // Every lookup, wait, cursor access and posted event of the click was sampled. The first
        // sample is the lookup that decides whether to refuse, before any event can be posted.
        #expect(bar.gateSamples.count == bar.lookups + bar.cursorReads + bar.log.count)
        #expect(bar.gateSamples.dropFirst().allSatisfy { $0 })
        #expect(!gate.suppressUserInput)
    }

    @Test func gateIsReleasedWhenTheRevealFails() {
        #expect(proxy().click(moveID("a"), among: all) == .revealFailed)
        #expect(!gate.suppressUserInput)
    }

    @Test func clickIsNotPostedOnceTheGateHasRunOutAndTheItemStaysPendingForTheNextTry() {
        bar.onWait = { [bar] count in
            bar.uptime.advance(by: InputGate.defaultMaxSuppressionMilliseconds)
            if count == 1 { bar.frames[moveID("a")] = ItemFrame(x: 22, y: 0, width: 10, height: 20) }
        }
        let proxy = proxy()
        #expect(proxy.click(moveID("a"), among: all) == .clickFailed)
        #expect(bar.clicks.isEmpty)
        #expect(proxy.hasDisplacedItem)
        #expect(!gate.suppressUserInput)
    }

    @Test func gateIsReleasedWhenTheClickFails() {
        bar.clickPosts = false
        moves([1: 22, 2: 110])
        #expect(proxy().click(moveID("a"), among: all) == .clickFailed)
        #expect(!gate.suppressUserInput)
    }

    // MARK: onRestoreTimeout

    @Test func timeoutHandlerRunsInsteadOfTheProxysOwnRestore() {
        moves([1: 22, 2: 110])
        let proxy = proxy()
        var calls = 0
        proxy.onRestoreTimeout = { calls += 1 }
        #expect(proxy.click(moveID("a"), among: all) == .clicked)
        let events = bar.log.count

        timer.advance(by: 9)
        #expect(calls == 0)
        timer.advance(by: 1)
        #expect(calls == 1)
        #expect(proxy.hasDisplacedItem)
        #expect(bar.log.count == events)
    }

    @Test func itemIsStillReturnedByTheHandlerCallingRestore() {
        moves([1: 22, 2: 110])
        let proxy = proxy()
        proxy.onRestoreTimeout = { proxy.restoreIfDisplaced() }
        #expect(proxy.click(moveID("a"), among: all) == .clicked)
        timer.advance(by: 10)
        #expect(!proxy.hasDisplacedItem)
    }

    // MARK: restoreIfDisplaced

    @Test func restoreWithNothingAwayDoesNothing() {
        #expect(proxy().restoreIfDisplaced() == .nothingToRestore)
        #expect(bar.log.isEmpty)
    }

    @Test func restoreRetriesAReturnThatFailedOnTheTimeout() {
        moves([1: 22])
        let proxy = proxy()
        #expect(proxy.click(moveID("a"), among: all) == .clicked)
        timer.advance(by: 10)
        #expect(proxy.hasDisplacedItem)

        moves([32: 110])
        #expect(proxy.restoreIfDisplaced() == .restored)
        #expect(!proxy.hasDisplacedItem)
        #expect(bar.ups.last == CursorPoint(x: 120, y: 10))
        #expect(bar.cursor == saved)
    }

    @Test func restoreThatKeepsFailingLeavesTheItemPendingForTheNextTry() {
        moves([1: 22])
        let proxy = proxy()
        #expect(proxy.click(moveID("a"), among: all) == .clicked)
        #expect(proxy.restoreIfDisplaced() == .failed)
        #expect(proxy.hasDisplacedItem)
        #expect(proxy.click(moveID("b"), among: all) == .refused(.displacedItemPending))
    }

    // MARK: menuDidClose

    @Test func closeWithNothingAwayDoesNothing() {
        #expect(proxy().menuDidClose() == .nothingToRestore)
        #expect(bar.log.isEmpty)
        #expect(bar.cursorReads == 0)
    }

    @Test func closeWhenTheItemAlreadyBackAtItsOriginalPlaceDoesNotDragIt() {
        moves([1: 22])
        let proxy = proxy()
        #expect(proxy.click(moveID("a"), among: all) == .clicked)
        place("a", x: 100)
        let events = bar.log.count
        #expect(proxy.menuDidClose() == .nothingToRestore)
        #expect(!proxy.hasDisplacedItem)
        #expect(bar.log.count == events)
    }

    @Test func closeWhenTheItemHasVanishedClearsThePendingReturn() {
        moves([1: 22])
        let proxy = proxy()
        #expect(proxy.click(moveID("a"), among: all) == .clicked)
        bar.frames[moveID("a")] = nil
        let events = bar.log.count
        #expect(proxy.menuDidClose() == .nothingToRestore)
        #expect(!proxy.hasDisplacedItem)
        #expect(bar.log.count == events)
    }

    @Test func failedReturnOnCloseKeepsTheItemPending() {
        moves([1: 22])
        let proxy = proxy()
        #expect(proxy.click(moveID("a"), among: all) == .clicked)
        #expect(proxy.menuDidClose() == .failed)
        #expect(proxy.hasDisplacedItem)
        #expect(bar.cursor == saved)
        #expect(proxy.click(moveID("b"), among: all) == .refused(.displacedItemPending))
    }

    // MARK: timeout restore

    /// Reveal at the first wait, return at the second.
    private func clickedWithATimer(timeout: TimeInterval = 10) -> ClickProxy {
        moves([1: 22, 2: 110])
        let proxy = proxy(timeout: timeout)
        #expect(proxy.click(moveID("a"), among: all) == .clicked)
        return proxy
    }

    @Test func clickedItemIsReturnedWhenTheMenuNeverReportsClosing() {
        let proxy = clickedWithATimer()
        #expect(timer.pending.count == 1)
        timer.advance(by: 9)
        #expect(proxy.hasDisplacedItem)
        #expect(bar.downs.count == 1)

        timer.advance(by: 1)
        #expect(!proxy.hasDisplacedItem)
        #expect(bar.downs == [CommandDrag.pressPoint, CommandDrag.pressPoint])
        #expect(bar.ups.last == CursorPoint(x: 120, y: 10))
        #expect(bar.cursor == saved)
    }

    @Test func timeoutIsTheOneGivenToTheProxy() {
        let proxy = clickedWithATimer(timeout: 3)
        timer.advance(by: 2)
        #expect(proxy.hasDisplacedItem)
        timer.advance(by: 1)
        #expect(!proxy.hasDisplacedItem)
    }

    @Test func menuClosingBeforeTheTimeoutWithdrawsTheTimer() {
        let proxy = clickedWithATimer()
        let scheduled = timer.timers[0]
        #expect(proxy.menuDidClose() == .restored)
        #expect(scheduled.cancelCount == 1)
        #expect(timer.pending.isEmpty)
        let events = bar.log.count
        timer.advance(by: 100)
        #expect(bar.log.count == events)
    }

    @Test func closingTwiceCancelsTheTimerOnlyOnce() {
        let proxy = clickedWithATimer()
        let scheduled = timer.timers[0]
        proxy.menuDidClose()
        proxy.menuDidClose()
        #expect(scheduled.cancelCount == 1)
    }

    @Test func timeoutRestoreRunsOnceEvenWhenItFails() {
        moves([1: 22])
        let proxy = proxy()
        #expect(proxy.click(moveID("a"), among: all) == .clicked)
        timer.advance(by: 10)
        #expect(proxy.hasDisplacedItem)
        let drags = bar.downs.count
        timer.advance(by: 100)
        #expect(bar.downs.count == drags)
        #expect(timer.pending.isEmpty)

        moves([32: 110])
        #expect(proxy.menuDidClose() == .restored)
    }

    @Test func eachClickGetsItsOwnTimer() {
        let proxy = clickedWithATimer()
        timer.advance(by: 10)
        #expect(timer.timers.count == 1)

        moves([3: 22, 4: 130], item: "b")
        #expect(proxy.click(moveID("b"), among: all) == .clicked)
        #expect(timer.timers.count == 2)
        timer.advance(by: 9)
        #expect(proxy.hasDisplacedItem)
        timer.advance(by: 1)
        #expect(!proxy.hasDisplacedItem)
    }

    @Test func refusedSecondClickLeavesTheRunningTimerAlone() {
        let proxy = clickedWithATimer()
        #expect(proxy.click(moveID("b"), among: all) == .refused(.displacedItemPending))
        #expect(timer.timers.count == 1)
        #expect(timer.pending.count == 1)
    }

    @Test func timerFiringAfterTheProxyIsGoneDoesNothing() {
        var proxy: ClickProxy? = clickedWithATimer()
        #expect(proxy != nil)
        proxy = nil
        let events = bar.log.count
        timer.advance(by: 10)
        #expect(bar.log.count == events)
    }
}
