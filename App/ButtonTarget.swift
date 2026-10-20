import AppKit

/// Receives the clicks of one status item button. The button holds its target weakly, so whoever
/// creates a `ButtonTarget` keeps it for as long as the button lives and calls `invalidate` before
/// letting go.
///
/// A status item button does not track the middle button, so that one is caught by a local event
/// monitor; the button's own action takes the left button (control-click counts as secondary, as
/// it does for the system) and the right one.
@MainActor
final class ButtonTarget: NSObject {
    enum Click {
        /// A plain left click.
        case primary
        /// A middle, right or control-left click.
        case secondary
    }

    private let handler: (Click) -> Void
    private var monitor: Any?

    init(button: NSStatusBarButton?, handler: @escaping (Click) -> Void) {
        self.handler = handler
        super.init()
        button?.target = self
        button?.action = #selector(clicked(_:))
        button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        monitor = NSEvent.addLocalMonitorForEvents(matching: .otherMouseUp) { [weak self, weak button] event in
            guard event.buttonNumber == 2, let window = button?.window, event.window === window else {
                return event
            }
            // Out of the event dispatch, so a menu's tracking loop does not run inside the monitor.
            Task { @MainActor in self?.handler(.secondary) }
            return nil
        }
    }

    /// Stops listening for middle clicks.
    func invalidate() {
        monitor.map(NSEvent.removeMonitor)
        monitor = nil
    }

    @objc private func clicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        let isSecondary = event.type == .rightMouseUp || event.modifierFlags.contains(.control)
        handler(isSecondary ? .secondary : .primary)
    }
}
