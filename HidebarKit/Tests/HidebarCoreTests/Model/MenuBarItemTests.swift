import Foundation
import Testing

@testable import HidebarCore

@Suite struct MenuBarItemTests {
    @Test func idsWithSameOwnerAndTitleAreEqualAndHashEqual() {
        let a = MenuBarItemID(ownerBundleID: "com.example.app", title: "Status")
        let b = MenuBarItemID(ownerBundleID: "com.example.app", title: "Status")
        #expect(a == b)
        #expect(Set([a, b]).count == 1)
    }

    @Test func idsDifferByOwnerOrTitle() {
        let base = MenuBarItemID(ownerBundleID: "com.example.app", title: "Status")
        #expect(base != MenuBarItemID(ownerBundleID: "com.example.other", title: "Status"))
        #expect(base != MenuBarItemID(ownerBundleID: "com.example.app", title: "Other"))
    }

    @Test func idRoundTripsThroughJSON() throws {
        let id = MenuBarItemID(ownerBundleID: "com.example.app", title: "Status")
        let decoded = try JSONDecoder().decode(MenuBarItemID.self, from: JSONEncoder().encode(id))
        #expect(decoded == id)
    }

    @Test func itemKeepsAllFields() {
        let id = MenuBarItemID(ownerBundleID: "com.example.app", title: "Status")
        let frame = ItemFrame(x: 1, y: 2, width: 3, height: 4)
        let item = MenuBarItem(id: id, frame: frame, isMovable: true)
        #expect(item.id == id)
        #expect(item.frame == frame)
        #expect(item.frame.x == 1)
        #expect(item.frame.y == 2)
        #expect(item.frame.width == 3)
        #expect(item.frame.height == 4)
        #expect(item.isMovable)
    }

    @Test func itemsDifferingInAnyFieldAreNotEqual() {
        let id = MenuBarItemID(ownerBundleID: "com.example.app", title: "Status")
        let frame = ItemFrame(x: 1, y: 2, width: 3, height: 4)
        let item = MenuBarItem(id: id, frame: frame, isMovable: true)
        #expect(item == MenuBarItem(id: id, frame: frame, isMovable: true))
        #expect(item != MenuBarItem(id: id, frame: frame, isMovable: false))    }
}
