import AppKit
import HidebarCore

/// A small dot in the corner of the arrow's button, with a tooltip, while icons are hidden behind
/// the notch or the menus. Drawn as a subview of the button: no private API is involved, and the
/// arrow's own image is left alone.
///
/// The dot is placed by its frame and an autoresizing mask, not by constraints, so it takes no part
/// in the button's size (`arrowX` and the collapse guard depend on that), and it never takes a click.
@MainActor
final class ArrowBadge {
    private final class Dot: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }

    private static let diameter = 6.0
    private static let inset = 2.0

    private let button: NSStatusBarButton?
    private let dot = Dot()

    init(button: NSStatusBarButton?) {
        self.button = button
        dot.wantsLayer = true
        dot.layer?.backgroundColor = NSColor.systemOrange.cgColor
        dot.layer?.cornerRadius = Self.diameter / 2
        dot.isHidden = true
        guard let button else { return }
        let top = button.isFlipped ? Self.inset : button.bounds.height - Self.diameter - Self.inset
        dot.frame = NSRect(
            x: button.bounds.width - Self.diameter - Self.inset, y: top, width: Self.diameter,
            height: Self.diameter)
        dot.autoresizingMask = [.minXMargin, button.isFlipped ? .maxYMargin : .minYMargin]
        button.addSubview(dot)
    }

    /// With nothing hidden the arrow looks and behaves as it did before: no dot, no tooltip.
    func apply(_ indicator: NotchIndicator) {
        dot.isHidden = !indicator.isShown
        button?.toolTip = indicator.tooltip
    }
}
