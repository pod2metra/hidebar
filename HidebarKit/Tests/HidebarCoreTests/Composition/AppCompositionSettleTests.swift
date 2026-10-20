import Testing

@testable import HidebarCore

/// After the separator is shown the bar re-lays out; icons are read once its frame stops changing.
@MainActor @Suite struct AppCompositionSettleTests {
    private let scene = CompositionScene()

    private var composition: AppComposition { scene.composition }

    private var poll: Int { AppComposition.settlePollMilliseconds }

    init() {
        scene.separator.hide()
    }

    @Test func aFrameThatChangesIsWaitedOutAndTheBodyRunsOnceItHoldsStill() {
        scene.script(wait: 1, movesSeparatorTo: 30)
        scene.script(wait: 2, movesSeparatorTo: 50)

        let waitsInside = composition.withRevealed { scene.bar.waits }

        #expect(waitsInside == 3)
        #expect(scene.bar.log == [.wait(poll), .wait(poll), .wait(poll)])
        #expect(scene.lengthAtWaits == [scene.normal, scene.normal, scene.normal])
    }

    @Test func aBarThatNeverSettlesIsReadAtTheDeadlineAndHiddenAgain() {
        for count in 1...100 {
            scene.script(wait: count, movesSeparatorTo: Double(count))
        }

        let waitsInside = composition.withRevealed { scene.bar.waits }

        #expect(waitsInside == AppComposition.settleDeadlineMilliseconds / poll)
        #expect(scene.separator.state == .hiding)
    }

    @Test func timeSpentReadingTheFrameCountsTowardsTheDeadline() {
        scene.bar.readCost = 100
        for count in 1...100 {
            scene.script(wait: count, movesSeparatorTo: Double(count))
        }

        let waitsInside = composition.withRevealed { scene.bar.waits }

        // The first read takes 100, every round 125 more: 100 + 8 * 125 reaches 1000.
        #expect(waitsInside == 8)
    }

    @Test func aFrameThatCannotBeReadIsNotWaitedFor() {
        scene.bar.frames[OwnItems.separatorID] = nil

        let waitsInside = composition.withRevealed { scene.bar.waits }

        #expect(waitsInside == 1)
    }
}
