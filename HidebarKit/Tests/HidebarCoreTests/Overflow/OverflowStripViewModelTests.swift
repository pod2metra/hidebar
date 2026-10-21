import Testing

@testable import HidebarCore

/// Scene: 100 wide screen, menus up to x 20, spacing 5 → 80 points for icons. Bar order left to
/// right is a (30 wide), b (40), c (30), d (30); from the right d and c fit (65), b does not.
/// The strip holds a, b: content 30 + 5 + 40 = 75.
@MainActor @Suite struct OverflowStripViewModelTests {
    /// Stands in for the action the app passes to click an icon.
    @MainActor private final class ClickLog {
        private(set) var ids: [MenuBarItemID] = []
        var outcome = ClickOutcome.clicked

        func click(_ id: MenuBarItemID) -> ClickOutcome {
            ids.append(id)
            return outcome
        }
    }

    private let clicks = ClickLog()
    private let granted = PermissionsState(accessibility: true).capabilities
    private let none = PermissionsState(accessibility: false).capabilities
    private let screen = OverflowCalculator(screenWidth: 100, notchRightArea: nil, menusWidth: 20, spacing: 5)

    private func entry(
        _ name: String, x: Double, width: Double, windowID: Int = 1, managed: Bool = true,
        movable: Bool = true
    ) -> DiscoveredItem {
        DiscoveredItem(
            windowID: windowID, ownerPID: 688,
            item: MenuBarItem(
                id: moveID(name), frame: ItemFrame(x: x, y: 0, width: width, height: 20),
                isMovable: movable),
            isManaged: managed)
    }

    private var scene: [DiscoveredItem] {
        [
            entry("c", x: 150, width: 30, windowID: 3), entry("a", x: 10, width: 30, windowID: 1),
            entry("d", x: 200, width: 30, windowID: 4), entry("b", x: 60, width: 40, windowID: 2),
        ]
    }

    private var viewModel: OverflowStripViewModel {
        OverflowStripViewModel(
            names: ItemNames(apps: StubAppNames(names: ["com.example.app": "Example"])),
            click: { [clicks] in clicks.click($0) })
    }

    private func recompute(
        _ model: OverflowStripViewModel, items: [DiscoveredItem]? = nil, viewport: Double = 40,
        screen custom: OverflowCalculator? = nil, capabilities: Capabilities? = nil,
        own: OwnBarItems? = nil
    ) {
        model.recompute(
            screen: custom ?? screen, viewportWidth: viewport, items: items ?? scene,
            capabilities: capabilities ?? granted, own: own)
    }

    // MARK: partition into rows

    @Test func rowsAreTheItemsThatDoNotFitInBarOrder() {
        let model = viewModel
        recompute(model)
        #expect(model.rows.map(\.id) == [moveID("a"), moveID("b")])
        #expect(!model.isHidden)
    }

    @Test func everythingFittingHidesTheStrip() {
        let model = viewModel
        recompute(model, items: [scene[0]])
        #expect(model.rows.isEmpty)
        #expect(model.isHidden)
        #expect(model.scrollModel.contentWidth == 0)
        #expect(model.visibleRange == 0..<0)
    }

    @Test func noItemsHidesTheStrip() {
        let model = viewModel
        recompute(model, items: [])
        #expect(model.isHidden)
    }

    @Test func spacingAndMenusWidthComeFromTheScreen() {
        let model = viewModel
        let roomy = OverflowCalculator(screenWidth: 100, notchRightArea: nil, menusWidth: 0, spacing: 0)
        recompute(model, screen: roomy)
        #expect(model.rows.map(\.id) == [moveID("a")])
        #expect(model.scrollModel.contentWidth == 30)
    }

    @Test func notchPushesTheLeftLimitSoMoreItemsOverflow() {
        let model = viewModel
        let notched = OverflowCalculator(
            screenWidth: 100, notchRightArea: BarRect(x: 50, y: 0, width: 50, height: 20), menusWidth: 20, spacing: 5)
        recompute(model, screen: notched)
        #expect(model.rows.map(\.id) == [moveID("a"), moveID("b"), moveID("c")])
    }

    @Test func itemsAtTheSamePositionKeepTheirInputOrderFromTheRight() {
        let model = viewModel
        let nothingFits = OverflowCalculator(screenWidth: 100, notchRightArea: nil, menusWidth: 100, spacing: 0)
        recompute(
            model, items: [entry("p", x: 5, width: 10), entry("q", x: 5, width: 10)], screen: nothingFits)
        #expect(model.rows.map(\.id) == [moveID("q"), moveID("p")])
    }

    // MARK: visible section only

    private func own(_ title: String, x: Double, width: Double) -> DiscoveredItem {
        DiscoveredItem(
            windowID: 90, ownerPID: 688,
            item: MenuBarItem(
                id: MenuBarItemID(ownerBundleID: OwnItems.bundleID, title: title),
                frame: ItemFrame(x: x, y: 0, width: width, height: 20), isMovable: true),
            isManaged: true)
    }

    private var separator: DiscoveredItem { own(OwnItems.separatorTitle, x: 0, width: 10) }

    @Test func iconsLeftOfTheSeparatorAreNeverRows() {
        let model = viewModel
        recompute(model, items: scene + [separator, entry("hidden", x: -60, width: 30)])
        #expect(model.rows.map(\.id) == [moveID("a"), moveID("b")])
    }

    @Test func theSeparatorDoesNotBecomeARowEvenWhenItOverflows() {
        let model = viewModel
        let nothingFits = OverflowCalculator(screenWidth: 100, notchRightArea: nil, menusWidth: 100, spacing: 0)
        recompute(model, items: scene + [separator], screen: nothingFits)
        #expect(model.rows.map(\.id) == [moveID("a"), moveID("b"), moveID("c"), moveID("d")])
    }

    @Test func ownIconsTakeRoomOnTheBarButAreNotRows() {
        let model = viewModel
        // d and c fit in 80 points without the arrow; with it (30 wide) c no longer does.
        recompute(model, items: scene + [separator, own("Hidebar arrow", x: 240, width: 30)])
        #expect(model.rows.map(\.id) == [moveID("a"), moveID("b"), moveID("c")])
        #expect(model.itemWidths == [30, 40, 30])
        #expect(model.spacing == 5)
    }

    @Test func anIconAtTheSeparatorsPositionIsStillInTheSection() {
        let model = viewModel
        let nothingFits = OverflowCalculator(screenWidth: 100, notchRightArea: nil, menusWidth: 100, spacing: 0)
        recompute(
            model, items: [entry("edge", x: 0, width: 10), separator], screen: nothingFits)
        #expect(model.rows.map(\.id) == [moveID("edge")])
    }

    @Test func withoutASeparatorEveryItemIsInTheSection() {
        let model = viewModel
        recompute(model, items: scene + [entry("far", x: -500, width: 30)])
        #expect(model.rows.map(\.id) == [moveID("far"), moveID("a"), moveID("b")])
    }

    // MARK: rows

    @Test func rowNameIsTheAppNameWithTheTitleOrTheBundleIdOfAnUnknownApp() {
        let titled = DiscoveredItem(
            windowID: 1, ownerPID: 688,
            item: MenuBarItem(
                id: MenuBarItemID(ownerBundleID: "com.example.app", title: "Sync"),
                frame: ItemFrame(x: 0, y: 0, width: 90, height: 20), isMovable: true),
            isManaged: true)
        let model = viewModel
        recompute(model, items: [titled, entry("u", x: 200, width: 90)], capabilities: none)
        #expect(model.rows.map(\.name) == ["Example — Sync", "test.u"])
    }

    @Test func clickableMeansCanMoveAndManagedAndMovable() {
        let items = [
            entry("ok", x: 0, width: 90), entry("unmanaged", x: 10, width: 90, managed: false),
            entry("pinned", x: 20, width: 90, movable: false), entry("edge", x: 500, width: 10),
        ]
        let model = viewModel
        recompute(model, items: items)
        #expect(model.rows.map(\.id.ownerBundleID) == ["test.ok", "test.unmanaged", "test.pinned"])
        #expect(model.rows.map(\.isClickable) == [true, false, false])

        recompute(model, items: items, capabilities: none)
        #expect(model.rows.map(\.isClickable) == [false, false, false])
    }

    // MARK: scrolling

    @Test func contentWidthAndVisibleRangeShareTheRowWidthsAndSpacing() {
        let model = viewModel
        recompute(model, viewport: 40)
        #expect(model.scrollModel.contentWidth == 75)
        #expect(model.scrollModel.viewportWidth == 40)
        #expect(model.scrollModel.maxOffset == 35)
        #expect(model.visibleRange == 0..<2)
    }

    @Test func rowsStartOneWidthAndOneSpacingAfterTheRowBefore() {
        let model = viewModel
        recompute(model)
        #expect(model.rowStart(at: 0) == 0)
        #expect(model.rowStart(at: 1) == 35)
        #expect(model.rowStart(at: 2) == 80)
    }

    @Test func scrollingMovesTheOffsetAndTheVisibleRangeAndClampsAtBothEnds() {
        let model = viewModel
        recompute(model, viewport: 40)
        model.scroll(ScrollInput(deltaX: -20, deltaY: 0, hasPreciseDeltas: true))
        #expect(model.scrollModel.offset == 20)
        model.scroll(ScrollInput(deltaX: -50, deltaY: 0, hasPreciseDeltas: true))
        #expect(model.scrollModel.offset == 35)
        #expect(model.visibleRange == 1..<2)
        model.scroll(ScrollInput(deltaX: 100, deltaY: 0, hasPreciseDeltas: true))
        #expect(model.scrollModel.offset == 0)
        #expect(model.visibleRange == 0..<2)
    }

    @Test func wheelScrollsByLines() {
        let model = viewModel
        recompute(model, viewport: 40)
        model.scroll(ScrollInput(deltaX: 0, deltaY: -1, hasPreciseDeltas: false))
        #expect(model.scrollModel.offset == ScrollInput.pointsPerWheelLine)
    }

    @Test func recomputeKeepsTheOffsetWhileItFitsAndClampsItWhenContentShrinks() {
        let model = viewModel
        recompute(model, viewport: 40)
        model.scroll(ScrollInput(deltaX: -30, deltaY: 0, hasPreciseDeltas: true))
        recompute(model, viewport: 40)
        #expect(model.scrollModel.offset == 30)

        let roomy = OverflowCalculator(screenWidth: 100, notchRightArea: nil, menusWidth: 0, spacing: 0)
        recompute(model, viewport: 40, screen: roomy)
        #expect(model.scrollModel.contentWidth == 30)
        #expect(model.scrollModel.offset == 0)
    }

    // MARK: click

    @Test func clickingAClickableRowClicksItsIconThroughTheInjectedAction() {
        let model = viewModel
        recompute(model)
        #expect(model.click(rowAt: 1) == .outcome(.clicked))
        #expect(clicks.ids == [moveID("b")])
    }

    @Test func theOutcomeOfTheActionIsPassedOn() {
        clicks.outcome = .revealFailed
        let model = viewModel
        recompute(model)
        #expect(model.click(rowAt: 0) == .outcome(.revealFailed))
    }

    // MARK: Accessibility asked for on demand

    @Test func withoutAccessibilityEveryRowAsksForIt() {
        let model = viewModel
        recompute(model, capabilities: none)
        #expect(model.rows.map(\.needsAccessibility) == [true, true])
        recompute(model)
        #expect(model.rows.map(\.needsAccessibility) == [false, false])
    }

    @Test func clickingARowWithoutAccessibilityAsksForItAndClicksNothing() {
        let model = viewModel
        recompute(model, capabilities: none)
        #expect(model.click(rowAt: 0) == .accessibilityNeeded)
        #expect(model.click(rowAt: 1) == .accessibilityNeeded)
        #expect(clicks.ids.isEmpty)
    }

    @Test func clickingAMissingRowWithoutAccessibilityDoesNothing() {
        let model = viewModel
        recompute(model, capabilities: none)
        #expect(model.click(rowAt: model.rows.count) == nil)
        #expect(model.click(rowAt: -1) == nil)
    }

    @Test func aRowIsEnabledWhenItClicksOrAsksForAccessibility() {
        let items = scene + [entry("pinned", x: 20, width: 90, movable: false)]
        let model = viewModel
        recompute(model, items: items)
        #expect(model.rows.map(\.id) == [moveID("a"), moveID("pinned"), moveID("b")])
        #expect(model.rows.map(\.isEnabled) == [true, false, true])
        recompute(model, items: items, capabilities: none)
        #expect(model.rows.map(\.isEnabled) == [true, true, true])
    }

    @Test func clickOnAnUnclickableOrMissingRowClicksNothing() {
        let model = viewModel
        recompute(model, items: scene + [entry("pinned", x: 20, width: 90, movable: false)])
        let pinned = model.rows.firstIndex { $0.id == moveID("pinned") }
        #expect(pinned != nil)
        #expect(model.click(rowAt: pinned ?? 0) == nil)
        #expect(model.click(rowAt: model.rows.count) == nil)
        #expect(model.click(rowAt: -1) == nil)
        #expect(clicks.ids.isEmpty)
    }
}
