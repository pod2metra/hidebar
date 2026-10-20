import Foundation
import Testing

@testable import HidebarCore

@MainActor @Suite struct AppCompositionTests {
    private let scene = CompositionScene()

    private var composition: AppComposition { scene.composition }

    @Test func shownSeparatorIsLeftAloneAndTheBodyRuns() {
        #expect(composition.withRevealed { 42 } == 42)
        #expect(scene.item.lengthWrites.isEmpty)
        #expect(scene.bar.log.isEmpty)
    }

    @Test func hidingSeparatorIsShownSettledThenHiddenAgain() {
        scene.collapse()
        var stateInside: SeparatorState?
        var waitsInside = 0
        let result = composition.withRevealed {
            stateInside = scene.separator.state
            waitsInside = scene.bar.waits
            return "done"
        }
        #expect(result == "done")
        #expect(stateInside == .shown)
        #expect(waitsInside == 1)
        #expect(scene.bar.log == [.wait(AppComposition.settlePollMilliseconds)])
        #expect(scene.item.lengthWrites == [scene.hiding, scene.normal, scene.hiding])
        #expect(scene.separator.state == .hiding)
    }
}
