import Testing

@testable import HidebarCore

/// Without Accessibility on macOS 26 every status window is owned by Control Center and has an
/// empty title, so every item has the same fallback id and the app's own pipe cannot be told by id.
/// The app's own items are known by their windows' frames instead (`OwnBarItems`).
///
/// Scene: 100 wide screen, no menus. Collapsed, the pipe is 10000 wide with the arrow right of it
/// and the hidden icons left of it. Expanded with a notch (the right safe area starts at 50), the
/// pipe is 4 wide at x 40 and the arrow sits at x 90.
@MainActor @Suite struct OverflowStripOwnItemsTests {
    private let plain = OverflowCalculator(screenWidth: 100, notchRightArea: nil, menusWidth: 0, spacing: 0)
    private let notched = OverflowCalculator(
        screenWidth: 100, notchRightArea: BarRect(x: 50, y: 0, width: 50, height: 20), menusWidth: 0, spacing: 0)
    private let nothingFits = OverflowCalculator(
        screenWidth: 100, notchRightArea: nil, menusWidth: 100, spacing: 0)
    private let withoutAccessibility = PermissionsState(accessibility: false).capabilities
    private let withAccessibility = PermissionsState(accessibility: true).capabilities

    private func window(_ windowID: Int, x: Double, width: Double) -> DiscoveredItem {
        DiscoveredItem(
            windowID: windowID, ownerPID: 688,
            item: MenuBarItem(
                id: itemID("com.apple.controlcenter"),
                frame: ItemFrame(x: x, y: 0, width: width, height: 24), isMovable: false),
            isManaged: false)
    }

    private var model: OverflowStripViewModel {
        OverflowStripViewModel(names: unknownApps, click: { _ in .clicked })
    }

    private func recompute(
        _ model: OverflowStripViewModel, _ items: [DiscoveredItem], screen: OverflowCalculator,
        capabilities: Capabilities? = nil, own: OwnBarItems?
    ) {
        model.recompute(
            screen: screen, viewportWidth: 50, items: items, capabilities: capabilities ?? withoutAccessibility,
            own: own)
    }

    // MARK: collapsed

    private var collapsedOwn: OwnBarItems? {
        OwnBarItems(separator: BarSpan(x: -9910, width: 10000), arrow: BarSpan(x: 90, width: 10))
    }

    private var collapsed: [DiscoveredItem] {
        [
            window(1, x: -9970, width: 30), window(2, x: -9940, width: 30),
            window(3, x: -9910, width: 10000), window(4, x: 60, width: 30), window(5, x: 90, width: 10),
        ]
    }

    @Test func collapsedWithoutAccessibilityTheIconsHiddenOnPurposeAreNotCounted() {
        let model = model
        recompute(model, collapsed, screen: plain, own: collapsedOwn)
        #expect(model.rows.isEmpty)
        #expect(model.indicator == NotchIndicator(hiddenCount: 0, canReach: false))
    }

    @Test func collapsedCountsNothingEvenWhenThePipeWindowIsNotListed() {
        let model = model
        recompute(model, collapsed.filter { $0.windowID != 3 }, screen: plain, own: collapsedOwn)
        #expect(model.rows.isEmpty)
        #expect(model.indicator.hiddenCount == 0)
    }

    // MARK: expanded, behind the notch

    private var expandedOwn: OwnBarItems? {
        OwnBarItems(separator: BarSpan(x: 40, width: 4), arrow: BarSpan(x: 90, width: 10))
    }

    private var expanded: [DiscoveredItem] {
        [
            window(1, x: 0, width: 40), window(2, x: 40, width: 4), window(3, x: 44, width: 20),
            window(4, x: 64, width: 26), window(5, x: 90, width: 10),
        ]
    }

    @Test func expandedWithoutAccessibilityTheIconsPastTheNotchAreCounted() {
        let model = model
        recompute(model, expanded, screen: notched, own: expandedOwn)
        #expect(model.itemWidths == [20])
        #expect(model.indicator == NotchIndicator(hiddenCount: 1, canReach: false))
    }

    @Test func theIndicatorKnowsWhetherAccessibilityLetsTheUserReachTheIcons() {
        let model = model
        recompute(model, expanded, screen: notched, capabilities: withAccessibility, own: expandedOwn)
        #expect(model.indicator == NotchIndicator(hiddenCount: 1, canReach: true))
    }

    @Test func theIndicatorGoesOutWhenEverythingFits() {
        let model = model
        #expect(model.indicator == NotchIndicator(hiddenCount: 0, canReach: true))
        recompute(model, expanded, screen: notched, own: expandedOwn)
        recompute(model, expanded, screen: plain, own: expandedOwn)
        #expect(model.indicator == NotchIndicator(hiddenCount: 0, canReach: false))
    }

    // MARK: own items are told by frame

    @Test func ownItemsNeverBecomeRowsEvenWhenTheirIdIsAnyonesId() {
        let model = model
        recompute(model, expanded, screen: nothingFits, own: expandedOwn)
        #expect(model.itemWidths == [20, 26])
        #expect(model.indicator.hiddenCount == 2)
    }

    @Test func aFrameOffByRoundingStillCountsAsOwn() {
        let model = model
        let rounded = [window(2, x: 40.4, width: 4.4), window(3, x: 44, width: 20), window(5, x: 90.4, width: 9.6)]
        recompute(model, rounded, screen: nothingFits, own: expandedOwn)
        #expect(model.itemWidths == [20])
    }

    // MARK: own windows unknown

    @Test func withoutTheOwnFramesThereIsNoIndicatorWhateverTheRows() {
        let model = model
        recompute(model, collapsed, screen: plain, own: nil)
        #expect(model.rows.count == 3)
        #expect(model.indicator == NotchIndicator(hiddenCount: 0, canReach: false))
    }

    @Test func withoutTheOwnFramesThePipeIsStillFoundByIdForTheRows() {
        let pipe = DiscoveredItem(
            windowID: 9, ownerPID: 1,
            item: MenuBarItem(
                id: OwnItems.separatorID, frame: ItemFrame(x: 0, y: 0, width: 10, height: 24), isMovable: true),
            isManaged: true)
        let model = model
        let items = [pipe, window(1, x: 20, width: 60), window(2, x: 80, width: 60)]
        recompute(model, items, screen: plain, capabilities: withAccessibility, own: nil)
        #expect(model.itemWidths == [60])
        #expect(model.indicator.hiddenCount == 0)
    }
}
