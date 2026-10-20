import Testing

@testable import HidebarCore

@Suite struct ScrollInputTests {
    private func wheel(x: Double = 0, y: Double = 0) -> ScrollInput {
        ScrollInput(deltaX: x, deltaY: y, hasPreciseDeltas: false)
    }

    private func trackpad(x: Double = 0, y: Double = 0) -> ScrollInput {
        ScrollInput(deltaX: x, deltaY: y, hasPreciseDeltas: true)
    }

    @Test func verticalWheelScrollsByLinesScaledToPoints() {
        #expect(wheel(y: -3).offsetDelta == 3 * ScrollInput.pointsPerWheelLine)
        #expect(wheel(y: 2).offsetDelta == -2 * ScrollInput.pointsPerWheelLine)
        #expect(ScrollInput.pointsPerWheelLine == 20)
    }

    @Test func horizontalWheelAndShiftWheelScrollByLinesToo() {
        #expect(wheel(x: -2).offsetDelta == 2 * ScrollInput.pointsPerWheelLine)
        #expect(wheel(x: 7, y: -1).offsetDelta == -7 * ScrollInput.pointsPerWheelLine)
    }

    @Test func trackpadScrollsInPointsAlongTheDominantAxis() {
        #expect(trackpad(x: -12, y: 5).offsetDelta == 12)
        #expect(trackpad(x: 12, y: -5).offsetDelta == -12)
        #expect(trackpad(x: 3, y: -9).offsetDelta == 9)
        #expect(trackpad(y: 9).offsetDelta == -9)
    }

    @Test func tieGoesToTheVerticalAxis() {
        #expect(trackpad(x: 5, y: -5).offsetDelta == 5)
        #expect(wheel(x: -4, y: 4).offsetDelta == -4 * ScrollInput.pointsPerWheelLine)
    }

    @Test func idleEventScrollsNowhere() {
        #expect(trackpad().offsetDelta == 0)
        #expect(wheel().offsetDelta == 0)
    }
}
