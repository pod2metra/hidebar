import Testing

@testable import HidebarCore

@Suite struct SoleTests {
    @Test func emptyCollectionHasNoSoleElement() {
        #expect([Int]().sole == nil)
    }

    @Test func singleElementIsTheSoleElement() {
        #expect([7].sole == 7)
    }

    @Test func severalElementsHaveNoSoleElement() {
        #expect([1, 2].sole == nil)
        #expect([1, 1, 1].sole == nil)
    }
}
