import Testing

@testable import HidebarCore

/// An item can be on the bar yet not on screen: the active app's menus cover it, as on a Mac with
/// a notch. `discoverAll` finds those too, so a drag can still name their window.
@Suite struct CoveredItemDiscoveryTests {
    private func discoverAll(
        _ windows: [WindowInfo], owners: [Int: ItemOwner] = [:], display: ItemFrame = mainDisplay
    ) -> [DiscoveredItem] {
        ItemDiscovery(
            windowList: StubWindowList(list: windows),
            ownerResolver: StubOwnerResolver(owners: owners), mainDisplay: { display }
        ).discoverAll()
    }

    private func ids(_ items: [DiscoveredItem]) -> [Int] { items.map(\.windowID) }

    private let owner = ItemOwner(bundleID: "info.example.Awake", title: "")

    @Test func coveredItemIsFoundAndManagedThroughItsAccessibilityOwner() throws {
        let covered = window(80, x: 970, width: 42, onscreen: false)
        let found = try #require(discoverAll([covered], owners: [80: owner]).first)
        #expect(found.windowID == 80)
        #expect(found.isManaged)
        #expect(found.item.id == MenuBarItemID(ownerBundleID: "info.example.Awake", title: ""))
    }

    @Test func plainDiscoverStillLeavesTheCoveredItemOut() {
        #expect(discover([window(80, x: 970, width: 42, onscreen: false)]).isEmpty)
    }

    @Test func aTwinOfAnOnscreenWindowIsDroppedWhateverItsNumber() {
        let real = window(900, x: 1566)
        let twin = window(21, x: 1566, onscreen: false)
        #expect(ids(discoverAll([twin, real])) == [900])
        #expect(ids(discoverAll([real, twin])) == [900])
    }

    @Test func offscreenTwinsOfACoveredItemLeaveTheOldestWindow() {
        let original = window(80, x: 970, width: 42, onscreen: false)
        let copy = window(154_021, x: 970, width: 42, onscreen: false)
        #expect(ids(discoverAll([copy, original])) == [80])
    }

    @Test func twinsAreOneItemSoTheOwnerIsNotShared() throws {
        let original = window(80, x: 970, width: 42, onscreen: false)
        let copy = window(154_021, x: 970, width: 42, onscreen: false)
        let found = try #require(
            discoverAll([original, copy], owners: [80: owner, 154_021: owner]).first)
        #expect(found.isManaged)
    }

    @Test func windowsWithDifferentFramesAreDifferentItems() {
        let first = window(1, x: 100, onscreen: false)
        let second = window(2, x: 200, onscreen: true)
        #expect(ids(discoverAll([second, first])) == [1, 2])
    }

    @Test func emptyWindowsOtherLayersAndOtherBarsStayOut() {
        let rows = [
            window(1, x: 10, width: 0, onscreen: false), window(2, x: 20, layer: 24, onscreen: false),
            window(3, x: 30, y: 900, onscreen: false), window(4, x: 4_000, onscreen: false),
            window(5, x: 50, onscreen: false),
        ]
        #expect(ids(discoverAll(rows)) == [5])
    }

    @Test func itemsKeepTheOrderByX() {
        let rows = [window(1, x: 300, onscreen: false), window(2, x: 100), window(3, x: 200)]
        #expect(ids(discoverAll(rows)) == [2, 3, 1])
    }
}
