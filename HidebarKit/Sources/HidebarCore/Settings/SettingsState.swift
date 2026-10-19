/// One list of the draft layout as the settings window shows it.
public struct SettingsSection: Equatable, Sendable {
    public let placement: Placement
    /// The label of a group section; `nil` for `visible` and `hidden`.
    public let symbol: GroupSymbol?
    public let items: [MenuBarItemID]
}

/// Why the last `SettingsViewModel.apply()` did not finish. The draft is kept in every case.
public enum ApplyFailure: Equatable, Sendable {
    /// Our separator is not on the bar (or cannot be dragged), so there is no boundary to
    /// arrange items around. Nothing was moved.
    case separatorUnavailable
    /// Step `stepIndex` of the plan, dragging `item`, ended with `outcome`. Earlier steps did
    /// move their items; nothing was saved.
    case moveStopped(stepIndex: Int, item: MenuBarItemID, outcome: MoveOutcome)
    /// The store holds a layout of a version this build cannot read and refuses to replace it.
    /// Nothing was moved or saved.
    case storeRefused(LayoutStoreError)
    /// The store failed for another reason. If this happened on save, the items did move but the
    /// layout was not saved.
    case storeFailed(String)

    static func storeFailure(_ error: any Error) -> ApplyFailure {
        guard let refusal = error as? LayoutStoreError else {
            return .storeFailed(String(describing: error))
        }
        return .storeRefused(refusal)
    }
}
