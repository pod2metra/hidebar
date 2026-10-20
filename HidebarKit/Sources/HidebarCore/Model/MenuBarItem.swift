/// Identity of a menu bar item that survives relaunches of the app and of the item's owner.
///
/// The ID is the owner's bundle identifier plus the item's title, both taken verbatim.
/// It deliberately knows nothing about window ids, pids or positions: those change on every
/// launch, and on macOS 26 the window owner is Control Center for every item, so the real
/// owner has to come from Accessibility and is supplied by the discovery layer.
///
/// An item without a title is keyed by its owner alone (`title == ""`). No index is used as a
/// fallback because an index shifts when any other item appears or disappears. Consequence:
/// two untitled items of one owner are indistinguishable and share one ID.
public struct MenuBarItemID: Hashable, Codable, Sendable {
    public let ownerBundleID: String
    public let title: String

    public init(ownerBundleID: String, title: String) {
        self.ownerBundleID = ownerBundleID
        self.title = title
    }
}

/// Screen-space rectangle of an item, in points. Plain values so the model needs no CoreGraphics.
public struct ItemFrame: Hashable, Codable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// A menu bar item as observed right now. Not persisted.
public struct MenuBarItem: Equatable, Sendable {
    public let id: MenuBarItemID
    public let frame: ItemFrame
    /// `false` for system items that must not be dragged (clock, Control Center) and for
    /// unmanaged items, whose identity is unreliable (see `ItemDiscovery.discover`).
    public let isMovable: Bool

    public init(id: MenuBarItemID, frame: ItemFrame, isMovable: Bool) {
        self.id = id
        self.frame = frame
        self.isMovable = isMovable
    }
}
