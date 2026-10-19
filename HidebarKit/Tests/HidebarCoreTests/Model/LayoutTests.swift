import Foundation
import Testing

@testable import HidebarCore

func itemID(_ owner: String, _ title: String = "") -> MenuBarItemID {
    MenuBarItemID(ownerBundleID: owner, title: title)
}

func makeGroup(_ id: UUID = UUID(), symbol: String = "star", items: [MenuBarItemID] = [])
    throws -> ItemGroup
{
    ItemGroup(id: id, symbol: try GroupSymbol(name: symbol), items: items)
}

@Suite struct LayoutTests {
    private let a = itemID("com.a")
    private let b = itemID("com.b", "Title")
    private let c = itemID("com.c")

    @Test func emptyLayoutHasNoItemsAndCurrentVersion() {
        #expect(Layout.empty.version == Layout.currentVersion)
        #expect(Layout.empty.version == 1)
        #expect(Layout.empty.visible.isEmpty)
        #expect(Layout.empty.hidden.isEmpty)
        #expect(Layout.empty.groups.isEmpty)
    }

    @Test func validInitKeepsOrderAndContents() throws {
        let group = try makeGroup(items: [c])
        let layout = try Layout(visible: [b, a], hidden: [], groups: [group])
        #expect(layout.visible == [b, a])
        #expect(layout.hidden.isEmpty)
        #expect(layout.groups == [group])
        #expect(layout.version == 1)
    }

    @Test func itemInVisibleAndHiddenIsRejected() {
        #expect(throws: LayoutError.duplicateItem(a)) {
            try Layout(visible: [a], hidden: [a], groups: [])
        }
    }

    @Test func itemTwiceInVisibleIsRejected() {
        #expect(throws: LayoutError.duplicateItem(a)) {
            try Layout(visible: [a, a], hidden: [], groups: [])
        }
    }

    @Test func itemInHiddenAndGroupIsRejected() throws {
        let group = try makeGroup(items: [b])
        #expect(throws: LayoutError.duplicateItem(b)) {
            try Layout(visible: [], hidden: [b], groups: [group])
        }
    }

    @Test func itemInTwoGroupsIsRejected() throws {
        let first = try makeGroup(items: [c])
        let second = try makeGroup(items: [a, c])
        #expect(throws: LayoutError.duplicateItem(c)) {
            try Layout(visible: [], hidden: [], groups: [first, second])
        }
    }

    @Test func itemTwiceInOneGroupIsRejected() throws {
        let group = try makeGroup(items: [a, a])
        #expect(throws: LayoutError.duplicateItem(a)) {
            try Layout(visible: [], hidden: [], groups: [group])
        }
    }

    @Test func duplicateGroupIDIsRejected() throws {
        let id = UUID()
        let first = try makeGroup(id, items: [a])
        let second = try makeGroup(id, symbol: "heart", items: [b])
        #expect(throws: LayoutError.duplicateGroup(id)) {
            try Layout(visible: [], hidden: [], groups: [first, second])
        }
    }

    @Test func roundTripsThroughJSON() throws {
        let layout = try Layout(
            visible: [a], hidden: [b], groups: [try makeGroup(items: [c])])
        let decoded = try JSONDecoder().decode(Layout.self, from: JSONEncoder().encode(layout))
        #expect(decoded == layout)
    }

    @Test func decodingRejectsDuplicateIDs() {
        let json = """
            {"version":1,"visible":[{"ownerBundleID":"com.a","title":""}],
             "hidden":[{"ownerBundleID":"com.a","title":""}],"groups":[]}
            """
        #expect(throws: LayoutError.duplicateItem(itemID("com.a"))) {
            try JSONDecoder().decode(Layout.self, from: Data(json.utf8))
        }
    }

    @Test func decodingRejectsOtherVersion() {
        let json = #"{"version":2,"visible":[],"hidden":[],"groups":[]}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Layout.self, from: Data(json.utf8))
        }
    }

    @Test func decodingRequiresAllFields() {
        let json = #"{"version":1,"visible":[],"hidden":[]}"#
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(Layout.self, from: Data(json.utf8))
        }
    }
}
