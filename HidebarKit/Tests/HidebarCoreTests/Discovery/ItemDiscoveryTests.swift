import Testing

@testable import HidebarCore

@Suite struct ItemDiscoveryTests {
    private func ids(_ items: [DiscoveredItem]) -> [Int] { items.map(\.windowID) }

    // MARK: filtering (rows from Spikes/FINDINGS.md)

    @Test func menubarWindowOnLayer24IsDropped() {
        let menubar = window(155_363, x: 0, width: 1728, layer: 24, owner: nil, title: "Menubar")
        let result = discover(
            [menubar, window(21, x: 1566, owner: "com.example.app")])
        #expect(ids(result) == [21])
    }

    @Test func itemCarriesTheWindowNumberOwnerAndFrameToNameInADrag() throws {
        let result = discover([window(21, x: 1566, ownerPID: 629)])
        let found = try #require(result.first)
        #expect(
            found.window
                == WindowTarget(
                    windowID: 21, ownerPID: 629,
                    frame: ItemFrame(x: 1566, y: 0, width: 46, height: 24)))
    }

    @Test func offscreenTwinIsDroppedAndOnscreenOneKept() {
        let twin = window(154_021, x: 1566, onscreen: false, owner: "com.example.app")
        let real = window(21, x: 1566, owner: "com.example.app")
        #expect(ids(discover([twin, real])) == [21])
        #expect(ids(discover([real, twin])) == [21])
    }

    @Test func zeroSizeWindowsAreDropped() {
        let both = window(1, x: 10, width: 0, height: 0, owner: "com.a")
        let noWidth = window(2, x: 20, width: 0, owner: "com.b")
        let noHeight = window(3, x: 30, height: 0, owner: "com.c")
        let real = window(4, x: 40, owner: "com.d")
        #expect(ids(discover([both, noWidth, noHeight, real])) == [4])
    }

    @Test func onlyLayer25IsKept() {
        let below = window(1, x: 10, layer: 24, owner: "com.a")
        let above = window(2, x: 20, layer: 26, owner: "com.b")
        let normal = window(3, x: 30, layer: 0, owner: "com.c")
        let status = window(4, x: 40, layer: 25, owner: "com.d")
        #expect(ids(discover([below, above, normal, status])) == [4])
        #expect(ItemDiscovery.statusItemLayer == 25)
    }

    @Test func emptyWindowListGivesNoItems() {
        #expect(discover([]).isEmpty)
    }

    // MARK: ordering

    @Test func itemsAreOrderedByX() {
        let right = window(1, x: 1612, width: 118, owner: "com.a")
        let middle = window(2, x: 1566, owner: "com.b")
        let left = window(3, x: 900, owner: "com.c")
        #expect(ids(discover([right, left, middle])) == [3, 2, 1])
    }

    @Test func equalXFallsBackToWindowID() {
        let first = window(7, x: 100, owner: "com.a")
        let second = window(9, x: 100, owner: "com.b")
        #expect(ids(discover([second, first])) == [7, 9])
    }

    @Test func itemCarriesWindowIDAndFrame() throws {
        let source = window(21, x: 1566, width: 46, height: 24, owner: "com.example.app")
        let result = try #require(discover([source]).first)
        #expect(result.windowID == 21)
        #expect(result.item.frame == ItemFrame(x: 1566, y: 0, width: 46, height: 24))
    }

    // MARK: owner

    @Test func accessibilityOwnerWinsOverWindowOwner() throws {
        let source = window(21, x: 1566, owner: controlCenter, title: "ignored")
        let owner = ItemOwner(bundleID: "com.example.app", title: "Status")
        let result = try #require(discover([source], owners: [21: owner]).first)
        #expect(result.item.id == itemID("com.example.app", "Status"))
        #expect(result.isManaged)
    }

    @Test func withoutAccessibilityWindowOwnerAndTitleAreOnlyADisplayFallback() throws {
        let source = window(21, x: 1566, owner: "com.example.app", title: "Status")
        let result = try #require(discover([source]).first)
        #expect(result.item.id == itemID("com.example.app", "Status"))
        #expect(!result.isManaged)
    }

    @Test func accessibilityIsAskedPerWindow() {
        let first = window(21, x: 10)
        let second = window(19, x: 20)
        let owners = [
            21: ItemOwner(bundleID: "com.a", title: ""), 19: ItemOwner(bundleID: "com.b", title: ""),
        ]
        let result = discover([first, second], owners: owners)
        #expect(result.map(\.item.id) == [itemID("com.a"), itemID("com.b")])
    }

    // MARK: unmanaged

    @Test func controlCenterWithoutAccessibilityIsUnmanagedButStillListed() throws {
        let source = window(19, x: 1612, width: 118, owner: controlCenter)
        let result = try #require(discover([source]).first)
        #expect(!result.isManaged)
        #expect(!result.item.isMovable)
        #expect(!result.item.isHidable)
        #expect(result.item.id == itemID(controlCenter))
    }

    @Test func missingAccessibilityMakesEveryControlCenterItemUnmanaged() {
        let rows = [
            window(21, x: 1566, owner: controlCenter), window(19, x: 1612, width: 118),
        ]
        #expect(discover(rows).map(\.isManaged) == [false, false])
    }

    @Test func windowWithoutAnyOwnerAndWithoutAccessibilityIsUnmanaged() throws {
        let result = try #require(discover([window(5, x: 10, owner: nil, title: "Orphan")]).first)
        #expect(!result.isManaged)
        #expect(!result.item.isMovable)
    }

    @Test func accessibilityAnswerRescuesControlCenterWindow() throws {
        let owners = [21: ItemOwner(bundleID: "com.example.app", title: "Status")]
        let result = try #require(discover([window(21, x: 10)], owners: owners).first)
        #expect(result.isManaged)
    }

    @Test func twoUntitledItemsOfOneBundleAreBothUnmanaged() {
        let rows = [window(1, x: 10), window(2, x: 60), window(3, x: 110)]
        let owners = [
            1: ItemOwner(bundleID: "com.twin", title: ""),
            2: ItemOwner(bundleID: "com.twin", title: ""),
            3: ItemOwner(bundleID: "com.solo", title: ""),
        ]
        let result = discover(rows, owners: owners)
        #expect(result.map(\.isManaged) == [false, false, true])
        #expect(result.map(\.item.isMovable) == [false, false, true])
        #expect(result.map(\.item.isHidable) == [false, false, true])
    }

    @Test func sameTitleInDifferentBundlesIsNotACollision() {
        let owners = [
            1: ItemOwner(bundleID: "com.a", title: "Menu"), 2: ItemOwner(bundleID: "com.b", title: "Menu"),
        ]
        let rows = [window(1, x: 10), window(2, x: 60)]
        #expect(discover(rows, owners: owners).map(\.isManaged) == [true, true])
    }

    @Test func sameBundleWithDifferentTitlesIsNotACollision() {
        let owners = [
            1: ItemOwner(bundleID: "com.a", title: "One"), 2: ItemOwner(bundleID: "com.a", title: "Two"),
        ]
        let rows = [window(1, x: 10), window(2, x: 60)]
        #expect(discover(rows, owners: owners).map(\.isManaged) == [true, true])
    }

    // MARK: no Accessibility answer means no identity

    @Test func systemUIServerWindowWithEmptyTitleWithoutAccessibilityIsNotMovable() throws {
        let source = window(8, x: 10, owner: "com.apple.systemuiserver", title: "")
        let result = try #require(discover([source]).first)
        #expect(!result.isManaged)
        #expect(!result.item.isMovable)
        #expect(!result.item.isHidable)
        #expect(result.item.id == itemID("com.apple.systemuiserver"))
    }

    @Test func thirdPartyAppWithoutAccessibilityIsUnmanaged() throws {
        let source = window(21, x: 10, owner: "com.example.app", title: "Status")
        let result = try #require(discover([source]).first)
        #expect(!result.isManaged)
        #expect(!result.item.isMovable)
        #expect(!result.item.isHidable)
    }

    @Test func sameThirdPartyAppWithAccessibilityIsManaged() throws {
        let source = window(21, x: 10, owner: "com.example.app", title: "")
        let owner = ItemOwner(bundleID: "com.example.app", title: "Status")
        let result = try #require(discover([source], owners: [21: owner]).first)
        #expect(result.isManaged)
        #expect(result.item.isMovable)
        #expect(result.item.isHidable)
    }

    @Test func unresolvedWindowDoesNotDemoteResolvedItemWithTheSameID() {
        let rows = [window(1, x: 10), window(2, x: 60, owner: "com.a", title: "Status")]
        let owners = [1: ItemOwner(bundleID: "com.a", title: "Status")]
        #expect(discover(rows, owners: owners).map(\.isManaged) == [true, false])
    }

    // MARK: unmovable and unhidable system items

    /// Identities as Accessibility reports them: Control Center's items by `AXIdentifier`, Siri
    /// by its title.
    @Test(arguments: [
        (controlCenter, "com.apple.menuextra.clock"),
        (controlCenter, "com.apple.menuextra.controlcenter"),
        ("com.apple.systemuiserver", "Siri"),
    ])
    func systemItemIsManagedButNeitherMovableNorHidable(bundle: String, title: String) throws {
        let owners = [1: ItemOwner(bundleID: bundle, title: title)]
        let result = try #require(discover([window(1, x: 10)], owners: owners).first)
        #expect(result.isManaged)
        #expect(!result.item.isMovable)
        #expect(!result.item.isHidable)
    }

    @Test(arguments: [
        (controlCenter, "com.apple.menuextra.wifi"), (controlCenter, "com.apple.menuextra.bluetooth"),
        (controlCenter, "com.apple.menuextra.battery"), ("com.apple.systemuiserver", ""),
        ("com.apple.Spotlight", "Spotlight"), ("com.example.app", "Siri"),
        ("com.example.app", "com.apple.menuextra.clock"), (controlCenter, "Siri"),
    ])
    func otherItemsAreMovableAndHidable(bundle: String, title: String) throws {
        let owners = [1: ItemOwner(bundleID: bundle, title: title)]
        let result = try #require(discover([window(1, x: 10)], owners: owners).first)
        #expect(result.item.isMovable)
        #expect(result.item.isHidable)
    }
}
