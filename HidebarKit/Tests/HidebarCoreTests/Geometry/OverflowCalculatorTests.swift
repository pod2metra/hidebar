import Testing

@testable import HidebarCore

@Suite struct OverflowCalculatorTests {
    private func plain(menus: Double = 0, spacing: Double = 0) -> OverflowCalculator {
        OverflowCalculator(screenWidth: 100, notchRightArea: nil, menusWidth: menus, spacing: spacing)
    }

    private func notched(rightFrom: Double, menus: Double = 0, spacing: Double = 0) -> OverflowCalculator {
        OverflowCalculator(
            screenWidth: 100,
            notchRightArea: BarRect(x: rightFrom, y: 0, width: 100 - rightFrom, height: 24),
            menusWidth: menus,
            spacing: spacing
        )
    }

    @Test func barRectEdges() {
        let rect = BarRect(x: 10, y: 2, width: 30, height: 24)
        #expect(rect.minX == 10)
        #expect(rect.maxX == 40)
        #expect(rect.y == 2)
        #expect(rect.height == 24)
    }

    @Test func zeroItemsPartitionIsEmpty() {
        let result = plain().partition(itemWidths: [])
        #expect(result.visible == 0..<0)
        #expect(result.overflow == 0..<0)
    }

    @Test func allItemsFitWithoutNotch() {
        let result = plain().partition(itemWidths: [20, 30, 40])
        #expect(result.visible == 0..<3)
        #expect(result.overflow == 3..<3)
    }

    @Test func exactFitIsVisible() {
        let result = plain().partition(itemWidths: [50, 50])
        #expect(result.visible == 0..<2)
        #expect(result.overflow == 2..<2)
    }

    @Test func oneUnitTooWideOverflows() {
        let result = plain().partition(itemWidths: [50, 51])
        #expect(result.visible == 0..<1)
        #expect(result.overflow == 1..<2)
    }

    @Test func noItemFitsWhenFirstIsTooWide() {
        let result = plain().partition(itemWidths: [101, 5])
        #expect(result.visible == 0..<0)
        #expect(result.overflow == 0..<2)
    }

    @Test func overflowIsAPrefixCutEvenIfLaterItemIsNarrow() {
        let result = plain().partition(itemWidths: [60, 50, 5])
        #expect(result.visible == 0..<1)
        #expect(result.overflow == 1..<3)
    }

    @Test func menusWidthShrinksVisibleArea() {
        let result = plain(menus: 40).partition(itemWidths: [30, 30, 30])
        #expect(result.visible == 0..<2)
        #expect(result.overflow == 2..<3)
    }

    @Test func spacingCountsBetweenItemsOnly() {
        let result = plain(spacing: 10).partition(itemWidths: [45, 45])
        #expect(result.visible == 0..<2)
        #expect(result.overflow == 2..<2)
    }

    @Test func spacingPushesLastItemOut() {
        let result = plain(spacing: 10).partition(itemWidths: [45, 46])
        #expect(result.visible == 0..<1)
        #expect(result.overflow == 1..<2)
    }

    @Test func spacingDoesNotApplyBeforeFirstItem() {
        let result = plain(spacing: 10).partition(itemWidths: [100])
        #expect(result.visible == 0..<1)
    }

    @Test func notchLimitsVisibleAreaToRightSafeArea() {
        let result = notched(rightFrom: 60).partition(itemWidths: [20, 20, 20])
        #expect(result.visible == 0..<2)
        #expect(result.overflow == 2..<3)
    }

    @Test func itemNeverStraddlesNotch() {
        let result = notched(rightFrom: 60).partition(itemWidths: [30, 11])
        #expect(result.visible == 0..<1)
        #expect(result.overflow == 1..<2)
    }

    @Test func menusLeftOfNotchDoNotShrinkVisibleArea() {
        let result = notched(rightFrom: 60, menus: 50).partition(itemWidths: [20, 20])
        #expect(result.visible == 0..<2)
    }

    @Test func menusReachingPastNotchShrinkVisibleArea() {
        let result = notched(rightFrom: 60, menus: 80).partition(itemWidths: [10, 10, 10])
        #expect(result.visible == 0..<2)
        #expect(result.overflow == 2..<3)
    }

    @Test func menusWiderThanScreenLeaveNoRoom() {
        let result = plain(menus: 150).partition(itemWidths: [1])
        #expect(result.visible == 0..<0)
        #expect(result.overflow == 0..<1)
    }

    @Test func zeroWidthItemFitsWithNoRoom() {
        let result = plain(menus: 100).partition(itemWidths: [0])
        #expect(result.visible == 0..<1)
    }

    @Test func zeroWidthItemFitsWhenMenusWiderThanScreen() {
        let result = plain(menus: 150).partition(itemWidths: [0, 1])
        #expect(result.visible == 0..<1)
        #expect(result.overflow == 1..<2)
    }
}
