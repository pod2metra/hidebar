import Testing

@testable import HidebarCore

@Suite struct SeparatorStateTests {
    @Test func theArrowPointsLeftWhileTheIconsAreHiddenAndRightWhileShown() {
        #expect(SeparatorState.hiding.arrowSymbolName == "chevron.left")
        #expect(SeparatorState.shown.arrowSymbolName == "chevron.right")
    }
}
