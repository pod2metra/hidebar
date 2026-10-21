import AppKit

/// The menu of the separator's items: the Accessibility request (while it is off), the help, Quit.
@MainActor
final class AppMenu: NSObject {
    /// Called when the user chooses to reach the icons that are out of reach.
    var onReachIcons: () -> Void = {}

    /// Opens the menu under `statusItem`, highlighting its button while the menu is up.
    /// `reachIconsTitle` is the request's item; `nil` leaves it out.
    func show(under statusItem: NSStatusItem, reachIconsTitle: String?) {
        statusItem.menu = makeMenu(reachIconsTitle: reachIconsTitle)
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func makeMenu(reachIconsTitle: String?) -> NSMenu {
        let menu = NSMenu()
        if let reachIconsTitle {
            menu.addItem(withTitle: reachIconsTitle, action: #selector(reachIcons), keyEquivalent: "").target = self
        }
        menu.addItem(withTitle: "How to Use Hidebar…", action: #selector(showHelp), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quit Hidebar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    @objc private func reachIcons() {
        onReachIcons()
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

        Visible icons that do not fit the menu bar (behind the notch or under the app's menus) appear in a strip below it, \
        and a small orange dot on the arrow marks that some are hidden; hover the arrow to see how many. \
        Scroll the strip to see them all.

        Hidebar hides and shows icons without any permission. To click an icon in the strip it needs Accessibility; \
        while it is off, Hidebar asks when you click an icon in the strip, or when you choose "Reach Icons Behind the Notch…" in this menu.
        """
}
