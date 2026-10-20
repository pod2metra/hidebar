import AppKit
import HidebarCore

/// A panel that takes key status without activating another window, so it can notice the user
/// clicking elsewhere.
private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// The panel that drops down under a group's status item: one row per icon of the group.
/// What a row shows comes from `GroupPanelViewModel`; this class only draws it.
@MainActor
final class GroupPanelWindow: NSObject, NSWindowDelegate {
    /// Called with the icon whose row was clicked; the panel is already closed by then.
    var onRowClick: (MenuBarItemID) -> Void = { _ in }
    /// Called each time the panel closes.
    var onClose: () -> Void = {}

    var isVisible: Bool { panel.isVisible }

    private let viewModel: GroupPanelViewModel
    private let panel = KeyPanel(
        contentRect: NSRect(x: 0, y: 0, width: 200, height: 40),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
    private let stack = NSStackView()
    private let emptyLabel = NSTextField(labelWithString: "No icons in this group")

    init(snapshotter: any Snapshotting, names: ItemNames) {
        viewModel = GroupPanelViewModel(snapshotter: snapshotter, names: names)
        super.init()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        let background = NSVisualEffectView()
        background.material = .popover
        background.state = .active
        background.wantsLayer = true
        background.layer?.cornerRadius = 8
        background.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: background.topAnchor),
            stack.bottomAnchor.constraint(equalTo: background.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: background.trailingAnchor),
        ])
        panel.contentView = background
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.delegate = self
    }

    func show(
        group: ItemGroup, below button: NSStatusBarButton, items: [DiscoveredItem],
        capabilities: Capabilities
    ) async {
        await viewModel.refresh(group: group, items: items, capabilities: capabilities)
        rebuildRows()
        place(below: button)
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        onClose()
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    @objc private func rowClicked(_ sender: NSButton) {
        close()
        onRowClick(viewModel.rows[sender.tag].id)
    }

    private func rebuildRows() {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.addArrangedSubview(emptyLabel)
        emptyLabel.isHidden = !viewModel.isEmpty
        for (index, row) in viewModel.rows.enumerated() {
            let button = RowButton.make(for: row)
            button.tag = index
            button.target = self
            button.action = #selector(rowClicked(_:))
            stack.addArrangedSubview(button)
        }
    }

    private func place(below button: NSStatusBarButton) {
        guard let anchor = button.window?.frame else { return }
        panel.setContentSize(stack.fittingSize)
        let size = panel.frame.size
        let area = button.window?.screen?.visibleFrame ?? anchor
        let x = min(max(anchor.midX - size.width / 2, area.minX + 4), area.maxX - size.width - 4)
        panel.setFrameOrigin(NSPoint(x: x, y: anchor.minY - size.height - 4))
    }
}
