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
}
