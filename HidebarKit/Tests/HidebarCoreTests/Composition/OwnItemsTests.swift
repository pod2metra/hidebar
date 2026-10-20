import Foundation
import Testing

@testable import HidebarCore

@MainActor @Suite struct OwnItemsTests {
    @Test func separatorIdIsOurBundleIdWithTheSeparatorTitle() {
        #expect(OwnItems.separatorID.ownerBundleID == OwnItems.bundleID)
        #expect(OwnItems.separatorID.title == OwnItems.separatorTitle)
    }

    @Test func everyGroupIconHasATitleOfItsOwn() throws {
        let first = try makeGroup(UUID(), symbol: "star", items: [])
        let second = try makeGroup(UUID(), symbol: "star", items: [])
        let other = try makeGroup(first.id, symbol: "heart", items: [])
        #expect(OwnItems.groupTitle(first) != OwnItems.groupTitle(second))
        #expect(OwnItems.groupTitle(first) != OwnItems.groupTitle(other))
        #expect(OwnItems.groupTitle(first).contains(first.id.uuidString))
        #expect(OwnItems.groupTitle(first).contains("star"))
        #expect(OwnItems.groupTitle(first) != OwnItems.separatorTitle)
    }

    @Test func anIdIsOwnExactlyWhenItsOwnerIsOurBundle() {
        #expect(OwnItems.isOwn(MenuBarItemID(ownerBundleID: OwnItems.bundleID, title: "")))
        #expect(OwnItems.isOwn(MenuBarItemID(ownerBundleID: OwnItems.bundleID, title: "anything")))
        #expect(!OwnItems.isOwn(MenuBarItemID(ownerBundleID: OwnItems.bundleID + ".helper", title: "")))
        #expect(!OwnItems.isOwn(moveID("a")))
    }

    @Test func foreignDropsEveryOwnItemIncludingTheSeparator() {
        let items = [
            discovered("a"), ownDiscovered(OwnItems.separatorTitle), discovered("b", managed: false),
            ownDiscovered("toggle"),
        ]
        #expect(OwnItems.foreign(items) == [items[0], items[2]])
    }

    @Test func planItemsKeepTheSeparatorAndDropTheRestOfOurItems() {
        let items = [
            ownDiscovered("toggle"), discovered("a"), ownDiscovered(OwnItems.separatorTitle),
            ownDiscovered("group"),
        ]
        #expect(OwnItems.planItems(items) == [items[1].item, items[2].item])
    }
}
