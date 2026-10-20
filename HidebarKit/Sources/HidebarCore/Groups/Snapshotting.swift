/// Opaque handle to a captured window image. The adapter wraps its platform
/// image (a `CGImage`) and unwraps it again when drawing; the core only passes
/// the handle along and compares it by identity.
public struct SnapshotImage: Equatable {
    public let payload: AnyObject

    public init(payload: AnyObject) {
        self.payload = payload
    }

    public static func == (lhs: SnapshotImage, rhs: SnapshotImage) -> Bool {
        lhs.payload === rhs.payload
    }
}

/// Captures one window. The adapter forwards to ScreenCaptureKit and does nothing else.
@MainActor
public protocol Snapshotting {
    /// Nil when the window cannot be captured (permission lost, window gone).
    func snapshot(ofWindow windowID: Int) async -> SnapshotImage?
}

extension Array where Element == DiscoveredItem {
    /// The only sanctioned way from an item id to its window: the fallback id of an
    /// unmanaged icon can equal a managed one, so unmanaged entries never match.
    func managedItem(_ id: MenuBarItemID) -> DiscoveredItem? {
        first { $0.isManaged && $0.item.id == id }
    }
}
