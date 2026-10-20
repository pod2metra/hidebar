import Testing

@testable import HidebarCore

@Suite struct InputGateTests {
    @Test func startsOpenAndLetsEverythingPass() {
        let gate = InputGate()
        #expect(!gate.suppressUserInput)
        #expect(gate.shouldPass(isSynthetic: false))
        #expect(gate.shouldPass(isSynthetic: true))
    }

    @Test func beginDropsUserInputAndKeepsSyntheticEvents() {
        let gate = InputGate()
        gate.begin()
        #expect(gate.suppressUserInput)
        #expect(!gate.shouldPass(isSynthetic: false))
        #expect(gate.shouldPass(isSynthetic: true))
    }

    @Test func endReopensTheGate() {
        let gate = InputGate()
        gate.begin()
        gate.end()
        #expect(!gate.suppressUserInput)
        #expect(gate.shouldPass(isSynthetic: false))
    }

    @Test func nestedBeginStaysClosedUntilTheOutermostEnd() {
        let gate = InputGate()
        gate.begin()
        gate.begin()
        gate.end()
        #expect(gate.suppressUserInput)
        gate.end()
        #expect(!gate.suppressUserInput)
    }

    @Test func endWithoutBeginLeavesTheGateOpenAndDoesNotBankCredit() {
        let gate = InputGate()
        gate.end()
        #expect(!gate.suppressUserInput)
        gate.begin()
        #expect(gate.suppressUserInput)
    }

    // MARK: total bound

    private func boundedGate(_ time: TestUptime) -> InputGate {
        InputGate(maxSuppressionMilliseconds: 100, uptime: time.reader)
    }

    @Test func gateLetsUserInputThroughOnceTheOutermostBeginIsOlderThanTheBound() {
        let time = TestUptime()
        let gate = boundedGate(time)
        gate.begin()
        time.advance(by: 99)
        #expect(gate.suppressUserInput)
        #expect(!gate.isOverdue)

        time.advance(by: 1)
        #expect(!gate.suppressUserInput)
        #expect(gate.isOverdue)
        #expect(gate.shouldPass(isSynthetic: false))
    }

    @Test func aNestedBeginDoesNotRestartTheClock() {
        let time = TestUptime()
        let gate = boundedGate(time)
        gate.begin()
        time.advance(by: 60)
        gate.begin()
        time.advance(by: 40)
        #expect(gate.isOverdue)
        gate.end()
        #expect(gate.isOverdue)
    }

    @Test func endingAnOverdueGateClosesItAndTheNextBeginStartsFresh() {
        let time = TestUptime()
        let gate = boundedGate(time)
        gate.begin()
        time.advance(by: 500)
        gate.end()
        #expect(!gate.isOverdue)
        #expect(!gate.suppressUserInput)

        gate.begin()
        #expect(gate.suppressUserInput)
        #expect(!gate.isOverdue)
    }

    @Test func aGateThatWasNeverBegunIsNeverOverdue() {
        let time = TestUptime()
        let gate = boundedGate(time)
        time.advance(by: 10_000)
        #expect(!gate.isOverdue)
        #expect(!gate.suppressUserInput)
    }

    @Test func onlyTheAppTagMarksAnEventSynthetic() {
        #expect(InputGate.isSynthetic(userData: InputGate.syntheticEventTag))
        #expect(!InputGate.isSynthetic(userData: 0))
        #expect(!InputGate.isSynthetic(userData: InputGate.syntheticEventTag + 1))
        #expect(!InputGate.isSynthetic(userData: InputGate.syntheticEventTag - 1))
    }

    @Test func tapDisabledNotificationsAskForTheTapToBeTurnedBackOn() {
        #expect(InputGate.shouldReenable(eventTypeRaw: 0xFFFF_FFFE))
        #expect(InputGate.shouldReenable(eventTypeRaw: 0xFFFF_FFFF))
    }

    @Test func rawValuesMatchTheSystemConstants() {
        #expect(InputGate.tapDisabledByTimeoutRaw == 0xFFFF_FFFE)
        #expect(InputGate.tapDisabledByUserInputRaw == 0xFFFF_FFFF)
    }

    @Test func ordinaryEventTypesDoNotReenableTheTap() {
        #expect(!InputGate.shouldReenable(eventTypeRaw: 0))
        #expect(!InputGate.shouldReenable(eventTypeRaw: 1))
        #expect(!InputGate.shouldReenable(eventTypeRaw: 22))
        #expect(!InputGate.shouldReenable(eventTypeRaw: 0xFFFF_FFFD))
    }
}
