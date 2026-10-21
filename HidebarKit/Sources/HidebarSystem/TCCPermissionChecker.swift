import ApplicationServices
import HidebarCore

/// Reads the Accessibility permission without prompting: the check only reports the current grant.
public struct TCCPermissionChecker: Sendable {
    public init() {}

    public func current() -> PermissionsState {
        PermissionsState(accessibility: AXIsProcessTrusted())
    }
}
