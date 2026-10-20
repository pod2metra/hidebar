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

    @Test func matchingToleratesLessThanOnePointFiveOnXAndWidth() {
        let near = MutableWindowList([window(1, x: 101.4, width: 47.4), window(2, x: 98.6, width: 44.6)])
        let (resolver, _) = make(near, apps: oneItem)
        #expect(resolver.owner(ofWindow: 1) == alpha)
        #expect(resolver.owner(ofWindow: 2) == alpha)
    }

    @Test func aDifferenceOfOnePointFiveOrMoreDoesNotMatch() {
        let far = MutableWindowList([
            window(1, x: 101.5), window(2, x: 98.5), window(3, x: 100, width: 47.5),
            window(4, x: 100, width: 44.5),
        ])
        let (resolver, _) = make(far, apps: oneItem)
        #expect([1, 2, 3, 4].allSatisfy { resolver.owner(ofWindow: $0) == nil })
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
