/// Where an item's window is right now, so a drag can name it.
@MainActor
public protocol WindowLocating {
    /// `nil` when the item has no window on the bar or its identity is not reliable.
    func window(of id: MenuBarItemID) -> WindowTarget?
}

/// Finds an item's window by running discovery. Only a managed item has an identity that can be
/// trusted, so only a managed item is found.
///
/// While the bar re-lays out after a drag, Accessibility and the window list briefly disagree and
/// discovery loses items it had a moment before. A window keeps its number for as long as it
/// exists, so an item discovery loses is looked up in the window list by the number it had when it
/// was last found, and only a window that is gone counts as missing. Every lookup remembers all
/// the managed items it sees, so the numbers are known from the first drag of a plan on. If
/// discovery sees several unmanaged items under one id, the id names no single window and the
/// remembered number is not trusted.
@MainActor
public final class DiscoveryWindowLocator: WindowLocating {
    private let discover: @MainActor () -> [DiscoveredItem]
    private let windowList: any WindowListProvider
    private var known: [MenuBarItemID: Int] = [:]

    public init(
        discover: @escaping @MainActor () -> [DiscoveredItem], windowList: any WindowListProvider
    ) {
        self.discover = discover
        self.windowList = windowList
    }

    public func window(of id: MenuBarItemID) -> WindowTarget? {
        let found = discover()
        let managed = Dictionary(
            found.filter(\.isManaged).map { ($0.item.id, $0) }, uniquingKeysWith: { first, _ in first })
        managed.forEach { known[$0.key] = $0.value.windowID }
        if let current = managed[id] { return current.window }
        let sharing = Dictionary(grouping: found, by: \.item.id)[id]?.count ?? 0
        return sharing > 1 ? nil : remembered(id)
    }

    private func remembered(_ id: MenuBarItemID) -> WindowTarget? {
        let number = known[id]
        return windowList.windows().first { $0.windowID == number }.map {
            WindowTarget(windowID: $0.windowID, ownerPID: $0.ownerPID, frame: $0.frame)
        }
    }
}
