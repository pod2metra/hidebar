import AppKit
import HidebarCore

/// A real `NSStatusItem` behind the core's `StatusItemControlling`.
@MainActor
public final class NSStatusItemAdapter: StatusItemControlling {
    /// The app attaches its click action to it.
    public let item: NSStatusItem

    /// `autosaveName` keeps the item's position across launches. `symbolName` is an SF Symbol
    /// drawn as a template image; `nil` leaves the item without an image.
    public init(autosaveName: String, symbolName: String? = nil) {
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = autosaveName
        setSymbol(symbolName)
    }

    public func setSymbol(_ symbolName: String?) {
        let image = symbolName.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
        image?.isTemplate = true
        item.button?.image = image
    }

    public var length: Double {
        get { item.length }
        set { item.length = newValue }
    }

    public var isVisible: Bool {
        get { item.isVisible }
        set { item.isVisible = newValue }
    }
}
