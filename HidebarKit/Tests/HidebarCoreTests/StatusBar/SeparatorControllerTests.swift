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
    private let controller: SeparatorController

    init() {
        controller = SeparatorController(item: item)
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

    @Test func terminateFromHidingRestoresNormalLengthBeforeChangingState() {
        controller.hide()
        var stateAtWrite: SeparatorState?
        item.onLengthWrite = { _ in stateAtWrite = self.controller.state }
        controller.prepareForTermination()
        #expect(item.lengthWrites == [hiding, normal])
        #expect(stateAtWrite == .hiding)
        #expect(controller.state == .shown)
    }

    @Test func terminateFromShownKeepsNormalLength() {
        controller.prepareForTermination()
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
