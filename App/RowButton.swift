import AppKit
import HidebarCore

/// Draws one row of the overflow strip as a button; a row that cannot be clicked is disabled,
/// except while Accessibility is off, where a click asks for the permission.
@MainActor
enum RowButton {
    static func make(for row: GroupPanelRow) -> NSButton {
        let button = NSButton()
        button.isBordered = false
        button.isEnabled = row.isEnabled
        button.toolTip = row.name
        button.title = row.name
        button.image = AppIcons.image(bundleID: row.id.ownerBundleID)
        button.imagePosition = .imageLeading
        return button
    }
}
