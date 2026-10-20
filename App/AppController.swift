import AppKit
import HidebarCore
import HidebarSystem

/// Connects what the user does (clicks, menu items, coming back to the app) to the core, and the
/// core's answers to windows. It decides nothing itself: the order of work is `AppComposition`'s.
@MainActor
final class AppController: NSObject {
    private let services = AppServices()
    private let panel: GroupPanelWindow
    private let strip: OverflowStripWindow
    private let onboarding = OnboardingWindow()
    private var settings: SettingsWindow?
    /// The saved layout: it names the groups the status items and panels are built from.
    private var layout = Layout.empty
    private var permissions: PermissionsState

    override init() {
        panel = GroupPanelWindow(snapshotter: services.snapshotter)
        strip = OverflowStripWindow(services: services)
        permissions = services.permissions.current()
        super.init()
        services.groupItems.onClick = { [weak self] id, button in self?.groupClicked(id, button) }
        panel.onRowClick = { [weak self] id in self?.iconClicked(id) }
        strip.onRowClick = { [weak self] outcome in self?.show(outcome) }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(screensChanged), name: NSWorkspace.didActivateApplicationNotification,
            object: nil)
        panel.onClose = { [weak self] in self?.services.composition.restoreIfDisplaced() }
        let toggle = services.toggleItem.item.button
        toggle?.target = self
        toggle?.action = #selector(toggleClicked(_:))
        toggle?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification,
            object: nil)
    }

    func start() {
        do {
            let start = try services.composition.startupLayout(from: services.store)
            layout = start.layout
            start.notice.map(show(message:))
        } catch {
            show(message: String(describing: error))
        }
        onboarding.update(permissions)
        strip.barDidChange()
    }

    /// Restoring the separator comes first: icons must be visible whatever else fails.
    func stop() {
        services.separator.prepareForTermination()
        services.composition.restoreIfDisplaced()
    }

    /// The user came back to the app, possibly from System Settings.
    func permissionsMayHaveChanged() {
        let now = services.permissions.current()
        guard now != permissions else { return }
        permissions = now
        services.renewEventTapIfNeeded()
        onboarding.update(now)
        strip.barDidChange()
    }

    // MARK: status items

    @objc private func toggleClicked(_ sender: NSStatusBarButton) {
        guard NSApp.currentEvent?.type == .rightMouseUp else {
            services.toggleItem.setSymbol(services.composition.toggleSeparator().toggleSymbolName)
            return
        }
        services.toggleItem.item.menu = makeMenu()
        sender.performClick(nil)
        services.toggleItem.item.menu = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Hidebar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }

    private func groupClicked(_ id: UUID, _ button: NSStatusBarButton) {
        services.composition.restoreIfDisplaced()
        guard let group = layout.groups.first(where: { $0.id == id }) else { return }
        let capabilities = services.permissions.current().capabilities
        Task {
            let items = await services.composition.discoverRevealedInBackground()
            await panel.show(group: group, below: button, items: items, capabilities: capabilities)
        }
    }

    private func iconClicked(_ id: MenuBarItemID) {
        show(services.composition.click(id))
    }

    private func show(_ outcome: ClickOutcome) {
        UserMessages.text(for: outcome).map(show(message:))
    }

    // MARK: windows

    @objc private func openSettings() {
        if let settings {
            settings.show()
            return
        }
        do {
            let start = try services.composition.startupLayout(from: services.store)
            let window = SettingsWindow(
                model: services.makeSettingsModel(layout: start.layout),
                composition: services.composition, notice: start.notice)
            window.onApplied = { [weak self] saved in self?.applied(saved) }
            window.onClose = { [weak self] in self?.settings = nil }
            settings = window
            window.show()
        } catch {
            show(message: String(describing: error))
        }
    }

    private func applied(_ saved: Layout) {
        layout = saved
        services.groupItems.rebuild(saved.groups)
        strip.barDidChange()
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
