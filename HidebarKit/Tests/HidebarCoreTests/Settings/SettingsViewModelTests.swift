import Foundation
import Testing

@testable import HidebarCore

@MainActor @Suite struct SettingsViewModelTests {
    private let groupID = UUID()
    private let backing = InMemoryStore()
    private let bar = MoveFakeBar()
    private let separator = moveID("sep")

    /// visible a b, hidden c, group [d]; on the bar they sit a b | sep | c d, so the draft
    /// c d | sep | a b needs real drags.
    private func layout() throws -> Layout {
        try Layout(
            visible: [moveID("a"), moveID("b")], hidden: [moveID("c")],
            groups: [try makeGroup(groupID, symbol: "star", items: [moveID("d")])])
    }

    private func barItems(separatorMovable: Bool = true) -> [MenuBarItem] {
        [
            moveItem("a"), moveItem("b"), moveItem("sep", movable: separatorMovable),
            moveItem("c"), moveItem("d"),
        ]
    }

    private func makeModel(
        items: [MenuBarItem]? = nil, store: InMemoryStore? = nil
    ) throws -> SettingsViewModel {
        let current = items ?? barItems()
        for (index, item) in current.enumerated() {
            bar.frames[item.id] = ItemFrame(x: Double(index * 20), y: 0, width: 10, height: 20)
        }
        return SettingsViewModel(
            layout: try layout(), store: LayoutStore(store: store ?? backing),
            executor: MoveExecutor(
                poster: bar, locator: bar, windows: bar, clock: bar, inputGate: InputGate()),
            separator: separator,
            barItems: { current })
    }

    /// Every drag lands where it was released, so each is confirmed on its first poll.
    private func confirmEveryDrag() {
        bar.dragsLand = true
    }

    private func storedLayout() throws -> Layout? {
        let result = try LayoutStore(store: backing).load()
        return result.status == .missing ? nil : result.layout
    }

    @Test func fixedItemsAreTheOnesTheBarCannotMove() throws {
        let items = [moveItem("a"), moveItem("clock", movable: false), moveItem("b")]
        let model = try makeModel(items: items)
        #expect(model.fixedItems == [moveID("clock")])
        #expect(try makeModel(items: [moveItem("a")]).fixedItems.isEmpty)
    }

    // MARK: state

    @Test func startsCleanWithDraftEqualToSaved() throws {
        let model = try makeModel()
        #expect(model.draft == model.saved)
        #expect(model.draft == (try layout()))
        #expect(!model.isDirty)
        #expect(model.failure == nil)
    }

    @Test func sectionsListVisibleThenHiddenThenGroups() throws {
        let model = try makeModel()
        #expect(
            model.sections == [
                SettingsSection(placement: .visible, symbol: nil, items: [moveID("a"), moveID("b")]),
                SettingsSection(placement: .hidden, symbol: nil, items: [moveID("c")]),
                SettingsSection(
                    placement: .group(groupID), symbol: try GroupSymbol(name: "star"),
                    items: [moveID("d")]),
            ])
    }

    @Test func symbolCategoriesAreTheCatalogs() throws {
        #expect(try makeModel().symbolCategories == SymbolCatalog.categories)
    }

    @Test func desiredBarOrderPutsHiddenThenGroupItemsLeftOfTheSeparatorAndVisibleRight() throws {
        let model = try makeModel()
        #expect(
            model.desiredBarOrder == [moveID("c"), moveID("d"), separator, moveID("a"), moveID("b")])
    }

    // MARK: editing

    @Test func editsChangeOnlyTheDraftAndMarkItDirty() throws {
        let model = try makeModel()
        let original = model.saved
        try model.move(moveID("a"), to: .hidden, at: 0)
        #expect(model.draft.hidden == [moveID("a"), moveID("c")])
        #expect(model.isDirty)
        #expect(model.saved == original)
        try model.reorder(moveID("b"), to: 0)
        #expect(model.draft.visible == [moveID("b")])
    }

    @Test func anItemThatMustStayOnTheBarCannotBeHiddenOrGrouped() throws {
        let pinned = MenuBarItem(
            id: moveID("a"), frame: ItemFrame(x: 0, y: 0, width: 10, height: 20), isMovable: true,
            isHidable: false)
        let model = try makeModel(items: [pinned] + barItems().dropFirst())
        #expect(!model.canHide(moveID("a")))
        #expect(model.canHide(moveID("b")))
        #expect(model.canHide(moveID("not-on-the-bar")))
        #expect(model.canDrop(moveID("a"), on: .visible))
        #expect(!model.canDrop(moveID("a"), on: .hidden))
        #expect(!model.canDrop(moveID("a"), on: .group(groupID)))
        #expect(model.canDrop(moveID("b"), on: .hidden))
        #expect(model.canDrop(moveID("b"), on: .group(groupID)))
        #expect(throws: LayoutEditError.notHidable(moveID("a"))) {
            try model.move(moveID("a"), to: .hidden, at: 0)
        }
        #expect(throws: LayoutEditError.notHidable(moveID("a"))) {
            try model.move(moveID("a"), to: .group(groupID), at: 0)
        }
        #expect(model.draft == model.saved)
        try model.move(moveID("a"), to: .visible, at: 1)
        #expect(model.draft.visible == [moveID("b"), moveID("a")])
        try model.move(moveID("b"), to: .hidden, at: 0)
        #expect(model.draft.hidden == [moveID("b"), moveID("c")])
    }

    @Test func createGroupReturnsTheNewIDAndAppendsAnEmptyGroup() throws {
        let model = try makeModel()
        let id = try model.createGroup(symbolName: "bolt")
        #expect(
            model.draft.groups.last
                == ItemGroup(id: id, symbol: try GroupSymbol(name: "bolt"), items: []))
        #expect(model.isDirty)
        #expect(try model.createGroup(symbolName: "bolt") != id)
    }

    @Test func setSymbolRelabelsTheGroup() throws {
        let model = try makeModel()
        try model.setSymbol(ofGroup: groupID, symbolName: "heart")
        #expect(model.draft.groups[0].symbol.name == "heart")
        #expect(model.draft.groups[0].items == [moveID("d")])
    }

    @Test func deleteGroupReturnsItsItemsToTheEndOfHidden() throws {
        let model = try makeModel()
        try model.deleteGroup(groupID)
        #expect(model.draft.groups.isEmpty)
        #expect(model.draft.hidden == [moveID("c"), moveID("d")])
    }

    @Test func aFailedEditLeavesTheDraftAsItWas() throws {
        let model = try makeModel()
        let missing = UUID()
        #expect(throws: GroupSymbolError.unknownSymbol("nope")) {
            try model.createGroup(symbolName: "nope")
        }
        #expect(throws: GroupSymbolError.unknownSymbol("nope")) {
            try model.setSymbol(ofGroup: groupID, symbolName: "nope")
        }
        #expect(throws: LayoutEditError.unknownGroup(missing)) {
            try model.deleteGroup(missing)
        }
        #expect(throws: LayoutEditError.indexOutOfRange(9)) {
            try model.move(moveID("a"), to: .hidden, at: 9)
        }
        #expect(throws: LayoutEditError.unknownItem(moveID("zzz"))) {
            try model.reorder(moveID("zzz"), to: 0)
        }
        #expect(model.draft == model.saved)
    }

    @Test func revertRestoresTheSavedLayoutAndClearsTheFailure() throws {
        let model = try makeModel()
        try model.deleteGroup(groupID)
        model.apply()
        #expect(model.failure != nil)
        model.revert()
        #expect(model.draft == (try layout()))
        #expect(!model.isDirty)
        #expect(model.failure == nil)
    }

    // MARK: apply

    @Test func applyDragsTheIconsThenSavesTheDraftAndBecomesClean() throws {
        let model = try makeModel()
        confirmEveryDrag()
        try model.move(moveID("a"), to: .hidden, at: 0)
        let steps = MovePlanner.plan(
            current: barItems(), desired: model.desiredBarOrder, pinned: separator)
        model.apply()
        #expect(!steps.isEmpty)
        #expect(!steps.map(\.item.id).contains(separator))
        #expect(bar.downs.count == steps.count)
        #expect(model.failure == nil)
        #expect(!model.isDirty)
        #expect(model.saved == model.draft)
        #expect(try storedLayout() == model.draft)
    }

    @Test func applyWithNothingToDragStillSavesTheDraft() throws {
        let inOrder = [
            moveItem("c"), moveItem("d"), moveItem("sep"), moveItem("a"), moveItem("b"),
        ]
        let model = try makeModel(items: inOrder)
        try model.setSymbol(ofGroup: groupID, symbolName: "heart")
        model.apply()
        #expect(bar.log.isEmpty)
        #expect(model.failure == nil)
        #expect(try storedLayout() == model.draft)
        #expect(!model.isDirty)
    }

    @Test func aStuckDragReportsTheStepKeepsTheDraftAndSavesNothing() throws {
        let model = try makeModel()
        try model.deleteGroup(groupID)
        let edited = model.draft
        let plan = MovePlanner.plan(current: barItems(), desired: model.desiredBarOrder)
        model.apply()
        #expect(model.failure == .moveStopped(stepIndex: 0, item: plan[0].item.id, outcome: .failed))
        #expect(bar.downs.count == MoveExecutor.maxRetries + 1)
        #expect(model.draft == edited)
        #expect(model.isDirty)
        #expect(model.saved == (try layout()))
        #expect(try storedLayout() == nil)
    }

    @Test func aLaterStuckStepIsReportedByItsIndex() throws {
        let model = try makeModel()
        try model.deleteGroup(groupID)
        let plan = MovePlanner.plan(current: barItems(), desired: model.desiredBarOrder)
        #expect(plan.count >= 2)
        // The first drag succeeds, every later one leaves its item in place.
        let first = plan[0].item.id
        bar.onWait = { [bar] _ in
            guard let frame = bar.frames[first], frame.x < 1000 else { return }
            bar.frames[first] = ItemFrame(
                x: frame.x + 1000, y: frame.y, width: frame.width, height: frame.height)
        }
        model.apply()
        #expect(model.failure == .moveStopped(stepIndex: 1, item: plan[1].item.id, outcome: .failed))
        #expect(try storedLayout() == nil)
        #expect(model.isDirty)
    }

    @Test func aSuccessfulApplyClearsAnEarlierFailure() throws {
        let model = try makeModel()
        model.apply()
        #expect(model.failure != nil)
        confirmEveryDrag()
        model.apply()
        #expect(model.failure == nil)
    }

    @Test func missingOrUndraggableSeparatorStopsBeforeAnyDrag() throws {
        let withoutSeparator = try makeModel(items: barItems().filter { $0.id != separator })
        withoutSeparator.apply()
        #expect(withoutSeparator.failure == .separatorUnavailable)
        let frozen = try makeModel(items: barItems(separatorMovable: false))
        frozen.apply()
        #expect(frozen.failure == .separatorUnavailable)
        #expect(bar.log.isEmpty)
        #expect(try storedLayout() == nil)
    }

    @Test func aNewerStoredVersionStopsApplyBeforeAnyDragAndIsLeftUntouched() throws {
        let newer = Data(#"{"version":99}"#.utf8)
        let newerStore = InMemoryStore([LayoutStore.defaultKey: newer])
        let model = try makeModel(store: newerStore)
        try model.deleteGroup(groupID)
        model.apply()
        #expect(model.failure == .storeRefused(.unsupportedVersion(99)))
        #expect(bar.log.isEmpty)
        #expect(model.isDirty)
        #expect(newerStore.data(forKey: LayoutStore.defaultKey) == newer)
    }

    @Test func aStoreThatFailsToWriteReportsItAndKeepsTheDraft() throws {
        let model = try makeModel(store: InMemoryStore(failingKeys: [LayoutStore.defaultKey]))
        confirmEveryDrag()
        try model.deleteGroup(groupID)
        model.apply()
        #expect(model.failure == .storeFailed(String(describing: InMemoryStore.WriteFailure())))
        #expect(!bar.downs.isEmpty)
        #expect(model.isDirty)
        #expect(model.saved == (try layout()))
    }

    @Test func storeFailureMapsRefusalsAndOtherErrors() {
        #expect(
            ApplyFailure.storeFailure(LayoutStoreError.refusingToOverwriteNewerVersion(7))
                == .storeRefused(.refusingToOverwriteNewerVersion(7)))
        #expect(
            ApplyFailure.storeFailure(InMemoryStore.WriteFailure())
                == .storeFailed(String(describing: InMemoryStore.WriteFailure())))
    }
}
