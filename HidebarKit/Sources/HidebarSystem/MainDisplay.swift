import CoreGraphics
import HidebarCore

/// Bounds of the main display in the window server's global coordinates, where its menu bar sits.
public enum MainDisplay {
    public static func bounds() -> ItemFrame {
        let rect = CGDisplayBounds(CGMainDisplayID())
        return ItemFrame(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
    }
}
