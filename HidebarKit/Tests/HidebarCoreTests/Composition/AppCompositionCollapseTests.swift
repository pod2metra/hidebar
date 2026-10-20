import Foundation
import Testing

@testable import HidebarCore

/// Collapse and expand are the user's wish; the pipe follows it, and every reveal in between (a
/// click on a hidden icon) ends by putting the pipe back the way that wish says.
@MainActor @Suite struct AppCompositionCollapseTests {
    private let scene = CompositionScene()

    private var composition: AppComposition { scene.composition }

    // MARK: collapse and expand

    @Test func theAppStartsExpanded() {
        #expect(!composition.isCollapsed)
        #expect(scene.item.lengthWrites.isEmpty)
    }

    @Test func collapsingHidesTheIconsAndRemembersTheWish() {
        #expect(composition.collapse(pipeX: 100, arrowX: 200) == nil)

        #expect(composition.isCollapsed)
        #expect(scene.separator.state == .hiding)
        #expect(scene.item.lengthWrites == [scene.hiding])
    }

    @Test func collapsingTwiceHidesOnce() {
        scene.collapse()
        scene.collapse()

        #expect(scene.item.lengthWrites == [scene.hiding])
    }

    @Test func expandingShowsTheIconsAndForgetsTheWish() {
        scene.collapse()

        composition.expand()

        #expect(!composition.isCollapsed)
        #expect(scene.separator.state == .shown)
        #expect(scene.item.lengthWrites == [scene.hiding, scene.normal])
    }

    @Test func expandingWhileExpandedWritesNothing() {
        composition.expand()

        #expect(scene.item.lengthWrites.isEmpty)
    }

    // MARK: the guard

    @Test(
        arguments: [
            (nil, 200, CollapseRefusal.separatorNotOnBar),
            (100, nil, .separatorNotOnBar),
            (100, 99, .arrowWouldHide),
        ] as [(Double?, Double?, CollapseRefusal)])
    func aRefusedCollapseWritesNothingAndKeepsTheIconsShown(
        pipeX: Double?, arrowX: Double?, refusal: CollapseRefusal
    ) {
        #expect(composition.collapse(pipeX: pipeX, arrowX: arrowX) == refusal)

        #expect(!composition.isCollapsed)
        #expect(scene.separator.state == .shown)
        #expect(scene.item.lengthWrites.isEmpty)
    }

    @Test func aRefusedCollapseWhileCollapsedLeavesTheIconsHidden() {
        scene.collapse()

        #expect(composition.collapse(pipeX: 100, arrowX: 99) == .arrowWouldHide)
        #expect(composition.isCollapsed)
        #expect(scene.item.lengthWrites == [scene.hiding])
    }

    // MARK: reveals follow the wish

    @Test func aClickWhileCollapsedEndsHiding() {
        scene.collapse()
        scene.script(wait: 2, moves: "a", to: 22)

        #expect(composition.click(moveID("a")) == .clicked)

        #expect(scene.separator.state == .hiding)
        #expect(scene.item.lengthWrites == [scene.hiding, scene.normal, scene.hiding])
    }

    @Test func aClickWhileExpandedLeavesTheSeparatorAlone() {
        scene.script(wait: 1, moves: "a", to: 22)

        #expect(composition.click(moveID("a")) == .clicked)

        #expect(scene.separator.state == .shown)
        #expect(scene.item.lengthWrites.isEmpty)
    }

    @Test func anIconBroughtHomeAfterExpandingLeavesTheBarShown() {
        scene.collapse()
        scene.script(wait: 2, moves: "a", to: 22)
        #expect(composition.click(moveID("a")) == .clicked)
        composition.expand()
        scene.script(wait: 3, moves: "a", to: 110)

        #expect(composition.restoreIfDisplaced() == .restored)

        #expect(scene.separator.state == .shown)
        #expect(scene.item.lengthWrites == [scene.hiding, scene.normal, scene.hiding, scene.normal])
    }
}
