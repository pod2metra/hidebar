/// The sentences the app shows when something did not work out, so the windows only display them.
public enum UserMessages {
    public static func text(for failure: ApplyFailure) -> String {
        switch failure {
        case .separatorUnavailable:
            "The Hidebar separator is not on the menu bar or cannot be moved, so the icons were not arranged. Grant Accessibility access and try again."
        case .moveStopped(let index, let item, let outcome):
            "Step \(index + 1) failed: \(item.displayName) \(text(for: outcome)). Nothing was saved."
        case .storeRefused(let error):
            text(for: error)
        case .storeFailed(let reason):
            "The layout could not be saved: \(reason)"
        }
    }

    public static func text(for refusal: ApplyRefusal) -> String {
        switch refusal {
        case .displacedIconPending:
            "An icon you clicked earlier could not be put back in its place yet, so nothing was moved or saved. Try again in a moment."
        }
    }

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

    public static func text(for outcome: MoveOutcome) -> String {
        switch outcome {
        case .moved: "moved"
        case .unmovable: "cannot be moved"
        case .failed: "did not end up in place"
        }
    }

    public static func text(for error: LayoutStoreError) -> String {
        switch error {
        case .unsupportedVersion(let version), .refusingToOverwriteNewerVersion(let version):
            "The saved layout (version \(version)) was written by a different version of Hidebar. It is left untouched and nothing will be saved."
        }
    }

    /// For a rejected edit of the draft, such as a drop that is not allowed.
    public static func text(forEditError error: any Error) -> String {
        guard let edit = error as? LayoutEditError else { return "The change was rejected: \(error)" }
        switch edit {
        case .unknownItem: return "That icon is no longer in the layout."
        case .unknownGroup: return "That group no longer exists."
        case .notHidable(let id): return "\(id.displayName) must stay on the menu bar."
        case .indexOutOfRange: return "The icon cannot be dropped there."
        }
    }

    /// Something to tell the user about how the stored layout was loaded; `nil` when all is well.
    public static func notice(for status: LayoutLoadStatus) -> String? {
        switch status {
        case .missing, .loaded:
            nil
        case .recoveredFromCorruption:
            "The saved layout could not be read, so Hidebar started with an empty one. The unreadable data is kept as a backup."
        }
    }
}
