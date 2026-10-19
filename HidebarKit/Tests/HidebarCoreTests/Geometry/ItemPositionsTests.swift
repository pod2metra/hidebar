import Testing

@testable import HidebarCore

@Suite struct ItemPositionsTests {
    private func calculator(
        notchFrom: Double? = nil, menus: Double = 0, spacing: Double = 0
    ) -> OverflowCalculator {
        OverflowCalculator(
            screenWidth: 100,
            notchRightArea: notchFrom.map { BarRect(x: $0, y: 0, width: 100 - $0, height: 24) },
            menusWidth: menus,
            spacing: spacing
        )
    }

    @Test func noItemsHaveNoPositions() {
        #expect(calculator().itemMinXs(itemWidths: []) == [])
    }

    @Test func firstItemEndsAtTheRightScreenEdge() {
        #expect(calculator().itemMinXs(itemWidths: [30]) == [70])
    }

    @Test func itemsAreLaidOutRightToLeftWithSpacing() {
        let positions = calculator(spacing: 4).itemMinXs(itemWidths: [30, 20, 10])
        #expect(positions == [70, 46, 32])
    }

    @Test func overflowingItemsGoNegative() {
        let positions = calculator(spacing: 2).itemMinXs(itemWidths: [60, 60])
        #expect(positions == [40, -22])
    }

    @Test func leftLimitWithoutNotchIsMenusWidth() {
        #expect(calculator(menus: 35).leftLimit == 35)
    }

    @Test func leftLimitIsNotchEdgeWhenMenusAreShorter() {
        #expect(calculator(notchFrom: 60, menus: 35).leftLimit == 60)
    }

    @Test func leftLimitIsMenusWidthWhenMenusReachPastTheNotch() {
        #expect(calculator(notchFrom: 60, menus: 80).leftLimit == 80)
    }
}
