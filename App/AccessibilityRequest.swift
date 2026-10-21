import AppKit
import ApplicationServices
import HidebarCore

/// Asks for Accessibility at the moment the user wants to reach an icon that is out of reach, and
/// says why. Nothing asks at launch: hiding works without the permission.
///
/// "Open System Settings" registers the app in the permission's list and opens that pane. The grant
/// is picked up when the user comes back to the app (`AppDelegate.applicationDidBecomeActive`).
@MainActor
final class AccessibilityRequest {
    func ask() {
        let prompt = PermissionPrompt.accessibility
        let alert = NSAlert()
        alert.messageText = "Hidebar needs \(prompt.title) access to reach these icons"
        alert.informativeText = prompt.detail
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Not Now")
        NSApp.activate()
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        URL(string: prompt.settingsURL).map { _ = NSWorkspace.shared.open($0) }
    }
}
