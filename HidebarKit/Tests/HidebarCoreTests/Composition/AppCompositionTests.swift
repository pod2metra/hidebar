import Foundation
import Testing

@testable import HidebarCore

func ownDiscovered(_ title: String, x: Double = 0, windowID: Int = 90) -> DiscoveredItem {
    DiscoveredItem(
        windowID: windowID,
        item: MenuBarItem(
            id: MenuBarItemID(ownerBundleID: OwnItems.bundleID, title: title),
            frame: ItemFrame(x: x, y: 0, width: 10, height: 20), isMovable: true, isHidable: true),
        isManaged: true)
}

@MainActor @Suite struct AppCompositionTests {
    private let scene = CompositionScene()

    private var composition: AppComposition { scene.composition }

    // MARK: withRevealed

    @Test func shownSeparatorIsLeftAloneAndTheBodyRuns() {
        #expect(composition.withRevealed { 42 } == 42)
        #expect(scene.item.lengthWrites.isEmpty)
        #expect(scene.bar.log.isEmpty)
    }

    @Test func hidingSeparatorIsShownSettledThenHiddenAgain() {
        scene.separator.hide()
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
        #expect(scene.bar.log == [.wait(AppComposition.settleMilliseconds)])
        #expect(scene.item.lengthWrites == [scene.hiding, scene.normal, scene.hiding])
        #expect(scene.separator.state == .hiding)
    }

    @Test func settleTimeIsLongEnoughToMeasure() {
        #expect(AppComposition.settleMilliseconds > 0)
    }

    // MARK: discovery

    @Test func discoverRevealedReturnsEveryItemIncludingOwnOnesAfterRevealing() {
        scene.separator.hide()
        scene.found = [discovered("a"), ownDiscovered("toggle")]
        #expect(composition.discoverRevealed() == scene.found)
        #expect(scene.lengthAtDiscovery == [scene.normal])
        #expect(scene.separator.state == .hiding)
    }

    @Test func barItemsKeepOnlyOtherAppsItemsAndTheSeparator() {
        scene.separator.hide()
        scene.found = [
            discovered("a"), ownDiscovered("Hidebar group"), ownDiscovered(OwnItems.separatorTitle),
            discovered("b", managed: false), ownDiscovered("toggle"),
        ]
        #expect(
            composition.barItems().map(\.id) == [
                moveID("a"), OwnItems.separatorID, moveID("b"),
            ])
        // Reading the bar for a plan must not itself move the separator.
        #expect(scene.item.lengthWrites == [scene.hiding])
    }

    // MARK: startup layout

    @Test func missingLayoutStartsWithTheManagedIconsOnTheBarAndNoNotice() throws {
        scene.found = [
            discovered("a"), ownDiscovered("toggle"), discovered("u", managed: false), discovered("b"),
        ]
        let start = try composition.startupLayout(from: LayoutStore(store: scene.backing))
        #expect(start.layout == (try Layout(visible: [moveID("a"), moveID("b")], hidden: [], groups: [])))
        #expect(start.notice == nil)
    }

    @Test func storedPlacesAreKeptAndNewIconsAreAppendedToVisible() throws {
        let store = LayoutStore(store: scene.backing)
        let group = try makeGroup(UUID(), symbol: "star", items: [moveID("c")])
        try store.save(Layout(visible: [moveID("a")], hidden: [moveID("b")], groups: [group]))
        scene.found = [discovered("c"), discovered("new"), discovered("a")]
        let start = try composition.startupLayout(from: store)
        #expect(
            start.layout
                == (try Layout(
                    visible: [moveID("a"), moveID("new")], hidden: [moveID("b")], groups: [group])))
        #expect(start.notice == nil)
    }

    @Test func hiddenIconsAreFoundBecauseTheSeparatorIsRevealedForTheScan() throws {
        scene.separator.hide()
        _ = try composition.startupLayout(from: LayoutStore(store: scene.backing))
        #expect(scene.lengthAtDiscovery == [scene.normal])
        #expect(scene.separator.state == .hiding)
    }

    @Test func layoutOfAnotherVersionStartsEmptyWithAMessageAndIsNeverScanned() throws {
        let backing = InMemoryStore([LayoutStore.defaultKey: Data(#"{"version": 99}"#.utf8)])
        let start = try composition.startupLayout(from: LayoutStore(store: backing))
        #expect(start.layout == .empty)
        #expect(start.notice?.contains("different version") == true)
        #expect(scene.lengthAtDiscovery.isEmpty)
    }

    @Test func unreadableLayoutStartsFromTheBarWithAMessage() throws {
        let backing = InMemoryStore([LayoutStore.defaultKey: Data("not json".utf8)])
        scene.found = [discovered("a")]
        let start = try composition.startupLayout(from: LayoutStore(store: backing))
        #expect(start.layout == (try Layout(visible: [moveID("a")], hidden: [], groups: [])))
        #expect(start.notice?.contains("could not be read") == true)
    }

    // MARK: apply

    private func settings(
        layout: Layout, separatorOnBar: Bool = true
    ) -> SettingsViewModel {
        let ids = [moveID("a"), OwnItems.separatorID, moveID("b")]
        for (index, id) in ids.enumerated() {
            scene.bar.frames[id] = ItemFrame(x: Double(index) * 20, y: 0, width: 10, height: 20)
        }
        scene.found = [
            discovered("a"), separatorOnBar ? ownDiscovered(OwnItems.separatorTitle) : ownDiscovered("toggle"),
            discovered("b"),
        ]
        return SettingsViewModel(
            layout: layout, store: LayoutStore(store: scene.backing),
            executor: MoveExecutor(
                poster: scene.bar, locator: scene.bar, clock: scene.bar, inputGate: scene.gate),
            separator: OwnItems.separatorID, barItems: { [composition] in composition.barItems() })
    }

    @Test func applyMovesIconsWithTheSeparatorRevealedThenHidesItAgain() throws {
        let model = settings(
            layout: try Layout(visible: [moveID("a")], hidden: [moveID("b")], groups: []))
        scene.confirmEveryDrag()
        scene.separator.hide()

        #expect(composition.apply(model) == nil)

        #expect(model.failure == nil)
        #expect(model.saved == model.draft)
        #expect(try LayoutStore(store: scene.backing).load().layout == model.saved)
        // Both icons were out of order, so two drags; each polls once, after the settle pause.
        #expect(scene.bar.downs.count == 2)
        #expect(scene.lengthAtWaits.count == 3)
        #expect(scene.lengthAtWaits.allSatisfy { $0 == scene.normal })
        #expect(scene.item.lengthWrites == [scene.hiding, scene.normal, scene.hiding])
    }

    @Test func applyThatCannotArrangeTheBarStillPutsTheSeparatorBack() throws {
        let model = settings(
            layout: try Layout(visible: [moveID("a")], hidden: [moveID("b")], groups: []),
            separatorOnBar: false)
        scene.separator.hide()

        #expect(composition.apply(model) == nil)

        #expect(model.failure == .separatorUnavailable)
        #expect(scene.separator.state == .hiding)
        #expect(scene.item.length == scene.hiding)
    }
}
