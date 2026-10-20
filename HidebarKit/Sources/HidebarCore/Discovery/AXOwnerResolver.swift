import Synchronization

/// Finds the real owner of a status item window by matching the window's frame against the items
/// Accessibility lists. On macOS 26 the window owner is Control Center for every item, so this is
/// the only source of the owner. When several items match one window the owner is ambiguous: the
/// answer is `nil` and the item stays unmanaged.
///
/// `ItemDiscovery` asks once per window, and reading the tree costs one round trip per app. The
/// entries are therefore kept while the window list stays exactly the same; an empty read is not
/// kept, so granting Accessibility takes effect at once.
public final class AXOwnerResolver<Tree: AXTreeReading>: ItemOwnerResolving {
    /// Largest difference in points between a window's and an item's horizontal centre that still
    /// matches.
    static var centreTolerance: Double { 1.5 }
    /// How much wider than its window an item's AX frame may be and still match. An app's item is
    /// one point wider on each side; a system item (Wi-Fi, the clock) is ten points narrower on
    /// each side, which fits without a lower bound.
    static var widthTolerance: Double { 4 }

    private struct Snapshot {
        let windows: [WindowInfo]
        let entries: [AXMenuBarEntry]
    }

    private let windowList: any WindowListProvider
    private let reader: AXMenuBarReader<Tree>
    private let cache = Mutex<Snapshot?>(nil)

    public init(windowList: any WindowListProvider, reader: AXMenuBarReader<Tree>) {
        self.windowList = windowList
        self.reader = reader
    }

    public func owner(ofWindow windowID: Int) -> ItemOwner? {
        let windows = windowList.windows()
        guard let window = windows.first(where: { $0.windowID == windowID }) else { return nil }
        return matches(for: window, in: windows).sole?.owner
    }

    private func matches(for window: WindowInfo, in windows: [WindowInfo]) -> [AXMenuBarEntry] {
        entries(for: windows).filter { Self.matches($0.frame, window.frame) }
    }

    private func entries(for windows: [WindowInfo]) -> [AXMenuBarEntry] {
        cache.withLock { cached in
            if let cached, cached.windows == windows { return cached.entries }
            let entries = reader.entries()
            cached = entries.isEmpty ? nil : Snapshot(windows: windows, entries: entries)
            return entries
        }
    }

    /// Hidden Control Center modules are listed with an empty frame at the origin; they are not
    /// on the bar and match no window.
    private static func matches(_ item: ItemFrame, _ window: ItemFrame) -> Bool {
        item.width > 0
            && abs((item.x + item.width / 2) - (window.x + window.width / 2)) < centreTolerance
            && item.width - window.width < widthTolerance
    }
}
