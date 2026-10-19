import AppKit
import CoreGraphics

// Private CoreGraphics (SkyLight) entry points, same signatures Ice uses.
@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> Int32

@_silgen_name("CGSGetWindowCount")
func CGSGetWindowCount(_ cid: Int32, _ targetCID: Int32, _ outCount: inout Int32) -> CGError

@_silgen_name("CGSGetProcessMenuBarWindowList")
func CGSGetProcessMenuBarWindowList(
    _ cid: Int32,
    _ targetCID: Int32,
    _ count: Int32,
    _ list: UnsafeMutablePointer<CGWindowID>,
    _ outCount: inout Int32
) -> CGError

struct MenuBarWindow {
    let id: CGWindowID
    let pid: pid_t
    let ownerName: String
    let bundleID: String
    let name: String
    let bounds: CGRect
    let layer: Int
    let onScreen: Bool
    /// Present in the private CGSGetProcessMenuBarWindowList result.
    let inCGSList: Bool

    /// macOS refuses to move these; Ice keys them by bundle id + window name.
    var isImmovable: Bool {
        switch (bundleID, name) {
        case ("com.apple.controlcenter", "Clock"),
             ("com.apple.controlcenter", "BentoBox"),
             ("com.apple.systemuiserver", "Siri"):
            return true
        default:
            return false
        }
    }
}

enum Windows {
    static func cgsMenuBarIDs() -> [CGWindowID] {
        let cid = CGSMainConnectionID()
        var count: Int32 = 0
        guard CGSGetWindowCount(cid, 0, &count) == .success, count > 0 else { return [] }
        var list = [CGWindowID](repeating: 0, count: Int(count))
        var real: Int32 = 0
        guard CGSGetProcessMenuBarWindowList(cid, 0, count, &list, &real) == .success else { return [] }
        return Array(list[..<Int(real)])
    }

    /// Status-level windows (layer == kCGStatusWindowLevel) plus anything the CGS menu bar list
    /// names, offscreen windows included (hidden items live there). Sorted by x.
    static func menuBarWindows() -> [MenuBarWindow] {
        let cgs = Set(cgsMenuBarIDs())
        let raw = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
        let statusLevel = Int(CGWindowLevelForKey(.statusWindow))
        return raw.compactMap { info -> MenuBarWindow? in
            guard
                let id = info[kCGWindowNumber as String] as? CGWindowID,
                let layer = info[kCGWindowLayer as String] as? Int,
                let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                let bounds = CGRect(dictionaryRepresentation: boundsDict),
                layer == statusLevel || cgs.contains(id)
            else { return nil }
            return MenuBarWindow(
                id: id,
                pid: pid,
                ownerName: info[kCGWindowOwnerName as String] as? String ?? "",
                bundleID: NSRunningApplication(processIdentifier: pid)?.bundleIdentifier ?? "",
                name: info[kCGWindowName as String] as? String ?? "",
                bounds: bounds,
                layer: layer,
                onScreen: info[kCGWindowIsOnscreen as String] as? Bool ?? false,
                inCGSList: cgs.contains(id)
            )
        }
        .sorted { $0.bounds.minX < $1.bounds.minX }
    }

    static func find(_ id: CGWindowID) -> MenuBarWindow? {
        menuBarWindows().first { $0.id == id }
    }
}

func fmt(_ r: CGRect) -> String {
    "x=\(Int(r.minX)) y=\(Int(r.minY)) w=\(Int(r.width)) h=\(Int(r.height))"
}

func runList() {
    let windows = Windows.menuBarWindows()
    let cgs = Windows.cgsMenuBarIDs()
    let owners = axOwners()
    print("status-level windows: \(windows.count); CGSGetProcessMenuBarWindowList ids: \(cgs.count)")
    if owners.isEmpty { print("note: no AX owner data (Accessibility not granted?), axOwner column omitted") }
    for w in windows {
        let ax = axOwner(for: w, in: owners).map { "axOwner=\($0.bundleID.isEmpty ? $0.appName : $0.bundleID)" } ?? ""
        print([
            "id=\(w.id)",
            "pid=\(w.pid)",
            "owner=\"\(w.ownerName)\"",
            "bundle=\(w.bundleID.isEmpty ? "-" : w.bundleID)",
            ax,
            "name=\"\(w.name)\"",
            fmt(w.bounds),
            "layer=\(w.layer)",
            "onscreen=\(w.onScreen)",
            "cgs=\(w.inCGSList)",
            w.isImmovable ? "IMMOVABLE" : "",
        ].filter { !$0.isEmpty }.joined(separator: " "))
    }
    let known = Set(windows.map(\.id))
    let missing = cgs.filter { !known.contains($0) }
    if !missing.isEmpty { print("CGS ids with no CGWindowList entry: \(missing)") }
}
