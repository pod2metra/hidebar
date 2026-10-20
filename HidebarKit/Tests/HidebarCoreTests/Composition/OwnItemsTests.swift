import Foundation
import Testing

@testable import HidebarCore

@MainActor @Suite struct OwnItemsTests {
    @Test func separatorIdIsOurBundleIdWithTheSeparatorTitle() {
        #expect(OwnItems.separatorID.ownerBundleID == OwnItems.bundleID)
        #expect(OwnItems.separatorID.title == OwnItems.separatorTitle)
    }

    @Test func anIdIsOwnExactlyWhenItsOwnerIsOurBundle() {
        #expect(OwnItems.isOwn(MenuBarItemID(ownerBundleID: OwnItems.bundleID, title: "")))
        #expect(OwnItems.isOwn(MenuBarItemID(ownerBundleID: OwnItems.bundleID, title: "anything")))
        #expect(!OwnItems.isOwn(MenuBarItemID(ownerBundleID: OwnItems.bundleID + ".helper", title: "")))
        #expect(!OwnItems.isOwn(moveID("a")))
    }
}
