import AppKit
import ApplicationServices
import HidebarCore

/// Asks for Accessibility while it is missing: a button registers the app in the permission's
/// list in System Settings and opens that pane. The window closes by itself once it is granted.
@MainActor
final class OnboardingWindow: NSObject {
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 440, height: 100),
        styleMask: [.titled, .closable], backing: .buffered, defer: true)

    override init() {
        super.init()
        window.title = "Welcome to Hidebar"
        window.isReleasedWhenClosed = false
    }

    /// Shows the Accessibility request while `state` lacks it, or closes the window when it is granted.
    func update(_ state: PermissionsState) {
        guard !state.accessibility else {
            window.orderOut(nil)
            return
        }
        let intro = NSTextField(
            wrappingLabelWithString:
                "Hidebar still works without this permission, with fewer features. "
                + "Switch it on in System Settings, then come back to this app.")
        let root = NSStackView(views: [intro, accessibilityBlock()])
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

    private func accessibilityBlock() -> NSView {
        let prompt = PermissionPrompt.accessibility
        let title = NSTextField(labelWithString: prompt.title)
        title.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        let detail = NSTextField(wrappingLabelWithString: prompt.detail)
        detail.preferredMaxLayoutWidth = 400
        let button = NSButton(title: "Open System Settings", target: self, action: #selector(open))
        let column = NSStackView(views: [title, detail, button])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 4
        return column
    }

    @objc private func open() {
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        URL(string: PermissionPrompt.accessibility.settingsURL).map { _ = NSWorkspace.shared.open($0) }
    }
}
