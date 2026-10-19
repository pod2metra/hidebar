import Foundation

/// One of the lists of a `Layout` an item can live in.
public enum Placement: Hashable, Sendable {
    case visible
    case hidden
    case group(UUID)
}

public enum LayoutEditError: Error, Equatable, Sendable {
    case unknownItem(MenuBarItemID)
    case unknownGroup(UUID)
    /// The item must stay on the bar (`MenuBarItem.isHidable == false`).
    case notHidable(MenuBarItemID)
    /// The index is outside `0...count` of the destination list once the item has left its old place.
    case indexOutOfRange(Int)
}

/// Edits of a `Layout` as pure functions: each returns a new layout that went through `Layout`'s
/// validating initializer, or throws and leaves the input as it was.
///
/// Every edit keeps each ID in exactly one place and never drops one. Besides `LayoutEditError`,
/// an edit can throw the `LayoutError` of that initializer (`createGroup` with a taken group ID).
public enum LayoutEditing {
    /// Takes `item` out of wherever it is and puts it at `index` of `placement`.
    ///
    /// `index` counts in the destination list without the item, so a move inside one list is a
    /// reorder. An item in `nonHidable` may only go to `.visible`: everywhere else it is hidden.
    public static func move(
        _ item: MenuBarItemID, in layout: Layout, to placement: Placement, at index: Int,
        nonHidable: Set<MenuBarItemID> = []
    ) throws -> Layout {
        var sections = Sections(layout)
        guard let origin = sections.placement(of: item) else {
            throw LayoutEditError.unknownItem(item)
        }
        if placement != .visible && nonHidable.contains(item) {
            throw LayoutEditError.notHidable(item)
        }
        try sections.remove(item, from: origin)
        try sections.edit(placement) { list in
            guard (0...list.count).contains(index) else { throw LayoutEditError.indexOutOfRange(index) }
            list.insert(item, at: index)
        }
        return try sections.layout()
    }

    /// Moves `item` to `index` within the list it is already in; it never changes what is hidden.
    public static func reorder(_ item: MenuBarItemID, in layout: Layout, to index: Int) throws -> Layout {
        guard let origin = Sections(layout).placement(of: item) else {
            throw LayoutEditError.unknownItem(item)
        }
        return try move(item, in: layout, to: origin, at: index)
    }

    /// `layout` plus an empty group labelled `symbol`, last in group order.
    public static func createGroup(in layout: Layout, symbol: GroupSymbol, id: UUID) throws -> Layout {
        try Layout(
            visible: layout.visible, hidden: layout.hidden,
            groups: layout.groups + [ItemGroup(id: id, symbol: symbol, items: [])])
    }

    /// Relabels a group: the symbol is the group's only name.
    public static func setSymbol(
        ofGroup id: UUID, in layout: Layout, to symbol: GroupSymbol
    ) throws -> Layout {
        let target = try group(id, in: layout)
        return try Layout(
            visible: layout.visible, hidden: layout.hidden,
            groups: layout.groups.map {
                $0.id == id ? ItemGroup(id: id, symbol: symbol, items: target.items) : $0
            })
    }

    /// Removes a group. Its items go to the end of `hidden`: deleting never loses an icon, and
    /// the icons stay out of the way the group kept them out of.
    public static func deleteGroup(_ id: UUID, in layout: Layout) throws -> Layout {
        let target = try group(id, in: layout)
        return try Layout(
            visible: layout.visible, hidden: layout.hidden + target.items,
            groups: layout.groups.filter { $0.id != id })
    }

    private static func group(_ id: UUID, in layout: Layout) throws -> ItemGroup {
        guard let found = layout.groups.first(where: { $0.id == id }) else {
            throw LayoutEditError.unknownGroup(id)
        }
        return found
    }
}

/// The lists of a `Layout` as mutable values, so an edit can change one list by `Placement`.
private struct Sections {
    var visible: [MenuBarItemID]
    var hidden: [MenuBarItemID]
    var groups: [ItemGroup]

    init(_ layout: Layout) {
        visible = layout.visible
        hidden = layout.hidden
        groups = layout.groups
    }

    func placement(of item: MenuBarItemID) -> Placement? {
        if visible.contains(item) { return .visible }
        if hidden.contains(item) { return .hidden }
        return groups.first { $0.items.contains(item) }.map { .group($0.id) }
    }

    mutating func remove(_ item: MenuBarItemID, from placement: Placement) throws {
        try edit(placement) { list in
            list.removeAll { $0 == item }
        }
    }

    mutating func edit(
        _ placement: Placement, _ change: (inout [MenuBarItemID]) throws -> Void
    ) throws {
        switch placement {
        case .visible:
            try change(&visible)
        case .hidden:
            try change(&hidden)
        case .group(let id):
            guard let position = groups.firstIndex(where: { $0.id == id }) else {
                throw LayoutEditError.unknownGroup(id)
            }
            var items = groups[position].items
            try change(&items)
            groups[position] = ItemGroup(id: id, symbol: groups[position].symbol, items: items)
        }
    }

    func layout() throws -> Layout {
        try Layout(visible: visible, hidden: hidden, groups: groups)
    }
}
