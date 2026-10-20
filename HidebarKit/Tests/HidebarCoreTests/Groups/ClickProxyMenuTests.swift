import Foundation
import Testing

@testable import HidebarCore

/// The timeout restore drags the clicked icon away, which would close its menu: while a menu is
/// open the timeout starts over. Bar: separator 0..20, then `a`, `b`, `c` (10 wide) at 100, 120, 140.
@MainActor @Suite struct ClickProxyMenuTests {
    private let bar = MoveFakeBar()
    private let timer = ManualClock()
    private let menu = FakeMenuProbe()
    private let gate = InputGate()
    private let all = [
        discovered("a", x: 100, windowID: 1), discovered("b", x: 120, windowID: 2),
        discovered("c", x: 140, windowID: 3),
    ]

    init() {
        bar.frames[moveID("sep")] = ItemFrame(x: 0, y: 0, width: 20, height: 20)
        for (index, name) in ["a", "b", "c"].enumerated() {
            bar.frames[moveID(name)] = ItemFrame(x: 100 + Double(index) * 20, y: 0, width: 10, height: 20)
        }
    }

    private func proxy(timeout: TimeInterval = 10, maxDisplacement: TimeInterval = 120) -> ClickProxy {
        ClickProxy(
            executor: MoveExecutor(
                poster: bar, locator: bar, windows: bar, clock: bar, inputGate: gate),
            poster: bar, locator: bar, separator: moveID("sep"), revealSide: .rightOf, clock: timer,
            inputGate: gate, isMenuOpen: { [menu] in menu.isMenuOpen() }, restoreTimeout: timeout,
            maxDisplacement: maxDisplacement)
    }

    /// Reveal at the first wait, return at the second.
    private func clicked(timeout: TimeInterval = 10, maxDisplacement: TimeInterval = 120) -> ClickProxy {
        script(revealAt: 1)
        let proxy = proxy(timeout: timeout, maxDisplacement: maxDisplacement)
        #expect(proxy.click(moveID("a"), among: all) == .clicked)
        return proxy
    }

    /// Reveal at wait `count`, return at the next one.
    private func script(revealAt count: Int) {
        bar.onWait = { [bar] waits in
            let x: Double? = [count: 22, count + 1: 110][waits]
            x.map { bar.frames[moveID("a")] = ItemFrame(x: $0, y: 0, width: 10, height: 20) }
        }
    }

    @Test func anOpenMenuAtTheTimeoutKeepsTheIconAwayAndStartsTheTimeoutOver() {
        menu.isOpen = true
        let proxy = clicked()
        let drags = bar.downs.count

        timer.advance(by: 10)

        #expect(proxy.hasDisplacedItem)
        #expect(bar.downs.count == drags)
        #expect(timer.timers.count == 2)
        #expect(timer.pending.count == 1)
        #expect(menu.reads == 1)
    }

    @Test func theIconGoesHomeOnTheFirstTimeoutAfterTheMenuClosed() {
        menu.isOpen = true
        let proxy = clicked()
        timer.advance(by: 10)
        timer.advance(by: 10)
        #expect(proxy.hasDisplacedItem)
        #expect(menu.reads == 2)

        menu.isOpen = false
        timer.advance(by: 9)
        #expect(proxy.hasDisplacedItem)
        timer.advance(by: 1)

        #expect(!proxy.hasDisplacedItem)
        #expect(bar.ups.last == CursorPoint(x: 120, y: 10))
        #expect(timer.pending.isEmpty)
    }

    @Test func theTimeoutStartsOverAfterTheGivenTimeoutNotAfterTheDefault() {
        menu.isOpen = true
        let proxy = clicked(timeout: 3)
        timer.advance(by: 3)
        #expect(timer.pending.count == 1)
        menu.isOpen = false
        timer.advance(by: 2)
        #expect(menu.reads == 1)
        timer.advance(by: 1)
        #expect(menu.reads == 2)
        #expect(!proxy.hasDisplacedItem)
    }

    @Test func aMenuThatNeverClosesCannotKeepTheIconAwayPastTheMaximum() {
        menu.isOpen = true
        let proxy = clicked()

        timer.advance(by: 119)
        #expect(proxy.hasDisplacedItem)
        #expect(menu.reads == 11)

        timer.advance(by: 1)
        #expect(!proxy.hasDisplacedItem)
        #expect(menu.reads == 11)
        #expect(timer.pending.isEmpty)
    }

    @Test func aTimeoutThatWouldPassTheMaximumIsNotWaitedForAgain() {
        menu.isOpen = true
        let proxy = clicked(timeout: 50)

        timer.advance(by: 99)
        #expect(proxy.hasDisplacedItem)
        timer.advance(by: 1)

        #expect(!proxy.hasDisplacedItem)
        #expect(menu.reads == 1)
        #expect(timer.pending.isEmpty)
    }

    @Test func aTimeoutThatEndsExactlyOnTheMaximumIsTheLastOne() {
        menu.isOpen = true
        let proxy = clicked(timeout: 60)

        timer.advance(by: 60)
        #expect(proxy.hasDisplacedItem)
        timer.advance(by: 60)

        #expect(!proxy.hasDisplacedItem)
        #expect(menu.reads == 1)
    }

    @Test func theMaximumHandsOverToTheTimeoutHandlerWithTheMenuStillOpen() {
        menu.isOpen = true
        let proxy = clicked(maxDisplacement: 30)
        var calls = 0
        proxy.onRestoreTimeout = { calls += 1 }

        timer.advance(by: 29)
        #expect(calls == 0)
        timer.advance(by: 1)

        #expect(calls == 1)
        #expect(menu.reads == 2)
    }

    @Test func eachClickGetsTheWholeMaximumAgain() {
        menu.isOpen = true
        let proxy = clicked(maxDisplacement: 60)
        timer.advance(by: 50)
        #expect(proxy.menuDidClose() == .restored)

        script(revealAt: 3)
        #expect(proxy.click(moveID("a"), among: all) == .clicked)
        timer.advance(by: 59)
        #expect(proxy.hasDisplacedItem)
        timer.advance(by: 1)
        #expect(!proxy.hasDisplacedItem)
    }

    @Test func theMenuIsNotAskedAboutBeforeTheTimeout() {
        menu.isOpen = true
        let proxy = clicked()
        timer.advance(by: 9)
        #expect(menu.reads == 0)
        #expect(proxy.hasDisplacedItem)
    }

    @Test func anExplicitCloseRestoresTheIconWhateverTheProbeSays() {
        menu.isOpen = true
        let proxy = clicked()

        #expect(proxy.menuDidClose() == .restored)
        #expect(!proxy.hasDisplacedItem)
        #expect(menu.reads == 0)
    }

    @Test func theTimeoutHandlerWaitsForTheMenuToo() {
        menu.isOpen = true
        let proxy = clicked()
        var calls = 0
        proxy.onRestoreTimeout = { calls += 1 }

        timer.advance(by: 10)
        #expect(calls == 0)

        menu.isOpen = false
        timer.advance(by: 10)
        #expect(calls == 1)
    }
}
