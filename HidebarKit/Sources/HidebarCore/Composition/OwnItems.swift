import Foundation

/// The app's own status items (separator, toggle, one per group) as they show up in discovery.
///
/// They are found like any other item, but no layout may name them: they are never saved, shown
/// in settings or dragged. Only the separator stays visible to a move plan, as the boundary the
/// bar is arranged around.
public enum OwnItems {
    /// Must equal `PRODUCT_BUNDLE_IDENTIFIER` of the app target.
    public static let bundleID = "app.hidebar.Hidebar"
    /// The accessibility title of the separator's button; it makes the separator's id stable.
    public static let separatorTitle = "Hidebar separator"

    public static let separatorID = MenuBarItemID(ownerBundleID: bundleID, title: separatorTitle)

    /// The accessibility title of a group icon's button. It is unique per group, so discovery
    /// gives every group icon an id of its own.
    public static func groupTitle(_ group: ItemGroup) -> String {
        "Hidebar group \(group.symbol.name) \(group.id.uuidString)"
    }

    public static func isOwn(_ id: MenuBarItemID) -> Bool {
        id.ownerBundleID == bundleID
    }

    /// Items of other apps: the only ones a layout may name.
    public static func foreign(_ items: [DiscoveredItem]) -> [DiscoveredItem] {
        items.filter { !isOwn($0.item.id) }
    }

    /// The bar as a move plan sees it: other apps' items plus our separator.
    public static func planItems(_ items: [DiscoveredItem]) -> [MenuBarItem] {
        items.filter { !isOwn($0.item.id) || $0.item.id == separatorID }.map(\.item)
    }
}
