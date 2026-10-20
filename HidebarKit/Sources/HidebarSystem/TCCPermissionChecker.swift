import ApplicationServices
import CoreGraphics
import HidebarCore

/// Reads the two permissions without prompting: the checks only report the current grant.
public struct TCCPermissionChecker: Sendable {
    public init() {}

    public func current() -> PermissionsState {
        PermissionsState(
            accessibility: AXIsProcessTrusted(), screenRecording: CGPreflightScreenCaptureAccess())
    }
}
