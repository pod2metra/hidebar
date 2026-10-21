/// What the arrow shows about the icons that do not fit the bar: a badge and a tooltip while
/// there are any, nothing otherwise.
///
/// The count is the strip's rows: visible icons that no longer fit, behind the notch or under the
/// frontmost app's menus. It needs no permission; the menus' extent is only known with
/// Accessibility, so without it only what the notch covers is counted.
public struct NotchIndicator: Equatable, Sendable {
    public let hiddenCount: Int
    /// `true` when the icons can be clicked from the strip: Accessibility is on.
    public let canReach: Bool

    public init(hiddenCount: Int, canReach: Bool) {
        self.hiddenCount = hiddenCount
        self.canReach = canReach
    }

    public var isShown: Bool { hiddenCount > 0 }

    /// `nil` while nothing is hidden.
    public var tooltip: String? {
        guard isShown else { return nil }
        let single = hiddenCount == 1
        let subject = single ? "1 icon is" : "\(hiddenCount) icons are"
        let it = single ? "it" : "them"
        let place = "behind the notch or the app's menus."
        if canReach { return "\(subject) \(place) Click \(it) in the strip below the menu bar." }
        return "\(subject) \(place) To click \(it), right-click the arrow and choose \(PermissionPrompt.reachIconsTitle)"
    }
}
