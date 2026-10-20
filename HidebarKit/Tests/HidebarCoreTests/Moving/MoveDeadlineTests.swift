import Testing

@testable import HidebarCore

@Suite struct MoveDeadlineTests {
    private func deadline(_ time: TestUptime) -> MoveDeadline {
        MoveDeadline(budgetMilliseconds: 100, uptime: time.reader)
    }

    @Test func defaultBudgetIsTenSeconds() {
        #expect(MoveDeadline.defaultBudgetMilliseconds == 10_000)
        let time = TestUptime()
        let deadline = MoveDeadline(uptime: time.reader)
        deadline.begin()
        time.advance(by: 9_999)
        #expect(!deadline.isOverdue)
        time.advance(by: 1)
        #expect(deadline.isOverdue)
    }

    @Test func isOverdueOnceTheOutermostBeginIsAsOldAsTheBudget() {
        let time = TestUptime()
        let deadline = deadline(time)
        deadline.begin()
        time.advance(by: 99)
        #expect(!deadline.isOverdue)

        time.advance(by: 1)
        #expect(deadline.isOverdue)
    }

    @Test func aNestedBeginDoesNotRestartTheClock() {
        let time = TestUptime()
        let deadline = deadline(time)
        deadline.begin()
        time.advance(by: 60)
        deadline.begin()
        time.advance(by: 40)
        #expect(deadline.isOverdue)
        deadline.end()
        #expect(deadline.isOverdue)
    }

    @Test func endingTheOutermostBeginClearsOverdueAndTheNextBeginStartsFresh() {
        let time = TestUptime()
        let deadline = deadline(time)
        deadline.begin()
        time.advance(by: 500)
        deadline.end()
        #expect(!deadline.isOverdue)

        deadline.begin()
        #expect(!deadline.isOverdue)
    }

    @Test func endWithoutBeginIsIgnoredAndDoesNotBankCredit() {
        let time = TestUptime()
        let deadline = deadline(time)
        deadline.end()
        deadline.begin()
        time.advance(by: 100)
        #expect(deadline.isOverdue)
        deadline.end()
        #expect(!deadline.isOverdue)
    }

    @Test func aDeadlineThatWasNeverBegunIsNeverOverdue() {
        let time = TestUptime()
        let deadline = deadline(time)
        time.advance(by: 10_000)
        #expect(!deadline.isOverdue)
    }
}
