/// Tells whether a menu is open on screen, from the window list: an open menu is a window on the
/// pop-up menu layer. It cannot say whose menu it is, which is enough to avoid dragging an icon
/// away while the user is still using a menu.
public struct OpenMenuProbe: Sendable {
    /// Window layer of an open menu (`NSPopUpMenuWindowLevel`).
    public static let menuLayer = 101

    private let windowList: any WindowListProvider

    public init(windowList: any WindowListProvider) {
        self.windowList = windowList
    }

    public func isMenuOpen() -> Bool {
        windowList.windows().contains { $0.layer == Self.menuLayer && $0.isOnscreen }
    }
}
