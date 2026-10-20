/// A status item found on the bar, tied to the window it was read from.
public struct DiscoveredItem: Equatable, Sendable {
    public let windowID: Int
    public let item: MenuBarItem
    /// `false` when `item.id` cannot be trusted as an identity: the real owner is unknown or
    /// another item shares the ID. Such an item stays visible, is never moved and is never saved.
    public let isManaged: Bool

    public init(windowID: Int, item: MenuBarItem, isManaged: Bool) {
        self.windowID = windowID
        self.item = item
        self.isManaged = isManaged
    }
}

/// Turns the window list into the status items on the bar, left to right.
public struct ItemDiscovery: Sendable {
    /// Status item windows sit on layer 25; the `Menubar` window itself is on layer 24.
    public static let statusItemLayer = 25
    public static let controlCenterBundleID = "com.apple.controlcenter"

    private static let unmovable: Set<MenuBarItemID> = [
        MenuBarItemID(ownerBundleID: controlCenterBundleID, title: "Clock"),
        MenuBarItemID(ownerBundleID: controlCenterBundleID, title: "BentoBox"),
        MenuBarItemID(ownerBundleID: "com.apple.systemuiserver", title: "Siri"),
    ]
    private static let movableButNotHidable: Set<MenuBarItemID> = [
        MenuBarItemID(ownerBundleID: controlCenterBundleID, title: "AudioVideoModule"),
        MenuBarItemID(ownerBundleID: controlCenterBundleID, title: "FaceTime"),
        MenuBarItemID(ownerBundleID: controlCenterBundleID, title: "MusicRecognition"),
    ]

    private struct Candidate {
        let window: WindowInfo
        let id: MenuBarItemID
        /// `true` when Accessibility supplied the owner; only then is `id` a stable identity.
        let isResolved: Bool
    }

    /// Largest difference in points between a window's y and the display's top that still counts
    /// as the top of its menu bar.
    static var barTopTolerance: Double { 1 }

    private let windowList: any WindowListProvider
    private let ownerResolver: any ItemOwnerResolving
    private let mainDisplay: @Sendable () -> ItemFrame

    /// `mainDisplay` is the bounds of the display the app works on, in the window server's global
    /// coordinates; it is read on every `discover()` because displays come and go.
    public init(
        windowList: any WindowListProvider, ownerResolver: any ItemOwnerResolving,
        mainDisplay: @escaping @Sendable () -> ItemFrame
    ) {
        self.windowList = windowList
        self.ownerResolver = ownerResolver
        self.mainDisplay = mainDisplay
    }

    /// Visible, non-empty status item windows of the main display's menu bar, ordered by x.
    /// Offscreen twins, zero-size windows and everything off layer 25 are dropped.
    ///
    /// Every item has a window on each display's bar (a second display's copies sit at that
    /// display's own y), so only windows at the main display's top and not past its right edge
    /// stay. The left edge is open on purpose: hidden items are pushed left of the display.
    ///
    /// An item is managed only when Accessibility named its owner. Without that answer the
    /// window's own owner and title are not an identity: on macOS 26 the owner is Control Center
    /// for every item, and elsewhere the title is empty without Screen Recording, so an ID built
    /// from them would change once Accessibility is granted and orphan the saved layout. Such an
    /// item is unmanaged (visible, never moved, never saved); its ID is only a display fallback.
    /// Resolved items that share one ID are all unmanaged too.
    public func discover() -> [DiscoveredItem] {
        let display = mainDisplay()
        let candidates = windowList.windows()
            .filter(ItemDiscovery.isStatusItem)
            .filter { ItemDiscovery.isOnBar(of: display, $0) }
            .sorted { ($0.frame.x, $0.windowID) < ($1.frame.x, $1.windowID) }
            .map(candidate)
        let shared = Set(
            Dictionary(grouping: candidates.filter(\.isResolved), by: \.id)
                .filter { $0.value.count > 1 }.keys)
        return candidates.map { discovered($0, isShared: shared.contains($0.id)) }
    }

    private static func isStatusItem(_ window: WindowInfo) -> Bool {
        window.layer == statusItemLayer && window.isOnscreen
            && window.frame.width > 0 && window.frame.height > 0
    }

    private static func isOnBar(of display: ItemFrame, _ window: WindowInfo) -> Bool {
        abs(window.frame.y - display.y) <= barTopTolerance
            && window.frame.x < display.x + display.width
    }

    private func candidate(for window: WindowInfo) -> Candidate {
        if let owner = ownerResolver.owner(ofWindow: window.windowID) {
            let id = MenuBarItemID(ownerBundleID: owner.bundleID, title: owner.title)
            return Candidate(window: window, id: id, isResolved: true)
        }
        let id = MenuBarItemID(ownerBundleID: window.ownerBundleID ?? "", title: window.title)
        return Candidate(window: window, id: id, isResolved: false)
    }

    private func discovered(_ candidate: Candidate, isShared: Bool) -> DiscoveredItem {
        let isManaged = candidate.isResolved && !isShared
        let id = candidate.id
        let isMovable = isManaged && !ItemDiscovery.unmovable.contains(id)
        let isHidable = isMovable && !ItemDiscovery.movableButNotHidable.contains(id)
        let item = MenuBarItem(
            id: id, frame: candidate.window.frame, isMovable: isMovable, isHidable: isHidable)
        return DiscoveredItem(windowID: candidate.window.windowID, item: item, isManaged: isManaged)
    }
}
