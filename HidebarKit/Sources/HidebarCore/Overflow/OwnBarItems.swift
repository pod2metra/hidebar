/// The horizontal extent of a status item's window, in the window server's global coordinates.
public struct BarSpan: Equatable, Sendable {
    public let x: Double
    public let width: Double

    public init(x: Double, width: Double) {
        self.x = x
        self.width = width
    }
}

/// Where the app's own pipe and arrow are on the bar, read from their own windows, which needs no
/// permission. Discovery cannot tell them from other icons without Accessibility: on macOS 26 every
/// status window is owned by Control Center and has no title. Their frames can, and they hold in
/// every state: a collapsed pipe's window keeps its true frame while it pushes the icons away.
public struct OwnBarItems: Equatable, Sendable {
    /// How far a window's frame may differ from an own item's and still be that item.
    static let tolerance = 1.0

    public let separator: BarSpan
    public let arrow: BarSpan

    /// `nil` unless both items have a window with a width: without both there is no boundary to
    /// count against.
    public init?(separator: BarSpan?, arrow: BarSpan?) {
        guard let separator, let arrow, separator.width > 0, arrow.width > 0 else { return nil }
        self.separator = separator
        self.arrow = arrow
    }

    /// `self` when the arrow's window starts on the screen spanning `minX..<minX + width`, else `nil`.
    /// The items can sit on the bar of another display, whose frames never match the windows found
    /// on this screen, so every icon would count as hidden. The pipe takes no part: while collapsed
    /// its window reaches far past the left edge of the screen.
    public func on(screenFrom minX: Double, width: Double) -> OwnBarItems? {
        (minX..<minX + width).contains(arrow.x) ? self : nil
    }

    /// True when `frame` is the window of the pipe or of the arrow. Height and top do not take part.
    public func contains(_ frame: ItemFrame) -> Bool {
        [separator, arrow].contains { Self.matches($0, frame) }
    }

    private static func matches(_ span: BarSpan, _ frame: ItemFrame) -> Bool {
        abs(span.x - frame.x) <= tolerance && abs(span.width - frame.width) <= tolerance
    }
}
