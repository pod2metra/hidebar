@testable import HidebarCore

func itemID(_ owner: String, _ title: String = "") -> MenuBarItemID {
    MenuBarItemID(ownerBundleID: owner, title: title)
}
