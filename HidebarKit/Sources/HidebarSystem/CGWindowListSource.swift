import CoreGraphics
import HidebarCore

/// The window server's window list, parsed by the core. Offscreen windows are included on purpose:
/// discovery drops the ones it does not want.
public struct CGWindowListSource: WindowListProvider {
    private let parser: WindowInfoParser

    public init(parser: WindowInfoParser = WindowInfoParser(bundleIDOfPID: RunningApps.bundleID)) {
        self.parser = parser
    }

    /// The unparsed dictionaries of `CGWindowListCopyWindowInfo`.
    public func rawWindows() -> [[String: Any]] {
        CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    }

    public func windows() -> [WindowInfo] {
        parser.parse(rawWindows())
    }
}
