import Foundation
import Testing

@testable import HidebarCore

/// Rows: 0 header(visible), 1 a, 2 b, 3 header(hidden), 4 header(group), 5 c, 6 d.
@Suite struct SettingsRowsTests {
    private let group = UUID()

    private var rows: SettingsRows {
        SettingsRows(sections: [
            SettingsSection(placement: .visible, symbol: nil, items: [moveID("a"), moveID("b")]),
            SettingsSection(placement: .hidden, symbol: nil, items: []),
            SettingsSection(
                placement: .group(group), symbol: try? GroupSymbol(name: "star"),
                items: [moveID("c"), moveID("d")]),
        ])
    }

    private func drop(_ name: String, aboveRow row: Int) -> SettingsDrop? {
        rows.drop(of: moveID(name), aboveRow: row)
    }

    private func place(_ placement: Placement, _ index: Int) -> SettingsDrop {
        SettingsDrop(placement: placement, index: index)
    }

    // MARK: rows

    @Test func sectionsBecomeHeadersFollowedByTheirItems() {
        #expect(
            rows.rows == [
                .header(placement: .visible, title: "On the menu bar", symbolName: nil),
                .item(moveID("a"), placement: .visible), .item(moveID("b"), placement: .visible),
                .header(placement: .hidden, title: "Hidden", symbolName: nil),
                .header(placement: .group(group), title: "Group", symbolName: "star"),
                .item(moveID("c"), placement: .group(group)),
                .item(moveID("d"), placement: .group(group)),
            ])
    }

    @Test func itemAtRowAnswersOnlyForItemRows() {
        #expect(rows.item(atRow: 1) == moveID("a"))
        #expect(rows.item(atRow: 6) == moveID("d"))
        #expect(rows.item(atRow: 0) == nil)
        #expect(rows.item(atRow: 3) == nil)
        #expect(rows.item(atRow: -1) == nil)
        #expect(rows.item(atRow: 7) == nil)
    }

    @Test func groupIdAtRowAnswersOnlyForGroupHeaders() {
        #expect(rows.groupID(atRow: 4) == group)
        #expect(rows.groupID(atRow: 0) == nil)
        #expect(rows.groupID(atRow: 3) == nil)
        #expect(rows.groupID(atRow: 5) == nil)
        #expect(rows.groupID(atRow: -1) == nil)
        #expect(rows.groupID(atRow: 7) == nil)
    }

    // MARK: drops

    @Test func dropAboveTheFirstHeaderIsTheStartOfTheFirstSection() {
        #expect(drop("b", aboveRow: 0) == place(.visible, 0))
    }

    @Test func dropRightUnderAHeaderIsTheStartOfItsSection() {
        #expect(drop("b", aboveRow: 1) == place(.visible, 0))
        #expect(drop("a", aboveRow: 5) == place(.group(group), 0))
    }

    @Test func dropAboveTheNextHeaderIsTheEndOfTheSectionBefore() {
        #expect(drop("c", aboveRow: 3) == place(.visible, 2))
        #expect(drop("a", aboveRow: 4) == place(.hidden, 0))
        #expect(drop("a", aboveRow: 7) == place(.group(group), 2))
    }

    @Test func dropInTheMiddleOfAnotherSectionKeepsItsRowOffset() {
        #expect(drop("a", aboveRow: 6) == place(.group(group), 1))
    }

    @Test func draggingDownInsideTheSectionLeavesAGapSoTheIndexShrinks() {
        #expect(drop("a", aboveRow: 3) == place(.visible, 1))
        #expect(drop("c", aboveRow: 7) == place(.group(group), 1))
        #expect(drop("a", aboveRow: 2) == place(.visible, 0))
    }

    @Test func draggingUpInsideTheSectionKeepsTheIndex() {
        #expect(drop("d", aboveRow: 5) == place(.group(group), 0))
    }

    @Test func droppingAnItemOnItsOwnPlaceKeepsItsIndex() {
        #expect(drop("d", aboveRow: 6) == place(.group(group), 1))
        #expect(drop("d", aboveRow: 7) == place(.group(group), 1))
    }

    @Test func unknownItemOrNoRowsMeansNoDrop() {
        #expect(drop("gone", aboveRow: 1) == nil)
        #expect(SettingsRows(sections: []).drop(of: moveID("a"), aboveRow: 0) == nil)
    }
}
