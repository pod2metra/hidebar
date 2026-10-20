import Testing

@testable import HidebarCore

@Suite struct StatusItemSlotsTests {
    @Test func theToggleIsRightOfTheSeparator() {
        #expect(StatusItemSlots.toggle < StatusItemSlots.separator)
    }

    @Test func fixedSlotIsSeededOnlyWhenTheItemHasNoPosition() {
        #expect(StatusItemSlots.fixedSeed(stored: nil, slot: 1) == 1)
        #expect(StatusItemSlots.fixedSeed(stored: nil, slot: 0) == 0)
        #expect(StatusItemSlots.fixedSeed(stored: 0, slot: 1) == nil)
        #expect(StatusItemSlots.fixedSeed(stored: 640, slot: 1) == nil)
    }

    @Test func groupWithAPositionKeepsIt() {
        #expect(StatusItemSlots.groupSeed(stored: 0.3, separator: 1, taken: []) == nil)
        #expect(StatusItemSlots.groupSeed(stored: 0, separator: 1, taken: []) == nil)
    }

    @Test func firstGroupLandsHalfwayBetweenTheRightEdgeAndTheSeparator() {
        #expect(StatusItemSlots.groupSeed(stored: nil, separator: 1, taken: []) == 0.5)
        #expect(StatusItemSlots.groupSeed(stored: nil, separator: 8, taken: []) == 4)
    }

    @Test func nextGroupLandsBetweenTheNearestTakenPositionAndTheSeparator() {
        #expect(StatusItemSlots.groupSeed(stored: nil, separator: 1, taken: [0, 0.5]) == 0.75)
        #expect(StatusItemSlots.groupSeed(stored: nil, separator: 1, taken: [0.5, 0, 0.75]) == 0.875)
    }

    @Test func positionsAtOrBeyondTheSeparatorAreIgnored() {
        #expect(StatusItemSlots.groupSeed(stored: nil, separator: 1, taken: [1]) == 0.5)
        #expect(StatusItemSlots.groupSeed(stored: nil, separator: 1, taken: [2, 40]) == 0.5)
        #expect(StatusItemSlots.groupSeed(stored: nil, separator: 1, taken: [0.5, 1, 9]) == 0.75)
    }

    @Test func newGroupIsAlwaysRightOfTheSeparatorAndLeftOfEveryTakenPositionBelowIt() {
        var taken = [StatusItemSlots.toggle]
        for _ in 0..<5 {
            let seed = StatusItemSlots.groupSeed(
                stored: nil, separator: StatusItemSlots.separator, taken: taken)
            #expect(seed != nil)
            #expect((seed ?? 0) < StatusItemSlots.separator)
            #expect((seed ?? 0) > (taken.max() ?? 0))
            taken.append(seed ?? 0)
        }
    }
}
