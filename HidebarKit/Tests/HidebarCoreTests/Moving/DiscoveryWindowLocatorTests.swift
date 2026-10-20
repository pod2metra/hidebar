import Testing

@testable import HidebarCore

@MainActor @Suite struct DiscoveryWindowLocatorTests {
    private func locator(
        _ found: [DiscoveredItem], windows: [WindowInfo] = []
    ) -> DiscoveryWindowLocator {
        DiscoveryWindowLocator(discover: { found }, windowList: StubWindowList(list: windows))
    }

    /// Reads the bar from `bar.found` each time, so a test can change what discovery sees.
    private final class Bar: @unchecked Sendable {
        var found: [DiscoveredItem] = []
        var windows: [WindowInfo] = []
    }

    private func locator(_ bar: Bar) -> DiscoveryWindowLocator {
        DiscoveryWindowLocator(
            discover: { bar.found }, windowList: SwitchingWindowList { bar.windows })
    }

    @Test func managedItemIsFoundWithItsWindowNumberOwnerAndFrame() {
        let found = locator([managed(moveID("a"), windowID: 7)]).window(of: moveID("a"))
        #expect(
            found
                == WindowTarget(
                    windowID: 7, ownerPID: 688, frame: ItemFrame(x: 0, y: 0, width: 46, height: 24)))
    }

    @Test func ifTwoManagedItemsShareAnIdTheFirstOneIsUsed() {
        let twins = [managed(moveID("a"), windowID: 7), managed(moveID("a"), windowID: 9)]
        #expect(locator(twins).window(of: moveID("a"))?.windowID == 7)
    }

    @Test func unmanagedItemHasNoWindowToName() {
        #expect(locator([unmanaged(moveID("a"))]).window(of: moveID("a")) == nil)
    }

    @Test func itemThatIsNotOnTheBarHasNoWindow() {
        #expect(locator([managed(moveID("a"))]).window(of: moveID("b")) == nil)
    }

    @Test func eachLookupReadsTheBarAgain() {
        var reads = 0
        let locator = DiscoveryWindowLocator(
            discover: {
                reads += 1
                return []
            }, windowList: StubWindowList(list: []))
        _ = locator.window(of: moveID("a"))
        _ = locator.window(of: moveID("a"))
        #expect(reads == 2)
    }

    // MARK: while the bar re-lays out

    @Test func anItemDiscoveryLosesIsFoundByTheWindowNumberSeenBefore() {
        let bar = Bar()
        let locator = locator(bar)
        bar.found = [managed(moveID("a"), windowID: 7), managed(moveID("b"), windowID: 8)]
        #expect(locator.window(of: moveID("a"))?.windowID == 7)

        bar.found = []
        bar.windows = [window(8, x: 300, width: 40, ownerPID: 99)]
        #expect(
            locator.window(of: moveID("b"))
                == WindowTarget(
                    windowID: 8, ownerPID: 99, frame: ItemFrame(x: 300, y: 0, width: 40, height: 24)))
    }

    @Test func aLookupRemembersEveryManagedItemItSaw() {
        let bar = Bar()
        let locator = locator(bar)
        bar.found = [managed(moveID("a"), windowID: 7), managed(moveID("b"), windowID: 8)]
        _ = locator.window(of: moveID("a"))
        bar.found = []
        bar.windows = [window(8, x: 300)]
        #expect(locator.window(of: moveID("b"))?.windowID == 8)
    }

    @Test func aNumberNeverSeenIsNotGuessed() {
        let bar = Bar()
        bar.windows = [window(8, x: 300)]
        #expect(locator(bar).window(of: moveID("b")) == nil)
    }

    @Test func aRememberedWindowThatIsGoneIsNotFound() {
        let bar = Bar()
        let locator = locator(bar)
        bar.found = [managed(moveID("a"), windowID: 7)]
        _ = locator.window(of: moveID("a"))
        bar.found = []
        bar.windows = [window(9, x: 300)]
        #expect(locator.window(of: moveID("a")) == nil)
    }

    @Test func anUnmanagedItemIsNotRemembered() {
        let bar = Bar()
        let locator = locator(bar)
        bar.found = [unmanaged(moveID("a"), windowID: 7)]
        _ = locator.window(of: moveID("a"))
        bar.found = []
        bar.windows = [window(7, x: 300)]
        #expect(locator.window(of: moveID("a")) == nil)
    }

    @Test func onlyTheRememberedNumberMatchesAmongSmallerAndLargerOnes() {
        let bar = Bar()
        let locator = locator(bar)
        bar.found = [managed(moveID("a"), windowID: 7)]
        _ = locator.window(of: moveID("a"))
        bar.found = []
        bar.windows = [window(3, x: 10), window(11, x: 20), window(7, x: 30), window(5, x: 40)]
        #expect(locator.window(of: moveID("a"))?.windowID == 7)
    }

    @Test func aNewerWindowNumberReplacesTheRememberedOne() {
        let bar = Bar()
        let locator = locator(bar)
        bar.found = [managed(moveID("a"), windowID: 7)]
        _ = locator.window(of: moveID("a"))
        bar.found = [managed(moveID("a"), windowID: 9)]
        _ = locator.window(of: moveID("a"))
        bar.found = []
        bar.windows = [window(7, x: 100), window(9, x: 200)]
        #expect(locator.window(of: moveID("a"))?.windowID == 9)
    }
}

/// A window list whose content a test can change between reads.
struct SwitchingWindowList: WindowListProvider {
    let read: @Sendable () -> [WindowInfo]
    func windows() -> [WindowInfo] { read() }
}
