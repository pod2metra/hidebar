import Foundation

/// State behind the settings window: a draft `Layout` the user edits and the `saved` one on disk.
///
/// Edits only change the draft. `apply()` moves the real icons to match it and saves the draft
/// only after every drag is confirmed (rule 1: save after the move is confirmed, never before).
@MainActor
public final class SettingsViewModel {
    public private(set) var draft: Layout
    public private(set) var saved: Layout
    /// Outcome of the last `apply()`: `nil` after a success, cleared by `revert()`.
    public private(set) var failure: ApplyFailure?

    private let store: LayoutStore
    private let executor: MoveExecutor
    private let separator: MenuBarItemID
    private let barItems: @MainActor () -> [MenuBarItem]

    /// - Parameters:
    ///   - layout: the layout loaded from `store`; it is both the draft and the saved state.
    ///   - separator: ID of our separator item, the boundary the bar order is arranged around.
    ///   - barItems: the items on the bar now, left to right; read on every move and every `apply()`.
    public init(
        layout: Layout, store: LayoutStore, executor: MoveExecutor, separator: MenuBarItemID,
        barItems: @escaping @MainActor () -> [MenuBarItem]
    ) {
        draft = layout
        saved = layout
        self.store = store
        self.executor = executor
        self.separator = separator
        self.barItems = barItems
    }

    public var isDirty: Bool { draft != saved }

    /// The draft as lists for the window: `visible`, `hidden`, then the groups in order.
    public var sections: [SettingsSection] {
        [
            SettingsSection(placement: .visible, symbol: nil, items: draft.visible),
            SettingsSection(placement: .hidden, symbol: nil, items: draft.hidden),
        ]
            + draft.groups.map {
                SettingsSection(placement: .group($0.id), symbol: $0.symbol, items: $0.items)
            }
    }

    /// The symbol picker's data: categories in catalog order, each with its symbol names.
    public var symbolCategories: [SymbolCatalog.Category] { SymbolCatalog.categories }

    /// Items left to right as `apply()` arranges the bar: everything hidden or in a group, then
    /// the separator, then the visible items. The separator pushes what is left of it off screen,
    /// and a group's items are hidden too (the group's panel shows them).
    public var desiredBarOrder: [MenuBarItemID] {
        draft.hidden + draft.groups.flatMap(\.items) + [separator] + draft.visible
    }

    /// Throws `LayoutEditError.notHidable` for an item that must stay on the bar and is dropped
    /// into `hidden` or a group.
    public func move(_ item: MenuBarItemID, to placement: Placement, at index: Int) throws {
        draft = try LayoutEditing.move(
            item, in: draft, to: placement, at: index, nonHidable: nonHidable)
    }

    /// `false` for items the window must not let into `hidden` or a group (the drop is disabled).
    /// Items missing from the bar right now count as hidable.
    public func canHide(_ item: MenuBarItemID) -> Bool {
        !nonHidable.contains(item)
    }

    /// Whether the window may accept a drop of `item` into `placement`; `false` disables the drop.
    public func canDrop(_ item: MenuBarItemID, on placement: Placement) -> Bool {
        placement == .visible || canHide(item)
    }

    /// Items on the bar now that must not be dragged (system items). The window lists them, as
    /// they are on the bar, but offers no way to drag them.
    public var fixedItems: Set<MenuBarItemID> {
        Set(barItems().filter { !$0.isMovable }.map(\.id))
    }

    private var nonHidable: Set<MenuBarItemID> {
        Set(barItems().filter { !$0.isHidable }.map(\.id))
    }

    public func reorder(_ item: MenuBarItemID, to index: Int) throws {
        draft = try LayoutEditing.reorder(item, in: draft, to: index)
    }

    /// Adds an empty group labelled with a catalog symbol and returns its ID.
    public func createGroup(symbolName: String) throws -> UUID {
        let id = UUID()
        draft = try LayoutEditing.createGroup(
            in: draft, symbol: GroupSymbol(name: symbolName), id: id)
        return id
    }

    public func setSymbol(ofGroup id: UUID, symbolName: String) throws {
        draft = try LayoutEditing.setSymbol(
            ofGroup: id, in: draft, to: GroupSymbol(name: symbolName))
    }

    public func deleteGroup(_ id: UUID) throws {
        draft = try LayoutEditing.deleteGroup(id, in: draft)
    }

    public func revert() {
        draft = saved
        failure = nil
    }

    /// Moves the bar's icons to match the draft, then saves it. On failure the draft stays and
    /// `failure` says what stopped.
    ///
    /// The store is probed first: a layout of an unreadable version would refuse the save, and
    /// that must be known before any icon is dragged.
    public func apply() {
        failure = attempt()
    }

    private func attempt() -> ApplyFailure? {
        do {
            _ = try store.load()
            return try moveBar()
        } catch {
            return .storeFailure(error)
        }
    }

    private func moveBar() throws -> ApplyFailure? {
        let bar = barItems()
        guard bar.contains(where: { $0.id == separator && $0.isMovable }) else {
            return .separatorUnavailable
        }
        // The separator is the boundary the others are arranged around: it is an anchor and is
        // never dragged, or the icons of this app would end up on the wrong side of it.
        let steps = MovePlanner.plan(current: bar, desired: desiredBarOrder, pinned: separator)
        let result = try executor.execute(steps, confirming: draft) { [self] confirmed in
            try store.save(confirmed)
            saved = confirmed
        }
        guard case .stopped(let index, let outcome) = result else { return nil }
        return .moveStopped(stepIndex: index, item: steps[index].item.id, outcome: outcome)
    }
}
