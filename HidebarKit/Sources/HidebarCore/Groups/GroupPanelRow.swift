/// One row of the overflow strip: the owning app's name and icon, drawn from the id's bundle.
public struct GroupPanelRow: Equatable {
    public let id: MenuBarItemID
    public let name: String
    public let isClickable: Bool
}
