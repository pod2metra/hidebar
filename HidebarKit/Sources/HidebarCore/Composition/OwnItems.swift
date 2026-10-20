import Foundation

/// The app's own status items (the separator and its arrow) as they show up in discovery.
///
/// They are found like any other item, but are never members of anything: they are never dragged.
public enum OwnItems {
    /// Must equal `PRODUCT_BUNDLE_IDENTIFIER` of the app target.
    public static let bundleID = "app.hidebar.Hidebar"
    /// The accessibility title of the separator's button; it makes the separator's id stable.
    public static let separatorTitle = "Hidebar separator"

    public static let separatorID = MenuBarItemID(ownerBundleID: bundleID, title: separatorTitle)

    public static func isOwn(_ id: MenuBarItemID) -> Bool {
        id.ownerBundleID == bundleID
    }

    /// Items of other apps.
    public static func foreign(_ items: [DiscoveredItem]) -> [DiscoveredItem] {
        items.filter { !isOwn($0.item.id) }
    }
}
