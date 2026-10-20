import Synchronization
import Testing

@testable import HidebarCore

/// A window list the test can change between calls.
private final class MutableWindowList: WindowListProvider {
    private let list: Mutex<[WindowInfo]>
    init(_ windows: [WindowInfo]) { list = Mutex(windows) }
    func set(_ windows: [WindowInfo]) { list.withLock { $0 = windows } }
    func windows() -> [WindowInfo] { list.withLock { $0 } }
}

@Suite struct AXOwnerResolverTests {
    private let alpha = ItemOwner(bundleID: "com.example.alpha", title: "Item")

    private func make(
        _ windows: MutableWindowList, apps: [FakeAXApp]
    ) -> (AXOwnerResolver<FakeAXTree>, FakeAXTree) {
        let tree = FakeAXTree(apps: apps)
        let reader = AXMenuBarReader(tree: tree, bundleIDOfPID: fakeBundleID)
        return (AXOwnerResolver(windowList: windows, reader: reader), tree)
    }

    private let oneItem = [FakeAXApp(items: [FakeAXItem(frame: axFrame(100))])]

    @Test func windowWithTheSameFrameGetsTheItemsOwner() {
        let (resolver, _) = make(MutableWindowList([window(5, x: 100)]), apps: oneItem)
        #expect(resolver.owner(ofWindow: 5) == alpha)
    }

    /// Measured on macOS 26: an item's AX frame is one point wider on each side than its window
    /// (AX x 2339 width 28, window x 2340 width 26), so the centres agree and the widths do not.
    @Test func anAXFrameOnePointWiderOnEachSideMatches() {
        let list = MutableWindowList([window(1, x: 101, width: 44)])
        let (resolver, _) = make(list, apps: oneItem)
        #expect(resolver.owner(ofWindow: 1) == alpha)
    }

    @Test func matchingToleratesLessThanOnePointFiveOnTheCentre() {
        let near = MutableWindowList([window(1, x: 101.4), window(2, x: 98.6)])
        let (resolver, _) = make(near, apps: oneItem)
        #expect(resolver.owner(ofWindow: 1) == alpha)
        #expect(resolver.owner(ofWindow: 2) == alpha)
    }

    @Test func matchingToleratesLessThanFourOnTheWidth() {
        let near = MutableWindowList([
            window(1, x: 98.05, width: 49.9), window(2, x: 101.95, width: 42.1),
        ])
        let (resolver, _) = make(near, apps: oneItem)
        #expect(resolver.owner(ofWindow: 1) == alpha)
        #expect(resolver.owner(ofWindow: 2) == alpha)
    }

    @Test func aCentreOffByOnePointFiveOrAnAXFrameFourWiderThanTheWindowDoesNotMatch() {
        let far = MutableWindowList([
            window(1, x: 101.5), window(2, x: 98.5), window(4, x: 102, width: 42),
        ])
        let (resolver, _) = make(far, apps: oneItem)
        #expect([1, 2, 4].allSatisfy { resolver.owner(ofWindow: $0) == nil })
    }

    // MARK: system items (rows measured on macOS 26)

    /// The window of a system item is ten points wider than its AX frame on each side, the centres
    /// agree: Wi-Fi AX 1306/22 against window 1296/42.
    private func systemBar() -> AXOwnerResolver<FakeAXTree> {
        let rows: [(pid: Int, ax: ItemFrame, title: String)] = [
            (10, axFrame(1270, width: 16), "Bluetooth"), (10, axFrame(1306, width: 22), "Wi-Fi"),
            (10, axFrame(1348, width: 26), "Battery"), (10, axFrame(1622, width: 97.5), "Clock"),
        ]
        let items = rows.map { FakeAXItem(pid: $0.pid, frame: $0.ax, title: $0.title) }
        let list = MutableWindowList([
            window(1, x: 1260, width: 36), window(2, x: 1296, width: 42),
            window(3, x: 1338, width: 46), window(4, x: 1612, width: 118),
        ])
        return make(list, apps: [FakeAXApp(items: items)]).0
    }

    @Test func aSystemItemsWindowTenPointsWiderOnEachSideMatchesItsNarrowerAXFrame() {
        let resolver = systemBar()
        let titles = [1, 2, 3, 4].map { resolver.owner(ofWindow: $0)?.title }
        #expect(titles == ["Bluetooth", "Wi-Fi", "Battery", "Clock"])
    }

    @Test func aNarrowAXFrameDoesNotMatchTheWindowOfItsNeighbour() {
        let wifi = [FakeAXApp(items: [FakeAXItem(frame: axFrame(1306, width: 22), title: "Wi-Fi")])]
        let neighbours = MutableWindowList([
            window(1, x: 1260, width: 36), window(2, x: 1338, width: 46),
        ])
        let (resolver, _) = make(neighbours, apps: wifi)
        #expect(resolver.owner(ofWindow: 1) == nil)
        #expect(resolver.owner(ofWindow: 2) == nil)
    }

    @Test func aHiddenModuleWithAnEmptyFrameMatchesNothing() {
        let hidden = [
            FakeAXApp(items: [FakeAXItem(frame: ItemFrame(x: 0, y: 0, width: 0, height: 0))])
        ]
        let list = MutableWindowList([window(1, x: -20, width: 40), window(2, x: -2, width: 4)])
        let (resolver, _) = make(list, apps: hidden)
        #expect(resolver.owner(ofWindow: 1) == nil)
        #expect(resolver.owner(ofWindow: 2) == nil)
    }

    @Test func aNarrowAXFrameInsideAWindowThatAnotherItemAlsoFitsStaysAmbiguous() {
        let apps = [
            FakeAXApp(items: [
                FakeAXItem(pid: 10, frame: axFrame(1306, width: 22), title: "A"),
                FakeAXItem(pid: 20, frame: axFrame(1300, width: 34), title: "B"),
            ])
        ]
        let (resolver, _) = make(MutableWindowList([window(1, x: 1296, width: 42)]), apps: apps)
        #expect(resolver.owner(ofWindow: 1) == nil)
    }

    @Test func eachWindowGetsTheOwnerOfItsOwnItem() {
        let apps = [
            FakeAXApp(items: [FakeAXItem(pid: 10, frame: axFrame(100), title: "A")]),
            FakeAXApp(items: [FakeAXItem(pid: 20, frame: axFrame(200), title: "B")]),
        ]
        let (resolver, _) = make(
            MutableWindowList([window(1, x: 100), window(2, x: 200)]), apps: apps)
        #expect(resolver.owner(ofWindow: 1)?.title == "A")
        #expect(resolver.owner(ofWindow: 2) == ItemOwner(bundleID: "com.example.beta", title: "B"))
    }

    @Test func severalItemsMatchingOneWindowLeaveItWithoutAnOwner() {
        let apps = [
            FakeAXApp(items: [FakeAXItem(pid: 10, frame: axFrame(100), title: "A")]),
            FakeAXApp(items: [FakeAXItem(pid: 20, frame: axFrame(100.5), title: "B")]),
        ]
        let (resolver, _) = make(MutableWindowList([window(5, x: 100), window(6, x: 300)]), apps: apps)
        #expect(resolver.owner(ofWindow: 5) == nil)
    }

    @Test func ambiguousWindowDoesNotHideAnUnambiguousOne() {
        let apps = [
            FakeAXApp(items: [
                FakeAXItem(pid: 10, frame: axFrame(100), title: "A"),
                FakeAXItem(pid: 20, frame: axFrame(100), title: "B"),
                FakeAXItem(pid: 10, frame: axFrame(300), title: "C"),
            ])
        ]
        let (resolver, _) = make(MutableWindowList([window(5, x: 100), window(6, x: 300)]), apps: apps)
        #expect(resolver.owner(ofWindow: 5) == nil)
        #expect(resolver.owner(ofWindow: 6)?.title == "C")
    }

    @Test func unknownWindowHasNoOwner() {
        let (resolver, _) = make(MutableWindowList([window(5, x: 100)]), apps: oneItem)
        #expect(resolver.owner(ofWindow: 6) == nil)
    }

    @Test func windowNoItemMatchesHasNoOwner() {
        let (resolver, _) = make(MutableWindowList([window(5, x: 900)]), apps: oneItem)
        #expect(resolver.owner(ofWindow: 5) == nil)
    }

    @Test func treeReadIsSharedWhileTheWindowListStaysTheSame() {
        let list = MutableWindowList([window(1, x: 100), window(2, x: 300)])
        let (resolver, tree) = make(list, apps: oneItem)
        _ = resolver.owner(ofWindow: 1)
        _ = resolver.owner(ofWindow: 2)
        _ = resolver.owner(ofWindow: 1)
        #expect(tree.walks.value == 1)
    }

    @Test func treeIsReadAgainWhenAWindowMoves() {
        let list = MutableWindowList([window(1, x: 100)])
        let (resolver, tree) = make(list, apps: oneItem)
        _ = resolver.owner(ofWindow: 1)
        list.set([window(1, x: 130)])
        _ = resolver.owner(ofWindow: 1)
        #expect(tree.walks.value == 2)
    }

    @Test func emptyReadIsNotRememberedSoGrantedAccessTakesEffectAtOnce() {
        let (resolver, tree) = make(MutableWindowList([window(1, x: 100)]), apps: [])
        #expect(resolver.owner(ofWindow: 1) == nil)
        #expect(resolver.owner(ofWindow: 1) == nil)
        #expect(tree.walks.value == 2)
    }

    @Test func discoveryTreatsAnAXResolvedItemAsManaged() {
        let list = MutableWindowList([window(5, x: 100)])
        let (resolver, _) = make(list, apps: oneItem)
        let found = ItemDiscovery(
            windowList: list, ownerResolver: resolver, mainDisplay: { mainDisplay }
        ).discover()
        #expect(found.map(\.isManaged) == [true])
        #expect(found.first?.item.id == MenuBarItemID(ownerBundleID: alpha.bundleID, title: alpha.title))
    }
}
