import Foundation
import Testing

@testable import HidebarCore

private let firstGroup = UUID()
private let secondGroup = UUID()

private func ids(_ names: String...) -> [MenuBarItemID] {
    names.map { itemID("com.\($0)") }
}

private func list(_ layout: Layout, _ placement: Placement) -> [MenuBarItemID] {
    switch placement {
    case .visible: layout.visible
    case .hidden: layout.hidden
    case .group(let id): layout.groups.first { $0.id == id }?.items ?? []
    }
}

private func allIDs(_ layout: Layout) -> [MenuBarItemID: Int] {
    Dictionary(
        (layout.visible + layout.hidden + layout.groups.flatMap(\.items)).map { ($0, 1) },
        uniquingKeysWith: +)
}

@Suite struct LayoutEditingTests {
    private let placements: [Placement] = [.visible, .hidden, .group(firstGroup), .group(secondGroup)]

    /// visible a b c, hidden d e, first group [f g], second group empty.
    private func sample() throws -> Layout {
        try Layout(
            visible: ids("a", "b", "c"), hidden: ids("d", "e"),
            groups: [
                try makeGroup(firstGroup, symbol: "star", items: ids("f", "g")),
                try makeGroup(secondGroup, symbol: "heart"),
            ])
    }

    @Test func everyMoveFromAnyListToAnyListAndIndexPutsTheItemThereAndLosesNothing() throws {
        let layout = try sample()
        let everyItem = layout.visible + layout.hidden + layout.groups.flatMap(\.items)
        for item in everyItem {
            let origin = try #require(placements.first { list(layout, $0).contains(item) })
            for destination in placements {
                let others = list(layout, destination).filter { $0 != item }
                for index in 0...others.count {
                    let moved = try LayoutEditing.move(item, in: layout, to: destination, at: index)
                    var expected = others
                    expected.insert(item, at: index)
                    #expect(list(moved, destination) == expected)
                    #expect(allIDs(moved) == allIDs(layout))
                    for untouched in placements where untouched != origin && untouched != destination {
                        #expect(list(moved, untouched) == list(layout, untouched))
                    }
                    if origin != destination {
                        #expect(list(moved, origin) == list(layout, origin).filter { $0 != item })
                    }
                    #expect(moved.groups.map(\.id) == layout.groups.map(\.id))
                    #expect(moved.groups.map(\.symbol) == layout.groups.map(\.symbol))
                }
            }
        }
    }

    @Test func indexBeyondTheDestinationOrBelowZeroIsRejected() throws {
        let layout = try sample()
        let item = itemID("com.a")
        // Hidden has two items, so 0...2 is valid for an item coming from elsewhere.
        #expect(throws: LayoutEditError.indexOutOfRange(3)) {
            try LayoutEditing.move(item, in: layout, to: .hidden, at: 3)
        }
        #expect(throws: LayoutEditError.indexOutOfRange(-1)) {
            try LayoutEditing.move(item, in: layout, to: .hidden, at: -1)
        }
        // Within its own list the item does not count: visible a b c allows 0...2 only.
        #expect(throws: LayoutEditError.indexOutOfRange(3)) {
            try LayoutEditing.move(item, in: layout, to: .visible, at: 3)
        }
        #expect(throws: LayoutEditError.indexOutOfRange(1)) {
            try LayoutEditing.move(item, in: layout, to: .group(secondGroup), at: 1)
        }
    }

    @Test func unknownItemAndUnknownGroupAreRejected() throws {
        let layout = try sample()
        let stranger = itemID("com.nobody")
        let missingGroup = UUID()
        #expect(throws: LayoutEditError.unknownItem(stranger)) {
            try LayoutEditing.move(stranger, in: layout, to: .visible, at: 0)
        }
        #expect(throws: LayoutEditError.unknownGroup(missingGroup)) {
            try LayoutEditing.move(itemID("com.a"), in: layout, to: .group(missingGroup), at: 0)
        }
    }

    @Test func aNonHidableItemMayOnlyGoToVisible() throws {
        let layout = try sample()
        let pinned = itemID("com.a")
        let rest = itemID("com.b")
        #expect(throws: LayoutEditError.notHidable(pinned)) {
            try LayoutEditing.move(pinned, in: layout, to: .hidden, at: 0, nonHidable: [pinned])
        }
        #expect(throws: LayoutEditError.notHidable(pinned)) {
            try LayoutEditing.move(
                pinned, in: layout, to: .group(firstGroup), at: 0, nonHidable: [pinned])
        }
        let reordered = try LayoutEditing.move(
            pinned, in: layout, to: .visible, at: 2, nonHidable: [pinned])
        #expect(reordered.visible == ids("b", "c", "a"))
        let hiddenOne = itemID("com.d")
        let shown = try LayoutEditing.move(
            hiddenOne, in: layout, to: .visible, at: 0, nonHidable: [hiddenOne])
        #expect(shown.visible.first == hiddenOne)
        let others = try LayoutEditing.move(
            rest, in: layout, to: .hidden, at: 0, nonHidable: [pinned])
        #expect(others.hidden.first == rest)
    }

    @Test func reorderMovesWithinTheSameList() throws {
        let layout = try sample()
        let first = try LayoutEditing.reorder(itemID("com.a"), in: layout, to: 2)
        #expect(first.visible == ids("b", "c", "a"))
        let second = try LayoutEditing.reorder(itemID("com.e"), in: layout, to: 0)
        #expect(second.hidden == ids("e", "d"))
        let third = try LayoutEditing.reorder(itemID("com.g"), in: layout, to: 0)
        #expect(third.groups[0].items == ids("g", "f"))
        for edited in [first, second, third] {
            #expect(allIDs(edited) == allIDs(layout))
        }
        #expect(second.visible == layout.visible)
    }

    @Test func reorderRejectsUnknownItemAndBadIndex() throws {
        let layout = try sample()
        let stranger = itemID("com.nobody")
        #expect(throws: LayoutEditError.unknownItem(stranger)) {
            try LayoutEditing.reorder(stranger, in: layout, to: 0)
        }
        #expect(throws: LayoutEditError.indexOutOfRange(3)) {
            try LayoutEditing.reorder(itemID("com.a"), in: layout, to: 3)
        }
    }

    @Test func createGroupAppendsAnEmptyGroupAndKeepsEverythingElse() throws {
        let layout = try sample()
        let id = UUID()
        let created = try LayoutEditing.createGroup(
            in: layout, symbol: GroupSymbol(name: "bolt"), id: id)
        #expect(created.groups.count == 3)
        #expect(created.groups[2] == ItemGroup(id: id, symbol: try GroupSymbol(name: "bolt"), items: []))
        #expect(Array(created.groups.prefix(2)) == layout.groups)
        #expect(created.visible == layout.visible)
        #expect(created.hidden == layout.hidden)
    }

    @Test func createGroupWithATakenIDIsRejectedByTheLayout() throws {
        #expect(throws: LayoutError.duplicateGroup(firstGroup)) {
            try LayoutEditing.createGroup(
                in: try sample(), symbol: GroupSymbol(name: "bolt"), id: firstGroup)
        }
    }

    @Test func setSymbolChangesOnlyThatGroupsSymbol() throws {
        let layout = try sample()
        let renamed = try LayoutEditing.setSymbol(
            ofGroup: firstGroup, in: layout, to: GroupSymbol(name: "bolt"))
        #expect(renamed.groups[0].symbol.name == "bolt")
        #expect(renamed.groups[0].items == ids("f", "g"))
        #expect(renamed.groups[0].id == firstGroup)
        #expect(renamed.groups[1] == layout.groups[1])
        #expect(renamed.visible == layout.visible)
        #expect(renamed.hidden == layout.hidden)
        #expect(allIDs(renamed) == allIDs(layout))
    }

    @Test func setSymbolOnAnUnknownGroupIsRejected() throws {
        let missing = UUID()
        #expect(throws: LayoutEditError.unknownGroup(missing)) {
            try LayoutEditing.setSymbol(
                ofGroup: missing, in: try sample(), to: GroupSymbol(name: "bolt"))
        }
    }

    @Test func deleteGroupSendsItsItemsToTheEndOfHiddenInOrder() throws {
        let layout = try sample()
        let deleted = try LayoutEditing.deleteGroup(firstGroup, in: layout)
        #expect(deleted.hidden == ids("d", "e", "f", "g"))
        #expect(deleted.groups == [layout.groups[1]])
        #expect(deleted.visible == layout.visible)
        #expect(allIDs(deleted) == allIDs(layout))
    }

    @Test func deleteGroupNeverLosesAnItemWhicheverGroupGoes() throws {
        let layout = try sample()
        for group in layout.groups {
            let deleted = try LayoutEditing.deleteGroup(group.id, in: layout)
            #expect(allIDs(deleted) == allIDs(layout))
            #expect(deleted.hidden.suffix(group.items.count) == group.items[...])
            #expect(!deleted.groups.contains { $0.id == group.id })
        }
    }

    @Test func deleteEmptyGroupLeavesHiddenAlone() throws {
        let layout = try sample()
        let deleted = try LayoutEditing.deleteGroup(secondGroup, in: layout)
        #expect(deleted.hidden == layout.hidden)
        #expect(deleted.groups == [layout.groups[0]])
    }

    @Test func deleteUnknownGroupIsRejected() throws {
        let missing = UUID()
        #expect(throws: LayoutEditError.unknownGroup(missing)) {
            try LayoutEditing.deleteGroup(missing, in: try sample())
        }
    }
}
