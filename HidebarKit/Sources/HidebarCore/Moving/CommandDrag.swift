/// A status item window as the window server knows it: the identity a synthetic mouse event has to
/// name to reach that item, and the window's own frame (a few points narrower than the item's
/// Accessibility frame on macOS 26).
public struct WindowTarget: Equatable, Sendable {
    public let windowID: Int
    /// The window's owner, which on macOS 26 is Control Center for every item.
    public let ownerPID: Int
    public let frame: ItemFrame

    public init(windowID: Int, ownerPID: Int, frame: ItemFrame) {
        self.windowID = windowID
        self.ownerPID = ownerPID
        self.frame = frame
    }
}

/// One ⌘-drag, addressed the way Ice does it: the press names the item's window and the release
/// names the anchor's window, so the pointer positions only have to be consistent with them.
public struct CommandDrag: Equatable, Sendable {
    /// Far off every display: the press picks the item by its window, not by where the pointer is.
    public static let pressPoint = CursorPoint(x: 20_000, y: 20_000)

    public let item: WindowTarget
    public let anchor: WindowTarget
    /// The anchor's near edge on `side`, at the height of its middle.
    public let release: CursorPoint

    public init(item: WindowTarget, anchor: WindowTarget, side: DropSide) {
        self.item = item
        self.anchor = anchor
        let frame = anchor.frame
        let edge: Double = switch side {
        case .leftOf: frame.x
        case .rightOf: frame.x + frame.width
        }
        release = CursorPoint(x: edge, y: frame.y + frame.height / 2)
    }
}
