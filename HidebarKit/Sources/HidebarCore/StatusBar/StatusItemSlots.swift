/// Where the app's status items sit on the bar, as the `NSStatusItem Preferred Position <name>`
/// numbers the system reads when it creates an item. A smaller number is nearer the right edge.
///
/// Unverified assumption: that direction (and that only the order of the numbers matters, not
/// their size) is taken from how Ice seeds its control items and has not been checked against
/// the system here. If it is the other way round, the toggle and the group icons land left of the
/// separator and are hidden with it; the manual checklist must confirm the order on a real bar.
///
/// The toggle is rightmost, then the group icons, then the separator: everything left of the
/// separator is hidden, so a group icon must never be created to its left. Items that already
/// have a position keep it (the user may have dragged them); only missing ones are seeded.
public enum StatusItemSlots {
    public static let toggle = 0.0
    public static let separator = 1.0

    /// The position to write for an item with a fixed slot; `nil` when it already has one.
    public static func fixedSeed(stored: Double?, slot: Double) -> Double? {
        guard stored == nil else { return nil }
        return slot
    }

    /// The position to write for a group icon; `nil` when it already has one. It lands halfway
    /// between the separator and the nearest position right of it in `taken` (the toggle and the
    /// other group icons), or the right edge when there is none.
    public static func groupSeed(stored: Double?, separator: Double, taken: [Double]) -> Double? {
        guard stored == nil else { return nil }
        return (nearest(below: separator, in: taken) + separator) / 2
    }

    private static func nearest(below limit: Double, in positions: [Double]) -> Double {
        var nearest = 0.0
        for position in positions where position < limit {
            nearest = max(nearest, position)
        }
        return nearest
    }
}
