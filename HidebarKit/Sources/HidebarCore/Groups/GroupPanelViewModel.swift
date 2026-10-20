public struct GroupPanelRow: Equatable {
    public enum Content: Equatable {
        /// The icon's own image.
        case snapshot(SnapshotImage)
        /// The app name and icon, drawn from the id's bundle; used without a snapshot.
        case appName
        /// The icon is not in the current discovery, typically because it is hidden off-screen.
        case unavailable
    }

    public let id: MenuBarItemID
    public let name: String
    public internal(set) var content: Content
    public let isClickable: Bool
}

/// Rows of one group's panel. Each row comes from the group's stored ids, so an
/// icon that discovery misses (hidden off-screen) stays visible as `.unavailable`.
@MainActor
public final class GroupPanelViewModel {
    public private(set) var rows: [GroupPanelRow] = []

    /// True when the group holds no icons at all: the panel shows its empty state.
    public var isEmpty: Bool { rows.isEmpty }

    private let snapshotter: any Snapshotting
    private var generation = 0

    public init(snapshotter: any Snapshotting) {
        self.snapshotter = snapshotter
    }

    /// Rebuilds the rows at once, then upgrades them to snapshots one by one.
    /// A newer call supersedes this one: its late snapshots are dropped.
    public func refresh(
        group: ItemGroup, items: [DiscoveredItem], capabilities: Capabilities
    ) async {
        generation += 1
        let mine = generation
        let matches = group.items.map { Self.match($0, in: items, capabilities: capabilities) }
        rows = zip(group.items, matches).map { Self.row(for: $0, match: $1, capabilities: capabilities) }
        guard capabilities.panelPresentation == .snapshots else { return }
        await loadSnapshots(for: matches, generation: mine)
    }

    private func loadSnapshots(for matches: [DiscoveredItem?], generation mine: Int) async {
        for (index, match) in matches.enumerated() {
            guard let match else { continue }
            let image = await snapshotter.snapshot(ofWindow: match.windowID)
            guard mine == generation else { return }
            if let image { rows[index].content = .snapshot(image) }
        }
    }

    private static func match(
        _ id: MenuBarItemID, in items: [DiscoveredItem], capabilities: Capabilities
    ) -> DiscoveredItem? {
        guard capabilities.canIdentifyOwners else { return nil }
        return items.managedItem(id)
    }

    private static func row(
        for id: MenuBarItemID, match: DiscoveredItem?, capabilities: Capabilities
    ) -> GroupPanelRow {
        let name = id.displayName
        guard capabilities.canIdentifyOwners else {
            return GroupPanelRow(id: id, name: name, content: .appName, isClickable: false)
        }
        guard let match else {
            return GroupPanelRow(id: id, name: name, content: .unavailable, isClickable: false)
        }
        return GroupPanelRow(
            id: id, name: name, content: .appName,
            isClickable: capabilities.canMove && match.item.isMovable)
    }
}
