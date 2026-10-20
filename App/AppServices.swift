import AppKit
import HidebarCore
import HidebarSystem

/// Every adapter and core object of the app, wired once. Holds no behaviour of its own.
@MainActor
final class AppServices {
    let permissions = TCCPermissionChecker()
    let store = LayoutStore(store: UserDefaultsStore())
    let snapshotter = SCKSnapshotter()
    let toggleItem: NSStatusItemAdapter
    let groupItems = GroupStatusItems()
    let separatorItem: NSStatusItemAdapter
    let separator: SeparatorController
    let composition: AppComposition
    /// The one settings drags with; it shares the input gate with the click proxy.
    let executor: MoveExecutor
    let clickProxy: ClickProxy
    /// Items on the bar as they are now, with no reveal; the overflow strip reads the visible side.
    let discovery: ItemDiscovery
    let menus = MenusExtent()

    private let inputGate = InputGate()
    private var eventTap: EventTapInputGate

    init() {
        // Everything left of the separator is hidden, so the toggle and the group icons must be
        // right of it: their positions are written before the items are created.
        StatusItemSeeding().seedFixedItems()
        toggleItem = NSStatusItemAdapter(
            autosaveName: AutosaveNames.toggle, symbolName: SeparatorState.shown.toggleSymbolName)
        groupItems.rebuild((try? store.load())?.layout.groups ?? [])
        separatorItem = NSStatusItemAdapter(autosaveName: AutosaveNames.separator)
        separator = SeparatorController(item: separatorItem, clock: DispatchSchedulingClock())
        separator.prepareForLaunch()
        SeparatorMark.apply(to: separatorItem.item)

        eventTap = EventTapInputGate(gate: inputGate)
        let windows = CGWindowListSource()
        let reader = AXMenuBarReader(tree: AXTreeReader(), bundleIDOfPID: RunningApps.bundleID)
        let discovery = ItemDiscovery(
            windowList: windows, ownerResolver: AXOwnerResolver(windowList: windows, reader: reader))
        let poster = CGEventPoster()
        let locator = AXFrameLocator(reader: reader)
        let moveClock = ThreadMoveClock()
        let executor = MoveExecutor(
            poster: poster, locator: locator, clock: moveClock, inputGate: inputGate)
        let menuProbe = OpenMenuProbe(windowList: windows)
        let proxy = ClickProxy(
            executor: executor, poster: poster, locator: locator, separator: OwnItems.separatorID,
            revealSide: .rightOf, clock: DispatchSchedulingClock(), inputGate: inputGate,
            isMenuOpen: { menuProbe.isMenuOpen() })
        composition = AppComposition(
            separator: separator, clickProxy: proxy, clock: moveClock, locator: locator,
            discover: { discovery.discover() })
        self.executor = executor
        self.clickProxy = proxy
        self.discovery = discovery
    }

    func makeSettingsModel(layout: Layout) -> SettingsViewModel {
        SettingsViewModel(
            layout: layout, store: store, executor: executor, separator: OwnItems.separatorID,
            barItems: { [composition] in composition.barItems() })
    }

    /// The event tap can only be created with Accessibility granted, so one made before the
    /// grant is replaced once the permission is there.
    func renewEventTapIfNeeded() {
        eventTap = eventTap.isActive ? eventTap : EventTapInputGate(gate: inputGate)
    }
}
