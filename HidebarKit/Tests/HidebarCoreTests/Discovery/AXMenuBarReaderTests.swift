import Testing

@testable import HidebarCore

@Suite struct AXMenuBarReaderTests {
    private func entries(_ apps: [FakeAXApp]) -> [AXMenuBarEntry] {
        AXMenuBarReader(tree: FakeAXTree(apps: apps), bundleIDOfPID: fakeBundleID).entries()
    }

    @Test func itemsOfEveryAppAreListedWithOwnerTitleAndFrame() {
        let result = entries([
            FakeAXApp(items: [FakeAXItem(pid: 10, frame: axFrame(100), title: "Wi-Fi")]),
            FakeAXApp(items: [FakeAXItem(pid: 20, frame: axFrame(200), title: "Sync")]),
        ])
        #expect(
            result == [
                AXMenuBarEntry(
                    frame: axFrame(100), owner: ItemOwner(bundleID: "com.example.alpha", title: "Wi-Fi")),
                AXMenuBarEntry(
                    frame: axFrame(200), owner: ItemOwner(bundleID: "com.example.beta", title: "Sync")),
            ])
    }

    @Test func entryIdIsOwnerPlusTitle() {
        let entry = AXMenuBarEntry(
            frame: axFrame(0), owner: ItemOwner(bundleID: "com.example.alpha", title: "Wi-Fi"))
        #expect(entry.id == MenuBarItemID(ownerBundleID: "com.example.alpha", title: "Wi-Fi"))
    }

    @Test func appWithoutAMenuBarContributesNothing() {
        let result = entries([FakeAXApp(items: nil), FakeAXApp(items: [FakeAXItem()])])
        #expect(result.count == 1)
    }

    @Test func noAppsGiveNoEntries() {
        #expect(entries([]).isEmpty)
    }

    @Test func itemWithoutFrameIsSkipped() {
        #expect(entries([FakeAXApp(items: [FakeAXItem(frame: nil)])]).isEmpty)
    }

    @Test func itemWithoutPidIsSkipped() {
        #expect(entries([FakeAXApp(items: [FakeAXItem(pid: nil)])]).isEmpty)
    }

    @Test func itemOfAnUnknownProcessIsSkipped() {
        #expect(entries([FakeAXApp(items: [FakeAXItem(pid: 99)])]).isEmpty)
    }

    /// Control Center's Wi-Fi item: a stable identifier, no title, and a localized description
    /// that changes with the signal.
    @Test func identifierWinsOverTitleAndDescription() {
        let item = FakeAXItem(
            title: nil, description: "Wi-Fi, connected, 3 bars", identifier: "com.apple.menuextra.wifi")
        #expect(entries([FakeAXApp(items: [item])]).first?.owner.title == "com.apple.menuextra.wifi")
        let titled = FakeAXItem(title: "Siri", description: "x", identifier: "id")
        #expect(entries([FakeAXApp(items: [titled])]).first?.owner.title == "id")
    }

    @Test func emptyIdentifierFallsBackToTheTitle() {
        let item = FakeAXItem(title: "Siri", description: "Description", identifier: "")
        #expect(entries([FakeAXApp(items: [item])]).first?.owner.title == "Siri")
    }

    @Test func titleComesFromAXTitleWhenPresent() {
        let item = FakeAXItem(title: "Title", description: "Description")
        #expect(entries([FakeAXApp(items: [item])]).first?.owner.title == "Title")
    }

    @Test func emptyTitleFallsBackToTheDescription() {
        let item = FakeAXItem(title: "", description: "Description")
        #expect(entries([FakeAXApp(items: [item])]).first?.owner.title == "Description")
    }

    @Test func missingTitleFallsBackToTheDescription() {
        let item = FakeAXItem(title: nil, description: "Description")
        #expect(entries([FakeAXApp(items: [item])]).first?.owner.title == "Description")
    }

    @Test func itemWithNeitherTitleNorDescriptionHasAnEmptyTitle() {
        let item = FakeAXItem(title: nil, description: nil)
        #expect(entries([FakeAXApp(items: [item])]).first?.owner.title == "")
        let blank = FakeAXItem(title: "", description: "")
        #expect(entries([FakeAXApp(items: [blank])]).first?.owner.title == "")
    }
}
