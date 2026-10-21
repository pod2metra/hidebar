import AppKit
import HidebarCore

/// Draws one row of the overflow strip as a button; a row that cannot be clicked is disabled.
@MainActor
enum RowButton {
    static func make(for row: GroupPanelRow) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.isEnabled = row.isClickable
        button.toolTip = row.name
        button.title = row.name
        button.image = AppIcons.image(bundleID: row.id.ownerBundleID)
        button.imagePosition = .imageLeading
        return button
    }
}
