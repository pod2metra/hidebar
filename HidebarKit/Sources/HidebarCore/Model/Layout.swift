import Foundation

/// An ordered set of hidden items collected under one menu bar symbol.
public struct ItemGroup: Equatable, Codable, Sendable {
    public let id: UUID
    public let symbol: GroupSymbol
    public let items: [MenuBarItemID]

    public init(id: UUID, symbol: GroupSymbol, items: [MenuBarItemID]) {
        self.id = id
        self.symbol = symbol
        self.items = items
    }
}

public enum LayoutError: Error, Equatable, Sendable {
    /// The item appears more than once across `visible`, `hidden` and all groups.
    case duplicateItem(MenuBarItemID)
    case duplicateGroup(UUID)
}

/// Where every known item lives: on the bar, hidden behind the separator, or in a group.
///
/// Invariant: an item ID appears at most once across `visible`, `hidden` and every group's
/// items, and group IDs are unique. It is enforced by the only public initializer (and by
/// decoding, which goes through it), so a `Layout` value is always consistent. A violation is
/// reported as an error; no ID is ever dropped to make a layout fit.
public struct Layout: Equatable, Codable, Sendable {
    public static let currentVersion = 1

    public static let empty = Layout(visible: [], hidden: [], groups: [], checked: ())

    public let version: Int
    public let visible: [MenuBarItemID]
    public let hidden: [MenuBarItemID]
    public let groups: [ItemGroup]

    public init(
        visible: [MenuBarItemID], hidden: [MenuBarItemID], groups: [ItemGroup]
    ) throws {
        var seenGroups: Set<UUID> = []
        for group in groups where !seenGroups.insert(group.id).inserted {
            throw LayoutError.duplicateGroup(group.id)
        }
        var seenItems: Set<MenuBarItemID> = []
        for id in visible + hidden + groups.flatMap(\.items) where !seenItems.insert(id).inserted {
            throw LayoutError.duplicateItem(id)
        }
        self.init(visible: visible, hidden: hidden, groups: groups, checked: ())
    }

    private init(
        visible: [MenuBarItemID], hidden: [MenuBarItemID], groups: [ItemGroup], checked: Void
    ) {
        version = Layout.currentVersion
        self.visible = visible
        self.hidden = hidden
        self.groups = groups
    }

    private enum CodingKeys: String, CodingKey {
        case version, visible, hidden, groups
    }

    /// Decodes a layout of the current version only; other versions are migrated by `LayoutStore`.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .version)
        guard version == Layout.currentVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .version, in: container,
                debugDescription: "expected layout version \(Layout.currentVersion), got \(version)")
        }
        try self.init(
            visible: container.decode([MenuBarItemID].self, forKey: .visible),
            hidden: container.decode([MenuBarItemID].self, forKey: .hidden),
            groups: container.decode([ItemGroup].self, forKey: .groups))
    }
}
