import Testing

@testable import HidebarCore

@Suite struct AllOrNothingTests {
    @Test func deliversEveryPartInOrderWhenNoneIsMissing() {
        var delivered: [Int] = []
        #expect(AllOrNothing.deliver([1, 2, 3]) { delivered.append($0) })
        #expect(delivered == [1, 2, 3])
    }

    @Test func deliversNothingWhenTheLastPartIsMissing() {
        var delivered: [Int] = []
        #expect(!AllOrNothing.deliver([1, 2, nil]) { delivered.append($0) })
        #expect(delivered.isEmpty)
    }

    @Test func deliversNothingWhenTheFirstPartIsMissing() {
        var delivered: [Int] = []
        #expect(!AllOrNothing.deliver([nil, 2]) { delivered.append($0) })
        #expect(delivered.isEmpty)
    }

    @Test func nothingToDeliverCountsAsDelivered() {
        var delivered: [Int] = []
        #expect(AllOrNothing.deliver([] as [Int?]) { delivered.append($0) })
        #expect(delivered.isEmpty)
    }
}
