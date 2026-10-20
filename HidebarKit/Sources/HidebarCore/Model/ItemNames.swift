/// Name of an installed app as its user knows it, looked up by bundle identifier.
public protocol AppNaming: Sendable {
    /// `nil` when no app with that identifier is installed or it has no name.
    func name(ofBundleID bundleID: String) -> String?
}

/// What the app shows for a menu bar item: the app's name, never the bundle identifier unless the
/// app is unknown. Names are for display only; an item's identity stays its `MenuBarItemID`.
public struct ItemNames: Sendable {
    private let apps: any AppNaming

    public init(apps: any AppNaming) {
        self.apps = apps
    }

    /// The app's name, followed by " — " and the item's title when the title adds something
    /// (Control Center lists many items under one app). A title that only repeats the app's
    /// name, ignoring case, is left out.
    public func name(of id: MenuBarItemID) -> String {
        let known = apps.name(ofBundleID: id.ownerBundleID) ?? ""
        let app = known.isEmpty ? id.ownerBundleID : known
        guard !id.title.isEmpty, id.title.lowercased() != app.lowercased() else { return app }
        return "\(app) — \(id.title)"
    }
}
