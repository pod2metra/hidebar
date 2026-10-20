import AppKit
import HidebarCore
import HidebarSystem

/// The menu of the separator's items: Screen Recording on request, the help, Quit.
@MainActor
final class AppMenu: NSObject {
    private let permissions: TCCPermissionChecker

    init(permissions: TCCPermissionChecker) {
        self.permissions = permissions
    }

    /// Opens the menu under `statusItem`, highlighting its button while the menu is up.
    func show(under statusItem: NSStatusItem) {
        statusItem.menu = makeMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        if !permissions.current().screenRecording {
            menu.addItem(withTitle: "Show Icon Images…", action: #selector(requestScreenRecording), keyEquivalent: "")
                .target = self
        }
        menu.addItem(withTitle: "How to Use Hidebar…", action: #selector(showHelp), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Hidebar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    /// Screen Recording is optional: it is requested only when the user asks for icon images.
    @objc private func requestScreenRecording() {
        _ = CGRequestScreenCaptureAccess()
        URL(string: PermissionPrompt.prompt(for: .screenRecording).settingsURL)
            .map { _ = NSWorkspace.shared.open($0) }
    }

    @objc private func showHelp() {
        let alert = NSAlert()
        alert.messageText = "How to Use Hidebar"
        alert.informativeText = Self.helpText
        NSApp.activate()
        alert.runModal()
    }

    static let helpText = """
        Click the arrow to hide or show the icons left of the pipe (|).

        Hold ⌘ and drag an icon to the left of the pipe to hide it, or to the right of it to keep it visible. \
        Keep the arrow right of the pipe: Hidebar will not hide the icons if the arrow would go with them.

        Right-click (or Control-click, or middle-click) the pipe or the arrow to open this menu.

        Visible icons that do not fit the menu bar (behind the notch or under the app's menus) appear in a strip below it. \
        Scroll the strip to see them all.

        Permissions: Accessibility lets you click the icons in the strip. \
        Screen Recording shows their images instead of app names; choose Show Icon Images… to turn it on.
        """
}
