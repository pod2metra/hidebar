/// The sentences the app shows when something did not work out, so the windows only display them.
public enum UserMessages {
    /// What to tell the user after a click on a hidden icon; `nil` when it went through.
    public static func text(for outcome: ClickOutcome) -> String? {
        switch outcome {
        case .clicked:
            nil
        case .refused(let reason):
            text(for: reason)
        case .revealFailed:
            "Hidebar could not bring that icon within reach. It was left where it was."
        case .clickFailed:
            "The click could not be sent to that icon."
        }
    }

    public static func text(for refusal: ClickRefusal) -> String {
        switch refusal {
        case .displacedItemPending:
            "Another icon is still out of its place and could not be put back yet. Try again in a moment."
        case .notManaged:
            "Hidebar cannot tell which app owns that icon, so it did not click it. Grant Accessibility access first."
        case .unmovable:
            "That icon is a system item and cannot be moved to be clicked."
        case .noHomeAnchor:
            "There is no other icon to put it back next to, so it was not moved."
        case .notLocated:
            "That icon is not on the menu bar right now."
        }
    }

    public static func text(for refusal: CollapseRefusal) -> String {
        switch refusal {
        case .separatorNotOnBar:
            "Hidebar's separator or arrow is not on the menu bar, so the icons were left shown."
        case .arrowWouldHide:
            "Hidebar's arrow is left of the separator and would be hidden with the icons, and you could not show them again. Drag the arrow to the right of the separator, then try again."
        }
    }

}
