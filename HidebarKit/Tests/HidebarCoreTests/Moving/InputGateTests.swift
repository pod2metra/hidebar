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
