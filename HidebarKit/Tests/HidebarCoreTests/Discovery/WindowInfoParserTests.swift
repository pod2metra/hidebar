import Foundation
import Testing

@testable import HidebarCore

@Suite struct WindowInfoParserTests {
    private let parser = WindowInfoParser { pid in pid == 629 ? "com.apple.controlcenter" : nil }

    /// A complete entry as `CGWindowListCopyWindowInfo` reports it; NSNumber values like the real list.
    private func raw(
        id: Int = 21, x: Double = 1566, without key: String? = nil
    ) -> [String: Any] {
        var entry: [String: Any] = [
            "kCGWindowNumber": NSNumber(value: id),
            "kCGWindowLayer": NSNumber(value: 25),
            "kCGWindowOwnerPID": NSNumber(value: 629),
            "kCGWindowName": "Clock",
            "kCGWindowIsOnscreen": true,
            "kCGWindowBounds": [
                "X": NSNumber(value: x), "Y": NSNumber(value: 0), "Width": NSNumber(value: 46),
                "Height": NSNumber(value: 24),
            ] as [String: Any],
        ]
        entry[key ?? ""] = nil
        return entry
    }

    @Test func completeEntryBecomesAWindowInfo() {
        #expect(
            parser.parse([raw()]) == [
                WindowInfo(
                    windowID: 21, layer: 25, frame: ItemFrame(x: 1566, y: 0, width: 46, height: 24),
                    isOnscreen: true, ownerPID: 629, ownerBundleID: "com.apple.controlcenter",
                    title: "Clock")
            ])
    }

    @Test func plainSwiftNumbersAreAccepted() {
        var entry = raw()
        entry["kCGWindowNumber"] = 7
        entry["kCGWindowBounds"] = ["X": 10, "Y": 0, "Width": 46.5, "Height": 24] as [String: Any]
        let result = parser.parse([entry])
        #expect(result.first?.windowID == 7)
        #expect(result.first?.frame == ItemFrame(x: 10, y: 0, width: 46.5, height: 24))
    }

    @Test func fractionalPositionIsKept() {
        #expect(parser.parse([raw(x: 1566.5)]).first?.frame.x == 1566.5)
    }

    @Test(arguments: ["kCGWindowNumber", "kCGWindowLayer", "kCGWindowBounds"])
    func entryWithoutARequiredKeyIsDropped(key: String) {
        #expect(parser.parse([raw(without: key)]).isEmpty)
    }

    @Test(arguments: ["X", "Y", "Width", "Height"])
    func entryWithIncompleteBoundsIsDropped(key: String) {
        var entry = raw()
        var bounds = entry["kCGWindowBounds"] as? [String: Any] ?? [:]
        bounds[key] = nil
        entry["kCGWindowBounds"] = bounds
        #expect(parser.parse([entry]).isEmpty)
    }

    @Test func wrongTypesAreDroppedNotGuessed() {
        var number = raw()
        number["kCGWindowNumber"] = "21"
        var bounds = raw()
        bounds["kCGWindowBounds"] = "0,0,46,24"
        var width = raw()
        width["kCGWindowBounds"] = ["X": 0, "Y": 0, "Width": "46", "Height": 24] as [String: Any]
        #expect(parser.parse([number, bounds, width]).isEmpty)
    }

    @Test func missingOnscreenMeansOffscreen() {
        #expect(parser.parse([raw(without: "kCGWindowIsOnscreen")]).first?.isOnscreen == false)
    }

    @Test func missingNameMeansEmptyTitle() {
        #expect(parser.parse([raw(without: "kCGWindowName")]).first?.title == "")
    }

    @Test func ownerBundleIDIsNilWhenThePidIsUnknown() {
        var stranger = raw()
        stranger["kCGWindowOwnerPID"] = NSNumber(value: 1)
        #expect(parser.parse([stranger]).first?.ownerBundleID == nil)
        #expect(parser.parse([stranger]).first?.ownerPID == 1)
    }

    @Test func entryWithoutAnOwnerPidIsDropped() {
        #expect(parser.parse([raw(without: "kCGWindowOwnerPID")]).isEmpty)
    }

    @Test func orderIsKeptAndBadEntriesAreSkippedBetweenGoodOnes() {
        let result = parser.parse([raw(id: 3), raw(id: 1, without: "kCGWindowLayer"), raw(id: 2)])
        #expect(result.map(\.windowID) == [3, 2])
    }

    @Test func emptyListGivesNoWindows() {
        #expect(parser.parse([]).isEmpty)
    }
}
