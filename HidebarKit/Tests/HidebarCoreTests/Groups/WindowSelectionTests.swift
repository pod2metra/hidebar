import Testing

@testable import HidebarCore

@Suite struct WindowSelectionTests {
    private struct Window: Equatable {
        let number: Int
        let label: String
    }

    private let windows = [Window(number: 4, label: "a"), Window(number: 9, label: "b"), Window(number: 9, label: "c")]

    @Test func picksTheWindowWhoseIdMatches() {
        #expect(windows.firstWindow(withID: 4, idOf: \.number) == windows[0])
    }

    @Test func firstOfSeveralMatchesWins() {
        #expect(windows.firstWindow(withID: 9, idOf: \.number) == windows[1])
    }

    @Test func missingIdGivesNil() {
        #expect(windows.firstWindow(withID: 5, idOf: \.number) == nil)
        #expect([Window]().firstWindow(withID: 4, idOf: \.number) == nil)
    }
}
