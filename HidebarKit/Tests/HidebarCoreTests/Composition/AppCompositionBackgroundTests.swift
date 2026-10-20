import Foundation
import Testing

@testable import HidebarCore

/// Reading the bar off the main thread suspends the caller with the separator revealed; the
/// reveal must end exactly once, and the user's own toggle must not be undone by it.
@MainActor @Suite struct AppCompositionBackgroundTests {
    private let scene = CompositionScene()

    private var composition: AppComposition { scene.composition }

    private func startRead() async -> Task<[DiscoveredItem], Never> {
        let count = await scene.background.started + 1
        let read = Task { await composition.discoverRevealedInBackground() }
        let started = await waitForReads(count, in: scene.background)
        #expect(started)
        if !started { await scene.background.releaseAll() }
        return read
    }

    @Test func aHidingSeparatorStaysRevealedWhileTheReadRunsThenHidesAgain() async {
        scene.separator.hide()

        let read = await startRead()
        #expect(scene.separator.state == .shown)
        #expect(scene.bar.log == [.wait(AppComposition.settlePollMilliseconds)])
        await scene.background.release(0)

        #expect(await read.value == scene.backgroundFound)
        #expect(scene.separator.state == .hiding)
        #expect(scene.item.lengthWrites == [scene.hiding, scene.normal, scene.hiding])
    }

    @Test func aShownSeparatorIsLeftAlone() async {
        let read = await startRead()
        await scene.background.release(0)

        #expect(await read.value == scene.backgroundFound)
        #expect(scene.item.lengthWrites.isEmpty)
        #expect(scene.bar.log.isEmpty)
    }

    @Test func overlappingReadsShareOneRevealAndTheLastToFinishEndsIt() async {
        scene.separator.hide()
        let first = await startRead()
        let second = await startRead()

        await scene.background.release(0)
        _ = await first.value
        #expect(scene.separator.state == .shown)

        await scene.background.release(1)
        _ = await second.value
        #expect(scene.separator.state == .hiding)
        #expect(scene.item.lengthWrites == [scene.hiding, scene.normal, scene.hiding])
        #expect(scene.bar.log == [.wait(AppComposition.settlePollMilliseconds)])
    }

    @Test func theReadThatDidNotRevealFinishingFirstLeavesTheEndToTheOneThatDid() async {
        scene.separator.hide()
        let first = await startRead()
        let second = await startRead()

        await scene.background.release(1)
        _ = await second.value
        #expect(scene.separator.state == .shown)

        await scene.background.release(0)
        _ = await first.value
        #expect(scene.separator.state == .hiding)
        #expect(scene.item.lengthWrites == [scene.hiding, scene.normal, scene.hiding])
    }

    @Test func eachReadRevealsAgainOnceTheEarlierOneIsOver() async {
        scene.separator.hide()
        for index in 0..<2 {
            let read = await startRead()
            #expect(scene.separator.state == .shown)
            await scene.background.release(index)
            _ = await read.value
            #expect(scene.separator.state == .hiding)
        }
        #expect(
            scene.item.lengthWrites == [
                scene.hiding, scene.normal, scene.hiding, scene.normal, scene.hiding,
            ])
    }

    // MARK: toggling

    @Test func toggleFlipsTheSeparatorAndAnswersWithItsNewState() {
        #expect(composition.toggleSeparator() == .hiding)
        #expect(scene.separator.state == .hiding)
        #expect(composition.toggleSeparator() == .shown)
        #expect(scene.separator.state == .shown)
    }

    @Test func toggleIsIgnoredWhileAReadHasTheBarRevealed() async {
        scene.separator.hide()
        let read = await startRead()
        let writes = scene.item.lengthWrites

        #expect(composition.toggleSeparator() == .shown)
        #expect(scene.item.lengthWrites == writes)

        await scene.background.release(0)
        _ = await read.value
        #expect(scene.separator.state == .hiding)
    }

    @Test func toggleWorksAgainOnceTheReadIsOver() async {
        let read = await startRead()
        await scene.background.release(0)
        _ = await read.value

        #expect(composition.toggleSeparator() == .hiding)
    }
}
