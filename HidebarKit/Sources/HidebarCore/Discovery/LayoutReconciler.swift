/// Brings a stored `Layout` up to date with the items found on the bar.
public enum LayoutReconciler {
    /// `stored` with every managed item it does not know yet appended to `visible`, in bar order.
    ///
    /// Nothing is ever removed: an ID missing from `discovered` (app quit, item hidden behind
    /// the separator) keeps its place, so the user's arrangement survives an app that is not
    /// running right now. Unmanaged items are never added. The result goes through `Layout`'s
    /// validating initializer.
    public static func reconcile(discovered: [DiscoveredItem], stored: Layout) throws -> Layout {
        var known = Set(stored.visible + stored.hidden + stored.groups.flatMap(\.items))
        let added = discovered.filter(\.isManaged).map(\.item.id)
            .filter { known.insert($0).inserted }
        return try Layout(
            visible: stored.visible + added, hidden: stored.hidden, groups: stored.groups)
    }
}
