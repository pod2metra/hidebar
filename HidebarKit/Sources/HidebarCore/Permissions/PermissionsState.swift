/// A system permission the app asks the user for, in onboarding order.
public enum Permission: Sendable, CaseIterable {
    /// Moving icons and identifying their real owners.
    case accessibility
    /// Snapshots of icons for the overflow strip.
    case screenRecording

    /// Onboarding asks only for required permissions; the others are offered on demand.
    public var isRequired: Bool {
        self == .accessibility
    }
}

/// How the overflow strip renders an icon.
public enum PanelPresentation: Sendable, Equatable {
    /// A screenshot of the icon.
    case snapshots
    /// The owning app's name and icon; used when snapshots are not allowed.
    case appNameAndIcon
}

/// What the app can do with the current permissions.
public struct Capabilities: Sendable, Equatable {
    /// Hiding via the separator needs no permission.
    public let canHide: Bool
    /// Synthetic drag needs Accessibility.
    public let canMove: Bool
    /// The real owner of a status item window is only visible through Accessibility on macOS 26.
    public let canIdentifyOwners: Bool
    /// Window snapshots need Screen Recording.
    public let canSnapshot: Bool

    public var panelPresentation: PanelPresentation {
        canSnapshot ? .snapshots : .appNameAndIcon
    }
}

/// Permissions that changed between two observations.
public struct PermissionsTransition: Sendable, Equatable {
    public let gained: [Permission]
    public let lost: [Permission]
}

/// The permissions currently granted to the app.
public struct PermissionsState: Sendable, Equatable {
    public let accessibility: Bool
    public let screenRecording: Bool

    public init(accessibility: Bool, screenRecording: Bool) {
        self.accessibility = accessibility
        self.screenRecording = screenRecording
    }

    public var capabilities: Capabilities {
        Capabilities(
            canHide: true,
            canMove: accessibility,
            canIdentifyOwners: accessibility,
            canSnapshot: screenRecording
        )
    }

    /// Required permissions not granted yet, in onboarding order.
    public var missingRequired: [Permission] {
        Permission.allCases.filter { $0.isRequired && !isGranted($0) }
    }

    /// Compares with an earlier state, for re-prompt handling: macOS periodically revokes Screen Recording.
    public func transition(from previous: PermissionsState) -> PermissionsTransition {
        PermissionsTransition(
            gained: Permission.allCases.filter { isGranted($0) && !previous.isGranted($0) },
            lost: Permission.allCases.filter { !isGranted($0) && previous.isGranted($0) }
        )
    }

    public func isGranted(_ permission: Permission) -> Bool {
        switch permission {
        case .accessibility: accessibility
        case .screenRecording: screenRecording
        }
    }
}
