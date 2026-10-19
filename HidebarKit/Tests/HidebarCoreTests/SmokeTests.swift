import Testing

@testable import HidebarCore

@Suite struct SmokeTests {
    @Test func clampBelowLowerReturnsLower() {
        #expect(clamp(-5, lower: 0, upper: 10) == 0)
    }

    @Test func clampAboveUpperReturnsUpper() {
        #expect(clamp(15, lower: 0, upper: 10) == 10)
    }

    @Test func clampInsideRangeReturnsValue() {
        #expect(clamp(5, lower: 0, upper: 10) == 5)
    }

    @Test func clampAtBoundsReturnsBounds() {
        #expect(clamp(0, lower: 0, upper: 10) == 0)
        #expect(clamp(10, lower: 0, upper: 10) == 10)
    }
}
