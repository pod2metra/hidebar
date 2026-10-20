import Testing

@testable import HidebarCore

/// Scene: 100 wide screen, menus up to x 20, spacing 5 → 80 points for icons. Bar order left to
/// right is a (30 wide), b (40), c (30), d (30); from the right d and c fit (65), b does not.
/// The strip holds a, b: content 30 + 5 + 40 = 75.
@MainActor @Suite struct OverflowStripViewModelTests {
    private let bar = MoveFakeBar()
    private let snapshotter = FakeSnapshotter()
    private let timer = ManualClock()
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
        let executor = MoveExecutor(poster: bar, locator: bar, clock: bar, inputGate: InputGate())
        let proxy = ClickProxy(
            executor: executor, poster: bar, locator: bar, separator: moveID("sep"), revealSide: .rightOf,
            clock: timer)
        return OverflowStripViewModel(snapshotter: snapshotter, clickProxy: proxy)
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

    private func arrangeBar() {
        bar.frames[moveID("sep")] = ItemFrame(x: 0, y: 0, width: 20, height: 20)
        for found in scene { bar.frames[found.item.id] = found.item.frame }
        bar.onWait = { [bar] count in
            if count == 1 { bar.frames[moveID("a")] = ItemFrame(x: 22, y: 0, width: 30, height: 20) }
        }
    }

    @Test func clickingAClickableRowGoesThroughTheProxyAtTheRevealedIcon() async {
        arrangeBar()
        let model = viewModel
        await recompute(model)
        #expect(model.click(rowAt: 0) == .clicked)
        #expect(bar.clicks == [CursorPoint(x: 37, y: 10)])
    }

    @Test func clickOnAnUnclickableOrMissingRowPostsNothing() async {
        arrangeBar()
        let model = viewModel
        await recompute(model, items: scene + [entry("pinned", x: 20, width: 90, movable: false)])
        let pinned = model.rows.firstIndex { $0.id == moveID("pinned") }
        #expect(pinned != nil)
        #expect(model.click(rowAt: pinned ?? 0) == nil)
        #expect(model.click(rowAt: model.rows.count) == nil)
        #expect(model.click(rowAt: -1) == nil)
        #expect(bar.log.isEmpty)
    }

    @Test func clickUsesTheItemsOfTheLatestRecompute() async {
        arrangeBar()
        let model = viewModel
        await recompute(model, items: [])
        await recompute(model)
        #expect(model.click(rowAt: 0) == .clicked)
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
