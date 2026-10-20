/// What onboarding tells the user about one permission, and where to grant it.
public struct PermissionPrompt: Equatable, Sendable {
    public let title: String
    /// What works with the permission and what the app does without it (rule 3).
    public let detail: String
    /// The System Settings pane that holds the switch, as a URL string.
    public let settingsURL: String

    public static func prompt(for permission: Permission) -> PermissionPrompt {
        switch permission {
        case .accessibility:
            PermissionPrompt(
                title: "Accessibility",
                detail: "Lets Hidebar move icons and tell which app owns each one. Without it icons can only be hidden, not arranged.",
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
        case .screenRecording:
            PermissionPrompt(
                title: "Screen Recording",
                detail: "Optional. Lets Hidebar show the real icons in the overflow strip. Without it the strip shows app names instead, and its rows still work.",
                settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
        }
    }
}
