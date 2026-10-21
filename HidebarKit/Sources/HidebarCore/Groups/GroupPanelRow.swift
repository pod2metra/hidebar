/// One row of the overflow strip: the owning app's name and icon, drawn from the id's bundle.
public struct GroupPanelRow: Equatable {
    public let id: MenuBarItemID
    public let name: String
    public let isClickable: Bool
    /// A click on the row asks for Accessibility: the permission is off, so nothing can be told or moved.
    public let needsAccessibility: Bool

    /// The row reacts to a click: it clicks its icon, or asks for the permission that would let it.
    public var isEnabled: Bool { isClickable || needsAccessibility }
}
