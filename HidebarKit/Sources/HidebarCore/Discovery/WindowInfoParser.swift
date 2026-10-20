import Foundation

/// Turns the raw dictionaries of `CGWindowListCopyWindowInfo` into `WindowInfo`. The keys are the
/// string values of the `kCGWindow*` constants, so the core needs no CoreGraphics.
public struct WindowInfoParser: Sendable {
    public typealias RawWindow = [String: Any]

    private let bundleIDOfPID: @Sendable (Int) -> String?

    /// `bundleIDOfPID` names the process that owns a window; the window list carries only the pid.
    public init(bundleIDOfPID: @escaping @Sendable (Int) -> String?) {
        self.bundleIDOfPID = bundleIDOfPID
    }

    /// Entries without a window number, layer, owner pid or complete bounds are dropped.
    public func parse(_ raw: [RawWindow]) -> [WindowInfo] {
        raw.compactMap(window)
    }

    private func window(from raw: RawWindow) -> WindowInfo? {
        guard let id = Self.integer(raw["kCGWindowNumber"]),
            let layer = Self.integer(raw["kCGWindowLayer"]),
            let frame = Self.frame(raw["kCGWindowBounds"]),
            let ownerPID = Self.integer(raw["kCGWindowOwnerPID"])
        else { return nil }
        return WindowInfo(
            windowID: id, layer: layer, frame: frame,
            isOnscreen: raw["kCGWindowIsOnscreen"] as? Bool ?? false, ownerPID: ownerPID,
            ownerBundleID: bundleIDOfPID(ownerPID),
            title: raw["kCGWindowName"] as? String ?? "")
    }

    private static func integer(_ value: Any?) -> Int? {
        (value as? NSNumber)?.intValue
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private static func frame(_ value: Any?) -> ItemFrame? {
        guard let bounds = value as? [String: Any],
            let x = number(bounds["X"]), let y = number(bounds["Y"]),
            let width = number(bounds["Width"]), let height = number(bounds["Height"])
        else { return nil }
        return ItemFrame(x: x, y: y, width: width, height: height)
    }
}
