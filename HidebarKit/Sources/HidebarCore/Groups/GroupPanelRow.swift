/// One row of the overflow strip: an icon with the name to show for it.
public struct GroupPanelRow: Equatable {
    public enum Content: Equatable {
        /// The icon's own image.
        case snapshot(SnapshotImage)
        /// The app name and icon, drawn from the id's bundle; used without a snapshot.
        case appName
    }

    public let id: MenuBarItemID
    public let name: String
    public internal(set) var content: Content
    public let isClickable: Bool
}
