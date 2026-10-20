/// Delivery of events that only make sense together, such as the two halves of a click.
public enum AllOrNothing {
    /// Hands every part to `deliver`, in order, only when none of them is `nil`; otherwise hands
    /// over nothing, so a click can never be left half posted.
    /// - Returns: whether the parts were delivered.
    public static func deliver<Part>(_ parts: [Part?], using deliver: (Part) -> Void) -> Bool {
        let complete = parts.compactMap { $0 }
        guard complete.count == parts.count else { return false }
        complete.forEach(deliver)
        return true
    }
}
