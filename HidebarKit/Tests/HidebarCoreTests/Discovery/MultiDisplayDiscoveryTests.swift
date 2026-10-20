import Testing

@testable import HidebarCore

/// Rows measured on macOS 26 with two displays: every status item has a window on each display's
/// bar, the second display's copies at its own y.
@Suite struct MultiDisplayDiscoveryTests {
    private func ids(_ items: [DiscoveredItem]) -> [Int] { items.map(\.windowID) }

    private let primary = ItemFrame(x: 0, y: 0, width: 3_282, height: 1_117)

    @Test func twinOnTheSecondDisplayIsDropped() {
        let main = window(21, x: 2_340, width: 26, height: 30)
        let twin = window(22, x: 3_780, y: -434, width: 26, height: 30)
        #expect(ids(discover([twin, main], display: primary)) == [21])
    }

    @Test func everyItemKeepsOnlyItsMainDisplayCopy() {
        let rows = [
            window(1, x: 2_340, width: 26, height: 30), window(2, x: 2_380, width: 26, height: 30),
            window(3, x: 3_780, y: -434, width: 26, height: 30),
            window(4, x: 3_820, y: -434, width: 26, height: 30),
        ]
        #expect(ids(discover(rows, display: primary)) == [1, 2])
    }

    @Test func singleDisplayIsUnchanged() {
        let rows = [window(1, x: 1_612, width: 118), window(2, x: 1_566)]
        let single = ItemFrame(x: 0, y: 0, width: 1_728, height: 1_117)
        #expect(ids(discover(rows, display: single)) == [2, 1])
    }

    @Test func sameYOnTheNextDisplayIsDroppedByTheRightEdge() {
        let main = window(1, x: 3_235, width: 46)
        let neighbour = window(2, x: 3_282)
        #expect(ids(discover([main, neighbour], display: primary)) == [1])
    }

    @Test func hiddenItemLeftOfTheDisplayIsKept() {
        let hidden = window(1, x: -9_000)
        #expect(ids(discover([hidden, window(2, x: 100)], display: primary)) == [1, 2])
    }

    @Test func displayWithNegativeOriginUsesItsOwnTopAndRightEdge() {
        let left = ItemFrame(x: -1_920, y: -434, width: 1_920, height: 1_080)
        let onLeft = window(1, x: -100, y: -434)
        let onRight = window(2, x: 0, y: 0)
        let atOrigin = window(3, x: -100, y: 0)
        #expect(ids(discover([onLeft, onRight, atOrigin], display: left)) == [1])
    }

    @Test func topToleranceIsOnePoint() {
        let exact = window(1, x: 10, y: 1)
        let below = window(2, x: 20, y: -1)
        let outside = window(3, x: 30, y: 1.5)
        let outsideBelow = window(4, x: 40, y: -1.5)
        #expect(ids(discover([exact, below, outside, outsideBelow], display: primary)) == [1, 2])
    }

    @Test func windowStartingAtTheRightEdgeIsDroppedOneBeforeIsKept() {
        let before = window(1, x: 3_281)
        let at = window(2, x: 3_282)
        #expect(ids(discover([before, at], display: primary)) == [1])
    }
}
