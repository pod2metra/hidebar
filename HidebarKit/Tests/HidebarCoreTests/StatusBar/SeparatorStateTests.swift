import Testing

@testable import HidebarCore

@Suite struct SeparatorStateTests {
    @Test func toggleSymbolPointsAtTheSideTheHiddenIconsAreOn() {
        #expect(SeparatorState.shown.toggleSymbolName == "chevron.right")
        #expect(SeparatorState.hiding.toggleSymbolName == "chevron.left")
    }
}
