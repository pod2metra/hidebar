/// Why the separator cannot be collapsed.
public enum CollapseRefusal: Equatable, Sendable {
    /// The pipe or the arrow has no frame on the bar, so nothing can be told about the order.
    case separatorNotOnBar
    /// The arrow is left of the pipe: it would be pushed off the bar with the hidden icons, and the
    /// icons could not be shown again.
    case arrowWouldHide
}

/// Checks the order of the pipe and the arrow before the pipe is stretched.
public enum CollapseGuard {
    /// `pipeX` and `arrowX` are the items' left edges in one coordinate space (AppKit frames, which
    /// stay readable while the pipe pushes items off the screen); `nil` when an item has no frame
    /// on the bar, and that is refused: an unknown order cannot be told from a stranded arrow.
    /// Everything with `x` less than the pipe's goes off the bar. Returns `nil` when the order
    /// allows collapsing.
    public static func check(pipeX: Double?, arrowX: Double?) -> CollapseRefusal? {
        guard let pipeX, let arrowX else { return .separatorNotOnBar }
        if arrowX < pipeX { return .arrowWouldHide }
        return nil
    }
}
