import Foundation
import Testing

@testable import HidebarCore

func ownDiscovered(_ title: String, x: Double = 0, windowID: Int = 90) -> DiscoveredItem {
    DiscoveredItem(
        windowID: windowID, ownerPID: 688,
        item: MenuBarItem(
            id: MenuBarItemID(ownerBundleID: OwnItems.bundleID, title: title),
            frame: ItemFrame(x: x, y: 0, width: 10, height: 20), isMovable: true, isHidable: true),
        isManaged: true)
}

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
