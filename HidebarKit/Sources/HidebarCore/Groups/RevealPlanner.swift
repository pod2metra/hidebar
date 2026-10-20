/// Chooses the drag that brings a clicked icon within reach.
enum RevealPlanner {
    /// An icon goes right beside the separator on its `side`. The first icon on that side is
    /// there already, and dropping it there moves nothing, which would read as a failed drag: it
    /// hops over the next movable icon instead, or, with none to hop over, is not dragged at all.
    static func step(
        for found: DiscoveredItem, among items: [DiscoveredItem], separator: MenuBarItemID,
        side: DropSide
    ) -> MoveStep? {
        let beside = MoveStep(item: found.item, anchor: separator, side: side)
        guard let boundary = items.first(where: { $0.item.id == separator }),
            isFirst(found, after: boundary, among: items, side: side)
        else { return beside }
        return hopTarget(after: found, among: items, side: side)
            .map { MoveStep(item: found.item, anchor: $0.item.id, side: side) }
    }

    /// `found` lies on `side` of the separator with no other icon between them.
    private static func isFirst(
        _ found: DiscoveredItem, after boundary: DiscoveredItem, among items: [DiscoveredItem],
        side: DropSide
    ) -> Bool {
        let edge = boundary.item.frame.x
        let x = found.item.frame.x
        let between = items.contains { isBetween($0.item.frame.x, edge, x, side: side) }
        return isFarther(x, than: edge, side: side) && !between
    }

    /// `at` lies strictly between `edge` and `x`, counting from `edge` towards `side`.
    private static func isBetween(_ at: Double, _ edge: Double, _ x: Double, side: DropSide) -> Bool {
        isFarther(at, than: edge, side: side) && isFarther(x, than: at, side: side)
    }

    private static func hopTarget(
        after found: DiscoveredItem, among items: [DiscoveredItem], side: DropSide
    ) -> DiscoveredItem? {
        let x = found.item.frame.x
        return items
            .filter { $0.isManaged && $0.item.isMovable && isFarther($0.item.frame.x, than: x, side: side) }
            .min { abs($0.item.frame.x - x) < abs($1.item.frame.x - x) }
    }

    private static func isFarther(_ a: Double, than b: Double, side: DropSide) -> Bool {
        switch side {
        case .rightOf: a > b
        case .leftOf: a < b
        }
    }
}
