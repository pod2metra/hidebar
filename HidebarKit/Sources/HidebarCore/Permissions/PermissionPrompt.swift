/// What onboarding tells the user about the Accessibility permission, and where to grant it.
public struct PermissionPrompt: Equatable, Sendable {
    public let title: String
    /// What works with the permission and what the app does without it (rule 3).
    public let detail: String
    /// The System Settings pane that holds the switch, as a URL string.
    public let settingsURL: String

    public static let accessibility = PermissionPrompt(
        title: "Accessibility",
        detail: "Lets Hidebar click the icons in the overflow strip and tell which app owns each one. Without it the section can only be collapsed and expanded, and the strip's icons are not clickable.",
        settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
}
