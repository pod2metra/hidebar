import Foundation
import Testing

@testable import HidebarCore

/// A bar that really reorders: items sit 20 points apart, 10 wide, in `order`. A drag picks the
/// item whose window it names and drops it beside the item whose window the release names (left
/// edge: before it, right edge: after it). Window numbers follow the order the bar started in.
@MainActor
private final class OrderingBar: EventPosting, ItemLocating, WindowLocating, MoveClock {
    var order: [MenuBarItemID]
    private let windowIDs: [MenuBarItemID]

    init(order: [MenuBarItemID]) {
        self.order = order
        windowIDs = order
    }

    func frame(of id: MenuBarItemID) -> ItemFrame? {
        order.firstIndex(of: id).map { ItemFrame(x: Double($0) * 20, y: 0, width: 10, height: 20) }
    }

    func window(of id: MenuBarItemID) -> WindowTarget? {
        guard let frame = frame(of: id), let number = windowIDs.firstIndex(of: id) else { return nil }
        return WindowTarget(windowID: number, ownerPID: 688, frame: frame)
    }

    func cursorPosition() -> CursorPoint { CursorPoint(x: 0, y: 0) }
    func setCursorPosition(_ point: CursorPoint) {}
    func postClick(at point: CursorPoint) -> Bool { true }
    func wait(milliseconds: Int) {}

    func postCommandDrag(_ drag: CommandDrag) -> Bool {
        let moved = windowIDs[drag.item.windowID]
        let anchor = windowIDs[drag.anchor.windowID]
        order.removeAll { $0 == moved }
        let at = order.firstIndex(of: anchor) ?? 0
        order.insert(moved, at: drag.release.x == drag.anchor.frame.x ? at : at + 1)
        return true
    }
}

@MainActor @Suite struct AppCompositionApplyTests {
    // MARK: a displaced icon goes home before the plan

    private let scene = CompositionScene()

    private func settings(layout: Layout) -> SettingsViewModel {
        scene.bar.frames[OwnItems.separatorID] = ItemFrame(x: 60, y: 0, width: 10, height: 20)
        scene.found = [discovered("a"), ownDiscovered(OwnItems.separatorTitle), discovered("b")]
        return SettingsViewModel(
            layout: layout, store: LayoutStore(store: scene.backing),
            executor: MoveExecutor(
                poster: scene.bar, locator: scene.bar, windows: scene.bar, clock: scene.bar,
                inputGate: scene.gate),
            separator: OwnItems.separatorID,
            barItems: { [composition = scene.composition] in composition.barItems() })
    }

    /// Click on `a` while the separator hides: settle is wait 1, the reveal polls at wait 2.
    private func clickA() {
        scene.separator.hide()
        scene.script(wait: 2, moves: "a", to: 22)
        #expect(scene.composition.click(moveID("a")) == .clicked)
        #expect(scene.proxy.hasDisplacedItem)
    }

    @Test func applyBringsAnIconAwayFromAClickHomeBeforeThePlanRuns() throws {
        clickA()
        let model = settings(
            layout: try Layout(visible: [moveID("a")], hidden: [moveID("b")], groups: []))
        // Apply: settle is wait 3, the return of `a` polls at wait 4.
        scene.script(wait: 4, moves: "a", to: 110)
        // The plan drops `b` left of `a` (wait 5), then `a` right of the separator at 60 (wait 6).
        scene.script(wait: 5, moves: "b", to: 40)
        scene.script(wait: 6, moves: "a", to: 65)

        #expect(scene.composition.apply(model) == nil)

        #expect(!scene.proxy.hasDisplacedItem)
        #expect(model.failure == nil)
        #expect(model.saved == model.draft)
        // The click's reveal, the return, then the two drags of the plan.
        #expect(scene.bar.downs.count == 4)
    }

    @Test func applyIsRefusedWhenTheAwayIconCannotComeHomeAndNothingMovesOrIsSaved() throws {
        clickA()
        let model = settings(
            layout: try Layout(visible: [moveID("a")], hidden: [moveID("b")], groups: []))
        let drags = scene.bar.downs.count

        #expect(scene.composition.apply(model) == .displacedIconPending)

        // Only the three attempts to bring the icon home were made.
        #expect(scene.bar.downs.count == drags + MoveExecutor.maxRetries + 1)
        #expect(scene.proxy.hasDisplacedItem)
        #expect(model.failure == nil)
        #expect(try LayoutStore(store: scene.backing).load().status == .missing)
        #expect(scene.separator.state == .hiding)
    }

    // MARK: our own icons stay right of the separator

    @Test func applyThatHidesIconsKeepsTheSeparatorAndOurIconsInPlaceSoTheyStayOnTheBar() throws {
        let separatorID = OwnItems.separatorID
        let group = MenuBarItemID(ownerBundleID: OwnItems.bundleID, title: "Hidebar group")
        let toggle = MenuBarItemID(ownerBundleID: OwnItems.bundleID, title: "Hidebar toggle")
        let bar = OrderingBar(order: [moveID("x"), separatorID, moveID("a"), moveID("b"), group, toggle])
        let item = FakeStatusItem()
        let separator = SeparatorController(item: item, clock: ManualClock())
        let gate = InputGate()
        let executor = MoveExecutor(
            poster: bar, locator: bar, windows: bar, clock: bar, inputGate: gate)
        let proxy = ClickProxy(
            executor: executor, poster: bar, locator: bar, separator: separatorID, revealSide: .rightOf,
            clock: ManualClock(), inputGate: gate, isMenuOpen: { false })
        let composition = AppComposition(
            separator: separator, clickProxy: proxy, clock: bar, locator: bar,
            discover: { [bar] in
                bar.order.map { id in
                    DiscoveredItem(
                        windowID: 1, ownerPID: 688,
                        item: MenuBarItem(
                            id: id, frame: bar.frame(of: id) ?? ItemFrame(x: 0, y: 0, width: 0, height: 0),
                            isMovable: true, isHidable: true),
                        isManaged: true)
                }
            },
            discoverInBackground: { [DiscoveredItem]() })
        let model = SettingsViewModel(
            layout: try Layout(
                visible: [moveID("x")], hidden: [moveID("a"), moveID("b")], groups: []),
            store: LayoutStore(store: InMemoryStore()), executor: executor, separator: separatorID,
            barItems: { composition.barItems() })
        separator.hide()

        #expect(composition.apply(model) == nil)

        #expect(model.failure == nil)
        #expect(
            bar.order == [moveID("a"), moveID("b"), separatorID, moveID("x"), group, toggle])
        #expect(separator.state == .hiding)
    }
}
