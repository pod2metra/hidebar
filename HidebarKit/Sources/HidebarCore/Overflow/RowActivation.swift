/// What a click on a row of the overflow strip came to.
public enum RowActivation: Equatable, Sendable {
    /// The icon was clicked, or the click was refused; the outcome says which.
    case outcome(ClickOutcome)
    /// Accessibility is off: nothing was clicked, the app should ask for the permission.
    case accessibilityNeeded
}
