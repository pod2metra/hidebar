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
    private let snapshotter = FakeSnapshotter()
    private let full = PermissionsState(accessibility: true, screenRecording: true).capabilities
    private let accessibilityOnly = PermissionsState(accessibility: true, screenRecording: false).capabilities
    private let none = PermissionsState(accessibility: false, screenRecording: false).capabilities
    private let screen = OverflowCalculator(screenWidth: 100, notchRightArea: nil, menusWidth: 20, spacing: 5)

    private func entry(
        _ name: String, x: Double, width: Double, windowID: Int = 1, managed: Bool = true,
        movable: Bool = true
    ) -> DiscoveredItem {
        DiscoveredItem(
            windowID: windowID,
            item: MenuBarItem(
                id: moveID(name), frame: ItemFrame(x: x, y: 0, width: width, height: 20),
                isMovable: movable, isHidable: movable),
            isManaged: managed)
    }

    private var scene: [DiscoveredItem] {
        [
            entry("c", x: 150, width: 30, windowID: 3), entry("a", x: 10, width: 30, windowID: 1),
            entry("d", x: 200, width: 30, windowID: 4), entry("b", x: 60, width: 40, windowID: 2),
        ]
    }

    private var viewModel: OverflowStripViewModel {
        OverflowStripViewModel(snapshotter: snapshotter, click: { [clicks] in clicks.click($0) })
    }

    private func recompute(
        _ model: OverflowStripViewModel, items: [DiscoveredItem]? = nil, viewport: Double = 40,
        screen custom: OverflowCalculator? = nil, capabilities: Capabilities? = nil
    ) async {
        await model.recompute(
            screen: custom ?? screen, viewportWidth: viewport, items: items ?? scene,
            capabilities: capabilities ?? full)
    }

    private func image() -> SnapshotImage { SnapshotImage(payload: FakeImage()) }

    // MARK: partition into rows

    @Test func rowsAreTheItemsThatDoNotFitInBarOrder() async {
        let model = viewModel
        await recompute(model)
        #expect(model.rows.map(\.id) == [moveID("a"), moveID("b")])
        #expect(!model.isHidden)
    }

    @Test func everythingFittingHidesTheStrip() async {
        let model = viewModel
        await recompute(model, items: [scene[0]])
        #expect(model.rows.isEmpty)
        #expect(model.isHidden)
        #expect(model.scrollModel.contentWidth == 0)
        #expect(model.visibleRange == 0..<0)
        #expect(snapshotter.requested.isEmpty)
    }

    @Test func noItemsHidesTheStrip() async {
        let model = viewModel
        await recompute(model, items: [])
        #expect(model.isHidden)
    }

    @Test func spacingAndMenusWidthComeFromTheScreen() async {
        let model = viewModel
        let roomy = OverflowCalculator(screenWidth: 100, notchRightArea: nil, menusWidth: 0, spacing: 0)
        await recompute(model, screen: roomy)
        #expect(model.rows.map(\.id) == [moveID("a")])
        #expect(model.scrollModel.contentWidth == 30)
    }

    @Test func notchPushesTheLeftLimitSoMoreItemsOverflow() async {
        let model = viewModel
        let notched = OverflowCalculator(
            screenWidth: 100, notchRightArea: BarRect(x: 50, y: 0, width: 50, height: 20), menusWidth: 20, spacing: 5)
        await recompute(model, screen: notched)
        #expect(model.rows.map(\.id) == [moveID("a"), moveID("b"), moveID("c")])
    }

    @Test func itemsAtTheSamePositionKeepTheirInputOrderFromTheRight() async {
        let model = viewModel
        let nothingFits = OverflowCalculator(screenWidth: 100, notchRightArea: nil, menusWidth: 100, spacing: 0)
        await recompute(
            model, items: [entry("p", x: 5, width: 10), entry("q", x: 5, width: 10)], screen: nothingFits)
        #expect(model.rows.map(\.id) == [moveID("q"), moveID("p")])
    }

    // MARK: visible section only

    private func own(_ title: String, x: Double, width: Double) -> DiscoveredItem {
        DiscoveredItem(
            windowID: 90,
            item: MenuBarItem(
                id: MenuBarItemID(ownerBundleID: OwnItems.bundleID, title: title),
                frame: ItemFrame(x: x, y: 0, width: width, height: 20), isMovable: true, isHidable: true),
            isManaged: true)
    }

    private var separator: DiscoveredItem { own(OwnItems.separatorTitle, x: 0, width: 10) }

    @Test func iconsLeftOfTheSeparatorAreNeverRows() async {
        let model = viewModel
        await recompute(model, items: scene + [separator, entry("hidden", x: -60, width: 30)])
        #expect(model.rows.map(\.id) == [moveID("a"), moveID("b")])
    }

    @Test func theSeparatorDoesNotBecomeARowEvenWhenItOverflows() async {
        let model = viewModel
        let nothingFits = OverflowCalculator(screenWidth: 100, notchRightArea: nil, menusWidth: 100, spacing: 0)
        await recompute(model, items: scene + [separator], screen: nothingFits)
        #expect(model.rows.map(\.id) == [moveID("a"), moveID("b"), moveID("c"), moveID("d")])
    }

    @Test func ownIconsTakeRoomOnTheBarButAreNotRows() async {
        let model = viewModel
        // d and c fit in 80 points without the group icon; with it (30 wide) c no longer does.
        await recompute(model, items: scene + [separator, own("Hidebar group", x: 240, width: 30)])
        #expect(model.rows.map(\.id) == [moveID("a"), moveID("b"), moveID("c")])
        #expect(model.itemWidths == [30, 40, 30])
        #expect(model.spacing == 5)
    }

    @Test func anIconAtTheSeparatorsPositionIsStillInTheSection() async {
        let model = viewModel
        let nothingFits = OverflowCalculator(screenWidth: 100, notchRightArea: nil, menusWidth: 100, spacing: 0)
        await recompute(
            model, items: [entry("edge", x: 0, width: 10), separator], screen: nothingFits)
        #expect(model.rows.map(\.id) == [moveID("edge")])
    }

    @Test func withoutASeparatorEveryItemIsInTheSection() async {
        let model = viewModel
        await recompute(model, items: scene + [entry("far", x: -500, width: 30)])
        #expect(model.rows.map(\.id) == [moveID("far"), moveID("a"), moveID("b")])
    }

    // MARK: rows

    @Test func rowNameIsTheTitleOrTheBundleIdWhenThereIsNone() async {
        let titled = DiscoveredItem(
            windowID: 1,
            item: MenuBarItem(
                id: MenuBarItemID(ownerBundleID: "com.example.app", title: "Sync"),
                frame: ItemFrame(x: 0, y: 0, width: 90, height: 20), isMovable: true, isHidable: true),
            isManaged: true)
        let model = viewModel
        await recompute(model, items: [titled, entry("u", x: 200, width: 90)], capabilities: none)
        #expect(model.rows.map(\.name) == ["Sync", "test.u"])
    }

    @Test func clickableMeansCanMoveAndManagedAndMovable() async {
        let items = [
            entry("ok", x: 0, width: 90), entry("unmanaged", x: 10, width: 90, managed: false),
            entry("pinned", x: 20, width: 90, movable: false), entry("edge", x: 500, width: 10),
        ]
        let model = viewModel
        await recompute(model, items: items)
        #expect(model.rows.map(\.id.ownerBundleID) == ["test.ok", "test.unmanaged", "test.pinned"])
        #expect(model.rows.map(\.isClickable) == [true, false, false])

        await recompute(model, items: items, capabilities: none)
        #expect(model.rows.map(\.isClickable) == [false, false, false])
    }

    // MARK: scrolling

    @Test func contentWidthAndVisibleRangeShareTheRowWidthsAndSpacing() async {
        let model = viewModel
        await recompute(model, viewport: 40)
        #expect(model.scrollModel.contentWidth == 75)
        #expect(model.scrollModel.viewportWidth == 40)
        #expect(model.scrollModel.maxOffset == 35)
        #expect(model.visibleRange == 0..<2)
    }

    @Test func rowsStartOneWidthAndOneSpacingAfterTheRowBefore() async {
        let model = viewModel
        await recompute(model)
        #expect(model.rowStart(at: 0) == 0)
        #expect(model.rowStart(at: 1) == 35)
        #expect(model.rowStart(at: 2) == 80)
    }

    @Test func scrollingMovesTheOffsetAndTheVisibleRangeAndClampsAtBothEnds() async {
        let model = viewModel
        await recompute(model, viewport: 40)
        model.scroll(ScrollInput(deltaX: -20, deltaY: 0, hasPreciseDeltas: true))
        #expect(model.scrollModel.offset == 20)
        model.scroll(ScrollInput(deltaX: -50, deltaY: 0, hasPreciseDeltas: true))
        #expect(model.scrollModel.offset == 35)
        #expect(model.visibleRange == 1..<2)
        model.scroll(ScrollInput(deltaX: 100, deltaY: 0, hasPreciseDeltas: true))
        #expect(model.scrollModel.offset == 0)
        #expect(model.visibleRange == 0..<2)
    }

    @Test func wheelScrollsByLines() async {
        let model = viewModel
        await recompute(model, viewport: 40)
        model.scroll(ScrollInput(deltaX: 0, deltaY: -1, hasPreciseDeltas: false))
        #expect(model.scrollModel.offset == ScrollInput.pointsPerWheelLine)
    }

    @Test func recomputeKeepsTheOffsetWhileItFitsAndClampsItWhenContentShrinks() async {
        let model = viewModel
        await recompute(model, viewport: 40)
        model.scroll(ScrollInput(deltaX: -30, deltaY: 0, hasPreciseDeltas: true))
        await recompute(model, viewport: 40)
        #expect(model.scrollModel.offset == 30)

        let roomy = OverflowCalculator(screenWidth: 100, notchRightArea: nil, menusWidth: 0, spacing: 0)
        await recompute(model, viewport: 40, screen: roomy)
        #expect(model.scrollModel.contentWidth == 30)
        #expect(model.scrollModel.offset == 0)
    }

    // MARK: click

    @Test func clickingAClickableRowClicksItsIconThroughTheInjectedAction() async {
        let model = viewModel
        await recompute(model)
        #expect(model.click(rowAt: 1) == .clicked)
        #expect(clicks.ids == [moveID("b")])
    }

    @Test func theOutcomeOfTheActionIsPassedOn() async {
        clicks.outcome = .revealFailed
        let model = viewModel
        await recompute(model)
        #expect(model.click(rowAt: 0) == .revealFailed)
    }

    @Test func clickOnAnUnclickableOrMissingRowClicksNothing() async {
        let model = viewModel
        await recompute(model, items: scene + [entry("pinned", x: 20, width: 90, movable: false)])
        let pinned = model.rows.firstIndex { $0.id == moveID("pinned") }
        #expect(pinned != nil)
        #expect(model.click(rowAt: pinned ?? 0) == nil)
        #expect(model.click(rowAt: model.rows.count) == nil)
        #expect(model.click(rowAt: -1) == nil)
        #expect(clicks.ids.isEmpty)
    }

    // MARK: snapshots

    @Test func fullAccessUpgradesRowsToSnapshotsInStripOrder() async {
        let a = image()
        let b = image()
        snapshotter.images = [1: a, 2: b]
        let model = viewModel
        await recompute(model)
        #expect(model.rows.map(\.content) == [.snapshot(a), .snapshot(b)])
        #expect(snapshotter.requested == [1, 2])
    }

    @Test func withoutScreenRecordingRowsStayAppNamesAndNothingIsCaptured() async {
        let model = viewModel
        await recompute(model, capabilities: accessibilityOnly)
        #expect(model.rows.map(\.content) == [.appName, .appName])
        #expect(snapshotter.requested.isEmpty)
    }

    @Test func failedCaptureKeepsTheAppNameAndDoesNotStopTheOthers() async {
        let b = image()
        snapshotter.images = [2: b]
        let model = viewModel
        await recompute(model)
        #expect(model.rows.map(\.content) == [.appName, .snapshot(b)])
        #expect(snapshotter.requested == [1, 2])
    }

    @Test func snapshotArrivingAfterANewerRecomputeIsDropped() async {
        let stale = image()
        let fresh = image()
        snapshotter.images = [1: stale]
        snapshotter.holdWindows = [1]
        let model = viewModel
        let first = Task { await recompute(model) }
        // Bounded: a broken match must fail this test, not hang the whole run.
        for _ in 0..<100 where snapshotter.requested.isEmpty { await Task.yield() }

        snapshotter.holdWindows = []
        snapshotter.images = [1: fresh]
        await recompute(model, items: [entry("a", x: 10, width: 90, windowID: 1)])
        snapshotter.release(1)
        await first.value

        #expect(model.rows.map(\.content) == [.snapshot(fresh)])
        #expect(snapshotter.requested == [1, 1])
    }
}
