import Testing

@testable import HidebarCore

@Suite struct ScrollInputTests {
    private func wheel(x: Double = 0, y: Double) -> ScrollInput {
        ScrollInput(deltaX: x, deltaY: y, hasPreciseDeltas: false)
    }

    private func trackpad(x: Double = 0, y: Double = 0) -> ScrollInput {
        ScrollInput(deltaX: x, deltaY: y, hasPreciseDeltas: true)
    }

    @Test func wheelDrivesTheStripWithItsVerticalDeltaScaledToPointsPerLine() {
        #expect(wheel(y: -3).offsetDelta == 3 * ScrollInput.pointsPerWheelLine)
        #expect(wheel(y: 2).offsetDelta == -2 * ScrollInput.pointsPerWheelLine)
        #expect(ScrollInput.pointsPerWheelLine == 20)
    }

    @Test func wheelIgnoresItsHorizontalDelta() {
        #expect(wheel(x: 7, y: -1).offsetDelta == ScrollInput.pointsPerWheelLine)
        #expect(wheel(x: 7, y: 0).offsetDelta == 0)
    }

    @Test func trackpadDrivesTheStripWithItsHorizontalDeltaInPoints() {
        #expect(trackpad(x: -12, y: 5).offsetDelta == 12)
        #expect(trackpad(x: 12, y: -5).offsetDelta == -12)
    }

    @Test func trackpadFallsBackToTheVerticalDeltaForAPurelyVerticalSwipe() {
        #expect(trackpad(y: -9).offsetDelta == 9)
        #expect(trackpad(y: 9).offsetDelta == -9)
    }

    @Test func idleEventScrollsNowhere() {
        #expect(trackpad().offsetDelta == 0)
        #expect(wheel(y: 0).offsetDelta == 0)
    }
}
