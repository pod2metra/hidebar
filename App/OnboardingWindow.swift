import AppKit
import ApplicationServices
import HidebarCore

/// Lists the permissions that are still missing, each with a button that asks the system for it
/// and opens the System Settings pane. The window closes by itself once nothing is missing.
@MainActor
final class OnboardingWindow: NSObject {
    private final class PermissionButton: NSButton {
        var permission = Permission.accessibility
    }

    /// Registers the app in the permission's list in System Settings; the user still has to
    /// switch it on there.
    private static let requests: [Permission: () -> Void] = [
        .accessibility: { _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) },
        .screenRecording: { _ = CGRequestScreenCaptureAccess() },
    ]

    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 440, height: 100),
        styleMask: [.titled, .closable], backing: .buffered, defer: true)

    override init() {
        super.init()
        window.title = "Welcome to Hidebar"
        window.isReleasedWhenClosed = false
    }

    /// Shows the missing permissions of `state`, or closes the window when there are none.
    func update(_ state: PermissionsState) {
        guard !state.missing.isEmpty else {
            window.orderOut(nil)
            return
        }
        let intro = NSTextField(
            wrappingLabelWithString:
                "Hidebar still works without these permissions, with fewer features. "
                + "Switch them on in System Settings, then come back to this app.")
        let root = NSStackView(views: [intro] + state.missing.map(block(for:)))
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        window.contentView = root
        window.setContentSize(root.fittingSize)
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func block(for permission: Permission) -> NSView {
        let prompt = PermissionPrompt.prompt(for: permission)
        let title = NSTextField(labelWithString: prompt.title)
        title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        let detail = NSTextField(wrappingLabelWithString: prompt.detail)
        detail.preferredMaxLayoutWidth = 400
        let button = PermissionButton(title: "Open System Settings", target: self, action: #selector(open(_:)))
        button.permission = permission
        let column = NSStackView(views: [title, detail, button])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 4
        return column
    }

    @objc private func open(_ sender: PermissionButton) {
        Self.requests[sender.permission]?()
        URL(string: PermissionPrompt.prompt(for: sender.permission).settingsURL)
            .map { _ = NSWorkspace.shared.open($0) }
    }
}
