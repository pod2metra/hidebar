import Foundation

/// One line of the settings list: a section header or an icon under it.
public enum SettingsRow: Equatable, Sendable {
    /// `symbolName` is the SF Symbol of a group section; `nil` for the two plain lists.
    case header(placement: Placement, title: String, symbolName: String?)
    case item(MenuBarItemID, placement: Placement)

    fileprivate func holds(_ id: MenuBarItemID) -> Bool {
        guard case .item(let held, _) = self else { return false }
        return held == id
    }
}

/// Where a dragged icon lands: `index` counts in the destination list without the dragged icon,
/// the way `SettingsViewModel.move` expects it.
public struct SettingsDrop: Equatable, Sendable {
    public let placement: Placement
    public let index: Int
}

/// The sections of the settings window flattened into the rows of one list, and the mapping
/// between a row position (what a table reports for a drag) and a place in the layout.
public struct SettingsRows: Equatable, Sendable {
    public let rows: [SettingsRow]

    public init(sections: [SettingsSection]) {
        rows = sections.flatMap { section in
            [SettingsRow.header(
                placement: section.placement, title: Self.title(of: section.placement),
                symbolName: section.symbol?.name)]
                + section.items.map { SettingsRow.item($0, placement: section.placement) }
        }
    }

    private static func title(of placement: Placement) -> String {
        switch placement {
        case .visible: "On the menu bar"
        case .hidden: "Hidden"
        case .group: "Group"
        }
    }

    public func item(atRow row: Int) -> MenuBarItemID? {
        guard rows.indices.contains(row), case .item(let id, _) = rows[row] else { return nil }
        return id
    }

    /// The group whose header is at `row`.
    public func groupID(atRow row: Int) -> UUID? {
        guard rows.indices.contains(row), case .header(.group(let id), _, _) = rows[row] else { return nil }
        return id
    }

    /// The place for `item` when it is dropped between row `row - 1` and row `row`.
    ///
    /// A drop right under a header is the start of that header's section, and a drop above the
    /// next header is the end of the section before it, so an empty section can be filled.
    ///
    /// Dragging an icon down inside its own section leaves a gap above the drop point, so the
    /// index shrinks by one: `SettingsViewModel.move` counts without the dragged icon.
    public func drop(of item: MenuBarItemID, aboveRow row: Int) -> SettingsDrop? {
        // The last header above the drop point, or the first one when the drop is above them all.
        guard let source = rows.firstIndex(where: { $0.holds(item) }),
            let header = rows.indices.prefix(max(row, 0)).last(where: isHeader(at:))
                ?? rows.indices.first(where: isHeader(at:))
        else { return nil }
        var index = row - header - 1
        if placement(at: source) == placement(at: header) && source < row { index -= 1 }
        return SettingsDrop(placement: placement(at: header), index: max(index, 0))
    }

    private func isHeader(at row: Int) -> Bool {
        guard case .header = rows[row] else { return false }
        return true
    }

    private func placement(at row: Int) -> Placement {
        switch rows[row] {
        case .header(let placement, _, _), .item(_, let placement): placement
        }
    }
}
