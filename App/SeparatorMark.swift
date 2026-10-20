import AppKit
import HidebarCore

/// What the separator looks like on the bar and what Accessibility calls it. The title is what
/// makes the separator's id stable (`OwnItems.separatorID`), so the planner can find it.
@MainActor
enum SeparatorMark {
    static func apply(to item: NSStatusItem) {
        item.button?.image = divider
        item.button?.setAccessibilityTitle(OwnItems.separatorTitle)
    }

    private static let divider: NSImage = {
        let image = NSImage(size: NSSize(width: 6, height: 16), flipped: false) { _ in
            NSColor.black.withAlphaComponent(0.5).setFill()
            NSRect(x: 2.5, y: 2, width: 1, height: 12).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()
}
