extension Collection {
    /// The only element, or `nil` when there are none or several: an ambiguous match is no match.
    var sole: Element? {
        guard count == 1 else { return nil }
        return first
    }
}
