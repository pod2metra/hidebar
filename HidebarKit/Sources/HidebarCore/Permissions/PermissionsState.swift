/// What the app can do with the current permissions.
public struct Capabilities: Sendable, Equatable {
    /// Hiding via the separator needs no permission.
    public let canHide: Bool
    /// Synthetic drag needs Accessibility.
    public let canMove: Bool
    /// The real owner of a status item window is only visible through Accessibility on macOS 26.
    public let canIdentifyOwners: Bool
}

/// The permissions currently granted to the app: Accessibility is the only one it asks for.
public struct PermissionsState: Sendable, Equatable {
    public let accessibility: Bool

    public init(accessibility: Bool) {
        self.accessibility = accessibility
    }

    public var capabilities: Capabilities {
        Capabilities(canHide: true, canMove: accessibility, canIdentifyOwners: accessibility)
    }
}
