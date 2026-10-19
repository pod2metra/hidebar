import AppKit
import ApplicationServices

/// On macOS 26 every status window is owned by Control Center, so the real owner has to come
/// from Accessibility: each running app's AXExtrasMenuBar children carry the item frames.
/// Needs Accessibility; returns [] without it.
struct AXOwner {
    let appName: String
    let bundleID: String
    let frame: CGRect
}

private func frame(of element: AXUIElement) -> CGRect? {
    var posRef: CFTypeRef?
    var sizeRef: CFTypeRef?
    guard
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &posRef) == .success,
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeRef) == .success,
        let posRef, let sizeRef,
        CFGetTypeID(posRef) == AXValueGetTypeID(), CFGetTypeID(sizeRef) == AXValueGetTypeID()
    else { return nil }
    var origin = CGPoint.zero
    var size = CGSize.zero
    AXValueGetValue(unsafeBitCast(posRef, to: AXValue.self), .cgPoint, &origin)
    AXValueGetValue(unsafeBitCast(sizeRef, to: AXValue.self), .cgSize, &size)
    return CGRect(origin: origin, size: size)
}

func axOwners() -> [AXOwner] {
    guard AXIsProcessTrusted() else { return [] }
    var owners: [AXOwner] = []
    for app in NSWorkspace.shared.runningApplications {
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.3)
        var barRef: CFTypeRef?
        var childrenRef: CFTypeRef?
        guard
            AXUIElementCopyAttributeValue(root, "AXExtrasMenuBar" as CFString, &barRef) == .success,
            let barRef, CFGetTypeID(barRef) == AXUIElementGetTypeID(),
            AXUIElementCopyAttributeValue(
                unsafeBitCast(barRef, to: AXUIElement.self), kAXChildrenAttribute as CFString, &childrenRef
            ) == .success,
            let children = childrenRef as? [AXUIElement]
        else { continue }
        for child in children {
            guard let rect = frame(of: child) else { continue }
            owners.append(AXOwner(
                appName: app.localizedName ?? "", bundleID: app.bundleIdentifier ?? "", frame: rect
            ))
        }
    }
    return owners
}

/// Matches a status window to an AX item frame (1.5 pt tolerance on x and width).
func axOwner(for window: MenuBarWindow, in owners: [AXOwner]) -> AXOwner? {
    owners.first {
        abs($0.frame.minX - window.bounds.minX) < 1.5 && abs($0.frame.width - window.bounds.width) < 1.5
    }
}
