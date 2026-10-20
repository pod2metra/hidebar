import AppKit
import HidebarCore
import HidebarSystem

/// Every adapter and core object of the app, wired once. Holds no behaviour of its own.
@MainActor
final class AppServices {
    let permissions = TCCPermissionChecker()
    let snapshotter = SCKSnapshotter()
    /// App names for everything the user reads; identities stay bundle ids.
    let names = ItemNames(apps: WorkspaceAppNames())
    let separatorItems = SeparatorItems(clock: DispatchSchedulingClock())
    let composition: AppComposition
    /// Items on the bar as they are now, with no reveal; the overflow strip reads the visible side.
    let discovery: ItemDiscovery
    /// Where `discovery` runs when the main thread must stay free.
    let background = BackgroundQueue()
    let menus = MenusExtent()

    init() {
        let windows = CGWindowListSource()
        let reader = AXMenuBarReader(tree: AXTreeReader(), bundleIDOfPID: RunningApps.bundleID)
        let discovery = ItemDiscovery(
            windowList: windows, ownerResolver: AXOwnerResolver(windowList: windows, reader: reader),
            mainDisplay: MainDisplay.bounds)
        let poster = LoggingPoster(base: CGEventPoster())
        let locator = LoggingLocator(base: AXFrameLocator(reader: reader))
        let moveClock = ThreadMoveClock()
        let windowLocator = LoggingWindows(
            base: DiscoveryWindowLocator(
                discover: { discovery.discoverAll() }, windowList: windows))
        let deadline = MoveDeadline()
        let executor = MoveExecutor(
            poster: poster, locator: locator, windows: windowLocator, clock: moveClock,
            deadline: deadline)
        let menuProbe = OpenMenuProbe(windowList: windows)
        let proxy = ClickProxy(
            executor: executor, poster: poster, locator: locator, separator: OwnItems.separatorID,
            revealSide: .rightOf, clock: DispatchSchedulingClock(), deadline: deadline,
            isMenuOpen: { menuProbe.isMenuOpen() })
        composition = AppComposition(
            separator: separatorItems.controller, clickProxy: proxy, clock: moveClock, locator: locator,
            discover: { discovery.discover() })
        self.discovery = discovery
    }
}
