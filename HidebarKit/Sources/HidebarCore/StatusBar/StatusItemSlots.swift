/// Where the app's status items sit on the bar, as the `NSStatusItem Preferred Position <name>`
/// numbers the system reads when it creates an item. A smaller number is nearer the right edge.
///
/// The arrow is rightmost, then the separator's pipe: everything left of the pipe is hidden when it
/// stretches, so the arrow must never be created to its left. An item that already has a position
/// keeps it (the user may have dragged it); only a missing one is seeded.
public enum StatusItemSlots {
    public static let toggle = 0.0
    public static let separator = 1.0

    /// The position to write for an item with a fixed slot; `nil` when it already has one.
    public static func fixedSeed(stored: Double?, slot: Double) -> Double? {
        guard stored == nil else { return nil }
        return slot
    }
}
