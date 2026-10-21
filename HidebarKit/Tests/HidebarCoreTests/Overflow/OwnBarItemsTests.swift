import Testing

@testable import HidebarCore

@Suite struct OwnBarItemsTests {
    private let pipe = BarSpan(x: 40, width: 4)
    private let arrow = BarSpan(x: 90, width: 10)

    private func frame(x: Double, width: Double, y: Double = 0, height: Double = 24) -> ItemFrame {
        ItemFrame(x: x, y: y, width: width, height: height)
    }

    // MARK: both spans or nothing

    @Test func bothSpansMakeTheOwnItems() {
        let own = OwnBarItems(separator: pipe, arrow: arrow)
        #expect(own?.separator == pipe)
        #expect(own?.arrow == arrow)
    }

    @Test func aMissingSpanMakesNoOwnItems() {
        #expect(OwnBarItems(separator: nil, arrow: arrow) == nil)
        #expect(OwnBarItems(separator: pipe, arrow: nil) == nil)
        #expect(OwnBarItems(separator: nil, arrow: nil) == nil)
    }

    @Test func aSpanWithoutWidthIsNotAWindowOnTheBar() {
        #expect(OwnBarItems(separator: BarSpan(x: 40, width: 0), arrow: arrow) == nil)
        #expect(OwnBarItems(separator: pipe, arrow: BarSpan(x: 90, width: -1)) == nil)
    }

    // MARK: matching a window by its frame

    @Test func aWindowWithTheFrameOfAnOwnItemIsOwn() throws {
        let own = try #require(OwnBarItems(separator: pipe, arrow: arrow))
        #expect(own.contains(frame(x: 40, width: 4)))
        #expect(own.contains(frame(x: 90, width: 10)))
    }

    @Test func otherWindowsAreNotOwn() throws {
        let own = try #require(OwnBarItems(separator: pipe, arrow: arrow))
        #expect(!own.contains(frame(x: 44, width: 20)))
        #expect(!own.contains(frame(x: 40, width: 10)))
        #expect(!own.contains(frame(x: 90, width: 4)))
    }

    @Test func theHeightAndTheTopOfTheWindowDoNotMatter() throws {
        let own = try #require(OwnBarItems(separator: pipe, arrow: arrow))
        #expect(own.contains(frame(x: 40, width: 4, y: 7, height: 99)))
    }

    @Test func roundingWithinOnePointStillMatches() throws {
        let own = try #require(OwnBarItems(separator: pipe, arrow: arrow))
        #expect(own.contains(frame(x: 41, width: 5)))
        #expect(own.contains(frame(x: 39, width: 3)))
        #expect(!own.contains(frame(x: 41.5, width: 4)))
        #expect(!own.contains(frame(x: 40, width: 5.5)))
        #expect(!own.contains(frame(x: 38.5, width: 4)))
        #expect(!own.contains(frame(x: 40, width: 2.5)))
    }
}
