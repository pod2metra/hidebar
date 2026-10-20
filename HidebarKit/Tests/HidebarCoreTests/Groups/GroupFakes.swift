@testable import HidebarCore

/// Serves canned images by window id. A window in `holdWindows` suspends its request
/// until `release(_:)`, handing back the image that was current when it was asked.
@MainActor
final class FakeSnapshotter: Snapshotting {
    var images: [Int: SnapshotImage] = [:]
    var holdWindows: Set<Int> = []
    private(set) var requested: [Int] = []
    private var held: [Int: CheckedContinuation<Void, Never>] = [:]
    private var released: Set<Int> = []

    func snapshot(ofWindow windowID: Int) async -> SnapshotImage? {
        requested.append(windowID)
        let image = images[windowID]
        if holdWindows.contains(windowID) && !released.contains(windowID) {
            await withCheckedContinuation { held[windowID] = $0 }
        }
        return image
    }

    /// Frees a held window now, or lets a request that has not arrived yet pass straight through,
    /// so a test whose timing broke fails an assertion instead of hanging.
    func release(_ windowID: Int) {
        released.insert(windowID)
        held.removeValue(forKey: windowID)?.resume()
    }
}

final class FakeImage {}

/// A menu probe a test flips by hand; `reads` counts how often it was asked.
@MainActor
final class FakeMenuProbe {
    var isOpen = false
    private(set) var reads = 0

    func isMenuOpen() -> Bool {
        reads += 1
        return isOpen
    }
}

func discovered(
    _ name: String, x: Double = 0, windowID: Int = 1, managed: Bool = true, movable: Bool = true
) -> DiscoveredItem {
    DiscoveredItem(
        windowID: windowID, ownerPID: 688,
        item: MenuBarItem(
            id: moveID(name), frame: ItemFrame(x: x, y: 0, width: 10, height: 20),
            isMovable: movable),
        isManaged: managed)
}

/// Wraps the bar's locator; `transform` sees the 1-based lookup count and the real frame.
@MainActor
final class ScriptedLocator: ItemLocating {
    private let bar: MoveFakeBar
    private var lookups = 0
    var transform: (Int, ItemFrame?) -> ItemFrame? = { $1 }

    init(_ bar: MoveFakeBar) {
        self.bar = bar
    }

    func frame(of id: MenuBarItemID) -> ItemFrame? {
        lookups += 1
        return transform(lookups, bar.frame(of: id))
    }
}
