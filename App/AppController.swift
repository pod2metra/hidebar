import AppKit
import HidebarCore
import HidebarSystem

/// Connects what the user does (clicks, coming back to the app) to the core, and the core's
/// answers to windows. It decides nothing itself: the order of work is `AppComposition`'s.
@MainActor
final class AppController: NSObject {
    private let services = AppServices()
    private let strip: OverflowStripWindow
    private let accessibilityRequest = AccessibilityRequest()
    private let menu: AppMenu
    private var permissions: PermissionsState

    override init() {
        strip = OverflowStripWindow(services: services)
        menu = AppMenu()
        permissions = services.permissions.current()
        super.init()
        services.separatorItems.onArrowClick = { [weak self] in self?.arrowClicked() }
        services.separatorItems.onMenuRequest = { [weak self] item in self?.showMenu(under: item) }
        menu.onReachIcons = { [weak self] in self?.requestAccessibility() }
        strip.onRowClick = { [weak self] activation in self?.handle(activation) }
        strip.onIndicatorChange = { [separatorItems = services.separatorItems] in separatorItems.show($0) }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(screensChanged), name: NSWorkspace.didActivateApplicationNotification,
            object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
    }

    /// Nothing is asked of the user at launch: hiding works without any permission.
    func start() {
        strip.barDidChange()
    }

    /// Restoring the pipe comes first: icons must be visible whatever else fails.
    func stop() {
        services.separatorItems.controller.prepareForTermination()
        services.composition.restoreIfDisplaced()
        services.separatorItems.invalidate()
    }

    /// The user came back to the app, possibly from System Settings.
    func permissionsMayHaveChanged() {
        let now = services.permissions.current()
        guard now != permissions else { return }
        permissions = now
        strip.barDidChange()
    }

    /// The user launched the app again (Finder, Spotlight), typically because the arrow is out of
    /// reach: everything comes back.
    func reopened() {
        services.composition.expand()
        services.separatorItems.showArrow(collapsed: false)
    }

    /// Collapses or expands the section. The core refuses to collapse when that would strand the
    /// arrow; the section then stays expanded.
    private func arrowClicked() {
        let composition = services.composition
        let items = services.separatorItems
        if composition.isCollapsed {
            composition.expand()
        } else if let refusal = composition.collapse(pipeX: items.pipeX, arrowX: items.arrowX) {
            show(message: UserMessages.text(for: refusal))
        }
        items.showArrow(collapsed: composition.isCollapsed)
    }

    /// The request is in the menu only while Accessibility is off.
    private func showMenu(under item: NSStatusItem) {
        let title = PermissionPrompt.reachIconsMenuTitle(for: services.permissions.current())
        menu.show(under: item, reachIconsTitle: title)
    }

    private func handle(_ activation: RowActivation) {
        switch activation {
        case .outcome(let outcome): UserMessages.text(for: outcome).map(show(message:))
        case .accessibilityNeeded: requestAccessibility()
        }
    }

    /// Asks for Accessibility. Rows drawn before a grant was noticed still ask: the grant is looked
    /// at again first, and when it is there the rows are rebuilt instead of showing the request.
    private func requestAccessibility() {
        guard PermissionPrompt.isNeeded(in: services.permissions.current()) else {
            permissionsMayHaveChanged()
            return
        }
        accessibilityRequest.ask()
    }

    /// The screens or the app that owns the menu bar changed: the room for icons changed with them.
    @objc private func screensChanged() {
        strip.barDidChange()
    }

    private func show(message: String) {
        let alert = NSAlert()
        alert.messageText = "Hidebar"
        alert.informativeText = message
        NSApp.activate()
        alert.runModal()
    }
}
