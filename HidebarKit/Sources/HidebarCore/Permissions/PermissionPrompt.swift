/// What the app tells the user when it asks for Accessibility, and where to grant it. It asks only
/// when the user tries to reach an icon that is out of reach, never at launch.
public struct PermissionPrompt: Equatable, Sendable {
    public let title: String
    /// Why the app asks, and what keeps working without the permission (rule 3).
    public let detail: String
    /// The System Settings pane that holds the switch, as a URL string.
    public let settingsURL: String

    /// The menu item that starts the request; it is only there while Accessibility is off.
    public static let reachIconsTitle = "Reach Icons Behind the Notch…"

    public static let accessibility = PermissionPrompt(
        title: "Accessibility",
        detail: "Hidebar needs it to click icons that are behind the notch or under the app's menus: it moves an icon into view, clicks it and puts it back. Hiding and showing icons works without it.",
        settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

    /// True while the permission is missing, so the request is worth showing.
    public static func isNeeded(in state: PermissionsState) -> Bool {
        !state.accessibility
    }

    /// The title of the menu item that asks for Accessibility; `nil` once it is granted.
    public static func reachIconsMenuTitle(for state: PermissionsState) -> String? {
        isNeeded(in: state) ? reachIconsTitle : nil
    }
}
