import AppKit
import HidebarCore

/// Draws one row of a group panel as a button; a row that cannot be clicked is disabled.
@MainActor
enum RowButton {
    static func make(for row: GroupPanelRow) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.isEnabled = row.isClickable
        button.toolTip = row.name
        switch row.content {
        case .snapshot(let image):
            button.image = image.nsImage
            button.imagePosition = .imageOnly
        case .appName:
            button.title = row.name
            button.image = AppIcons.image(bundleID: row.id.ownerBundleID)
            button.imagePosition = .imageLeading
        case .unavailable:
            button.title = "\(row.name) (not on the bar)"
            button.imagePosition = .noImage
        }
        return button
    }

}

extension SnapshotImage {
    /// The captured window as an image, drawn at its size in points.
    var nsImage: NSImage? {
        guard CFGetTypeID(payload) == CGImage.typeID else { return nil }
        let image = unsafeDowncast(payload, to: CGImage.self)
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        return NSImage(
            cgImage: image,
            size: NSSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale))
    }
}
