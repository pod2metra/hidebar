/// One window as reported by the window server. Plain values, so the core needs no CoreGraphics.
public struct WindowInfo: Equatable, Sendable {
    public let windowID: Int
    public let layer: Int
    public let frame: ItemFrame
    public let isOnscreen: Bool
    /// Bundle identifier of the window's owning process; `nil` when it has none. On macOS 26 this
    /// is Control Center for every status item, so it does not identify the real owner.
    public let ownerBundleID: String?
    /// Empty when the window has no name, which is always the case without Screen Recording.
    public let title: String

    public init(
        windowID: Int, layer: Int, frame: ItemFrame, isOnscreen: Bool,
        ownerBundleID: String?, title: String
    ) {
        self.windowID = windowID
        self.layer = layer
        self.frame = frame
        self.isOnscreen = isOnscreen
        self.ownerBundleID = ownerBundleID
        self.title = title
    }
}

/// Source of the current window list; the adapter wraps `CGWindowListCopyWindowInfo`.
public protocol WindowListProvider: Sendable {
    func windows() -> [WindowInfo]
}

/// The real owner and title of a status item, as read from Accessibility.
public struct ItemOwner: Equatable, Sendable {
    public let bundleID: String
    public let title: String

    public init(bundleID: String, title: String) {
        self.bundleID = bundleID
        self.title = title
    }
}

/// Accessibility lookup of a status item's real owner (`AXExtrasMenuBar`).
public protocol ItemOwnerResolving: Sendable {
    /// `nil` when the owner cannot be determined, notably when Accessibility is not granted.
    func owner(ofWindow windowID: Int) -> ItemOwner?
}
