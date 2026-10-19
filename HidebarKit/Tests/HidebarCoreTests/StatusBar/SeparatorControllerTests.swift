import Testing

@testable import HidebarCore

@MainActor
final class FakeStatusItem: StatusItemControlling {
    var lengthWrites: [Double] = []
    var visibleWrites: [Bool] = []
    var onLengthWrite: (@MainActor (Double) -> Void)?

    var length: Double = 0 {
        didSet {
            lengthWrites.append(length)
            onLengthWrite?(length)
        }
    }

    var isVisible: Bool = false {
        didSet { visibleWrites.append(isVisible) }
    }
}

@MainActor
@Suite struct SeparatorControllerTests {
    private let normal = SeparatorController.normalLength
    private let hiding = SeparatorController.hidingLength
    private let item = FakeStatusItem()
    private let clock = ManualClock()
    private let controller: SeparatorController

    init() {
        controller = SeparatorController(item: item, clock: clock)
    }

    @Test func lengthsDiffer() {
        #expect(normal < 0)
        #expect(hiding >= 10_000)
    }

    @Test func startsShownWithoutTouchingTheItem() {
        #expect(controller.state == .shown)
        #expect(item.lengthWrites.isEmpty)
        #expect(item.visibleWrites.isEmpty)
    }

    // MARK: hide / show / toggle

    @Test func hideStretchesTheSeparator() {
        controller.hide()
        #expect(controller.state == .hiding)
        #expect(item.lengthWrites == [hiding])
    }

    @Test func showRestoresNormalLength() {
        controller.hide()
        controller.show()
        #expect(controller.state == .shown)
        #expect(item.lengthWrites == [hiding, normal])
        #expect(clock.timers.isEmpty)
    }

    @Test func hideTwiceWritesOnce() {
        controller.hide()
        controller.hide()
        #expect(item.lengthWrites == [hiding])
    }

    @Test func showTwiceWritesNothingSecondTime() {
        controller.hide()
        controller.show()
        controller.show()
        #expect(item.lengthWrites == [hiding, normal])
    }

    @Test func showWhileShownWritesNothing() {
        controller.show()
        #expect(controller.state == .shown)
        #expect(item.lengthWrites.isEmpty)
    }

    @Test func toggleFlipsBetweenStates() {
        controller.toggle()
        #expect(controller.state == .hiding)
        #expect(item.lengthWrites == [hiding])
        controller.toggle()
        #expect(controller.state == .shown)
        #expect(item.lengthWrites == [hiding, normal])
    }

    // MARK: auto-hide

    @Test func autoHideFiresAfterTheDelay() {
        controller.hide()
        controller.show(autoHideAfter: 5)
        clock.advance(by: 4.9)
        #expect(controller.state == .shown)
        clock.advance(by: 0.1)
        #expect(controller.state == .hiding)
        #expect(item.lengthWrites == [hiding, normal, hiding])
        #expect(clock.pending.isEmpty)
    }

    @Test func autoHideFiresOnlyOnce() {
        controller.show(autoHideAfter: 1)
        clock.advance(by: 1)
        controller.show()
        clock.advance(by: 100)
        #expect(controller.state == .shown)
    }

    @Test func manualHideCancelsTheTimer() {
        controller.show(autoHideAfter: 5)
        let timer = clock.timers[0]
        controller.hide()
        #expect(timer.isCancelled)
        #expect(clock.pending.isEmpty)
        controller.show()
        clock.advance(by: 100)
        #expect(controller.state == .shown)
    }

    @Test func manualShowCancelsThePreviousTimer() {
        controller.show(autoHideAfter: 5)
        let first = clock.timers[0]
        controller.show(autoHideAfter: 10)
        #expect(first.isCancelled)
        #expect(clock.pending.count == 1)
        clock.advance(by: 5)
        #expect(controller.state == .shown)
        clock.advance(by: 5)
        #expect(controller.state == .hiding)
    }

    @Test func showWithoutDelayCancelsTheTimer() {
        controller.show(autoHideAfter: 5)
        controller.show()
        #expect(clock.pending.isEmpty)
        clock.advance(by: 100)
        #expect(controller.state == .shown)
    }

    @Test func toggleToShownCancelsTheTimerAndCanArmAnother() {
        controller.show(autoHideAfter: 5)
        controller.toggle()
        #expect(controller.state == .hiding)
        #expect(clock.pending.isEmpty)
        controller.toggle(autoHideAfter: 3)
        #expect(controller.state == .shown)
        clock.advance(by: 3)
        #expect(controller.state == .hiding)
    }

    @Test func toggleToShownWithoutDelayArmsNothing() {
        controller.hide()
        controller.toggle()
        #expect(clock.timers.isEmpty)
    }

    @Test func timerDoesNotOutliveTheController() {
        var local: SeparatorController? = SeparatorController(item: item, clock: clock)
        local?.show(autoHideAfter: 5)
        local = nil
        clock.advance(by: 5)
        #expect(item.lengthWrites.isEmpty)
    }

    // MARK: crash safety

    @Test func terminateFromHidingRestoresNormalLengthBeforeChangingState() {
        controller.hide()
        var stateAtWrite: SeparatorState?
        item.onLengthWrite = { _ in stateAtWrite = self.controller.state }
        controller.prepareForTermination()
        #expect(item.lengthWrites == [hiding, normal])
        #expect(stateAtWrite == .hiding)
        #expect(controller.state == .shown)
    }

    @Test func terminateRestoresLengthBeforeCancellingTheTimer() {
        controller.show(autoHideAfter: 5)
        let timer = clock.timers[0]
        var cancelsAtWrite: Int?
        item.onLengthWrite = { _ in cancelsAtWrite = timer.cancelCount }
        controller.prepareForTermination()
        #expect(cancelsAtWrite == 0)
        #expect(timer.cancelCount == 1)
    }

    @Test func terminateFromShownKeepsNormalLength() {
        controller.prepareForTermination()
        #expect(item.lengthWrites == [normal])
        #expect(controller.state == .shown)
    }

    @Test func terminateWithArmedTimerCancelsItAndNeverHidesAgain() {
        controller.show(autoHideAfter: 5)
        let timer = clock.timers[0]
        controller.prepareForTermination()
        #expect(timer.isCancelled)
        clock.advance(by: 100)
        #expect(item.lengthWrites == [normal])
        #expect(controller.state == .shown)
    }

    @Test func terminateIsIdempotent() {
        controller.hide()
        controller.prepareForTermination()
        controller.prepareForTermination()
        #expect(item.lengthWrites == [hiding, normal, normal])
        #expect(controller.state == .shown)
    }

    @Test func launchResetsAnItemLeftHiddenByACrash() {
        item.length = hiding
        item.isVisible = false
        item.lengthWrites = []
        item.visibleWrites = []
        var visibleWritesAtLengthWrite: Int?
        item.onLengthWrite = { _ in visibleWritesAtLengthWrite = self.item.visibleWrites.count }
        controller.prepareForLaunch()
        #expect(item.length == normal)
        #expect(item.isVisible)
        #expect(item.lengthWrites == [normal])
        #expect(item.visibleWrites == [true])
        #expect(visibleWritesAtLengthWrite == 0)
        #expect(controller.state == .shown)
    }

    @Test func launchRestoresLengthBeforeCancellingTheTimer() {
        controller.show(autoHideAfter: 5)
        let timer = clock.timers[0]
        var cancelsAtWrite: Int?
        item.onLengthWrite = { _ in cancelsAtWrite = timer.cancelCount }
        controller.prepareForLaunch()
        #expect(cancelsAtWrite == 0)
        #expect(timer.cancelCount == 1)
        clock.advance(by: 100)
        #expect(controller.state == .shown)
        #expect(item.lengthWrites == [normal])
    }

    @Test func launchIsIdempotent() {
        controller.prepareForLaunch()
        controller.prepareForLaunch()
        #expect(item.lengthWrites == [normal, normal])
        #expect(item.visibleWrites == [true, true])
    }

    @Test func hidingWorksAgainAfterLaunchReset() {
        controller.hide()
        controller.prepareForLaunch()
        controller.hide()
        #expect(controller.state == .hiding)
        #expect(item.lengthWrites == [hiding, normal, hiding])
    }
}
