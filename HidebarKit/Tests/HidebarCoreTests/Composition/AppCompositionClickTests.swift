import Testing

@testable import HidebarCore

/// The hiding separator pushes `a`, `b`, `c` off screen; a click must reveal them first.
/// Waits are numbered since creation: the settle pause of each reveal counts, and so does each
/// poll of a drag.
@MainActor @Suite struct AppCompositionClickTests {
    private let scene = CompositionScene()

    private var composition: AppComposition { scene.composition }

    private var revealCycle: [Double] { [scene.hiding, scene.normal, scene.hiding] }

    init() {
        scene.separator.hide()
    }

    /// Click on `a`: settle is wait 1, the reveal drag polls at wait 2.
    private func clickA() -> ClickOutcome {
        scene.script(wait: 2, moves: "a", to: 22)
        return composition.click(moveID("a"))
    }

    @Test func clickRevealsTheSeparatorBeforeLookingForTheIconAndHidesItAfterwards() {
        #expect(clickA() == .clicked)
        #expect(scene.lengthAtDiscovery == [scene.normal])
        #expect(scene.lengthAtWaits == [scene.normal, scene.normal])
        #expect(scene.item.lengthWrites == revealCycle)
        #expect(scene.bar.clicks == [CursorPoint(x: 27, y: 10)])
        #expect(scene.proxy.hasDisplacedItem)
        #expect(!scene.gate.suppressUserInput)
    }

    @Test func refusedClickStillPutsTheSeparatorBack() {
        #expect(composition.click(moveID("gone")) == .refused(.notManaged))
        #expect(scene.item.lengthWrites == revealCycle)
        #expect(scene.bar.clicks.isEmpty)
    }

    @Test func clickWhileAnIconIsAwayBringsItHomeFirst() {
        #expect(clickA() == .clicked)
        // Second click: settle is wait 3, the return of `a` polls at wait 4, the reveal of `b` at 5.
        scene.script(wait: 4, moves: "a", to: 110)
        scene.script(wait: 5, moves: "b", to: 22)

        #expect(composition.click(moveID("b")) == .clicked)
        #expect(
            scene.bar.ups == [
                CursorPoint(x: 20, y: 10), CursorPoint(x: 120, y: 10), CursorPoint(x: 20, y: 10),
            ])
        #expect(scene.bar.clicks.count == 2)
        #expect(scene.proxy.hasDisplacedItem)
        #expect(scene.lengthAtWaits.allSatisfy { $0 == scene.normal })
        #expect(scene.item.lengthWrites == revealCycle + [scene.normal, scene.hiding])
    }

    @Test func clickIsRefusedWhenTheAwayIconCannotBeBroughtHome() {
        #expect(clickA() == .clicked)
        let clicks = scene.bar.clicks.count

        #expect(composition.click(moveID("b")) == .refused(.displacedItemPending))
        #expect(scene.bar.clicks.count == clicks)
        #expect(scene.proxy.hasDisplacedItem)
        #expect(scene.separator.state == .hiding)
    }

    @Test func aClickFromTheOverflowStripRevealsTheSeparatorLikeAnyOtherClick() async {
        let composition = composition
        let strip = OverflowStripViewModel(
            snapshotter: FakeSnapshotter(), click: { composition.click($0) })
        // Room for two of the three 10-wide icons: `a` is left over.
        let screen = OverflowCalculator(
            screenWidth: 25, notchRightArea: nil, menusWidth: 0, spacing: 0)
        await strip.recompute(
            screen: screen, viewportWidth: 25, items: scene.found,
            capabilities: PermissionsState(accessibility: true, screenRecording: false).capabilities)
        #expect(strip.rows.map(\.id) == [moveID("a")])
        scene.script(wait: 2, moves: "a", to: 22)

        #expect(strip.click(rowAt: 0) == .clicked)

        #expect(scene.item.lengthWrites == revealCycle)
        #expect(scene.lengthAtWaits == [scene.normal, scene.normal])
        #expect(scene.bar.clicks == [CursorPoint(x: 27, y: 10)])
        #expect(scene.proxy.hasDisplacedItem)
    }

    // MARK: restoreIfDisplaced

    @Test func restoreWithNothingAwayLeavesTheSeparatorAlone() {
        #expect(composition.restoreIfDisplaced() == .nothingToRestore)
        #expect(scene.item.lengthWrites == [scene.hiding])
        #expect(scene.bar.log.isEmpty)
    }

    @Test func restoreRevealsTheSeparatorSoTheIconCanBeDraggedHome() {
        #expect(clickA() == .clicked)
        scene.script(wait: 4, moves: "a", to: 110)

        #expect(composition.restoreIfDisplaced() == .restored)
        #expect(!scene.proxy.hasDisplacedItem)
        #expect(scene.lengthAtWaits.allSatisfy { $0 == scene.normal })
        #expect(scene.item.lengthWrites == revealCycle + [scene.normal, scene.hiding])
    }

    @Test func timeoutReturnsTheIconWithTheSeparatorRevealed() {
        #expect(clickA() == .clicked)
        // The timeout restore: settle is wait 3, the return of `a` polls at wait 4.
        scene.script(wait: 4, moves: "a", to: 110)

        scene.timer.advance(by: 10)

        #expect(!scene.proxy.hasDisplacedItem)
        #expect(scene.lengthAtWaits.allSatisfy { $0 == scene.normal })
        #expect(scene.item.lengthWrites == revealCycle + [scene.normal, scene.hiding])
    }

    @Test func timeoutWaitsWhileAMenuIsOpenWithoutRevealingTheSeparator() {
        scene.menu.isOpen = true
        #expect(clickA() == .clicked)

        scene.timer.advance(by: 10)

        #expect(scene.proxy.hasDisplacedItem)
        #expect(scene.item.lengthWrites == revealCycle)

        scene.menu.isOpen = false
        scene.script(wait: 4, moves: "a", to: 110)
        scene.timer.advance(by: 10)

        #expect(!scene.proxy.hasDisplacedItem)
        #expect(scene.item.lengthWrites == revealCycle + [scene.normal, scene.hiding])
    }

    @Test func timeoutRestoreThatFailsLeavesTheIconForTheNextTry() {
        #expect(clickA() == .clicked)

        scene.timer.advance(by: 10)

        #expect(scene.proxy.hasDisplacedItem)
        #expect(scene.separator.state == .hiding)
    }

    @Test func failedRestoreKeepsTheIconPendingAndStillHidesTheSeparator() {
        #expect(clickA() == .clicked)

        #expect(composition.restoreIfDisplaced() == .failed)
        #expect(scene.proxy.hasDisplacedItem)
        #expect(scene.separator.state == .hiding)
    }
}
