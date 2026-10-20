import AppKit
import UniformTypeIdentifiers

/// The icon of the app that owns a menu bar item.
@MainActor
enum AppIcons {
    static let size = NSSize(width: 18, height: 18)

    /// The app's own icon, or the generic application icon when the bundle cannot be found.
    static func image(bundleID: String) -> NSImage {
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
            ?? NSWorkspace.shared.icon(for: .application)
        icon.size = size
        return icon
    }
}
