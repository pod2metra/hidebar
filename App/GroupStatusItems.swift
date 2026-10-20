import AppKit
import HidebarCore
import HidebarSystem

/// One status item per group, each showing the group's SF Symbol.
@MainActor
final class GroupStatusItems {
    /// Called with the group and its button when the user clicks the group's item.
    var onClick: (UUID, NSStatusBarButton) -> Void = { _, _ in }

    private var adapters: [NSStatusItemAdapter] = []
    private var targets: [ClickTarget] = []

    /// Replaces every item. The system remembers an item's place by its autosave name, so an
    /// item that survives a rebuild keeps its position; a new one is seeded right of the separator.
    func rebuild(_ groups: [ItemGroup]) {
        adapters.forEach { NSStatusBar.system.removeStatusItem($0.item) }
        StatusItemSeeding().seedGroups(groups)
        targets = groups.map { group in
            ClickTarget(groupID: group.id) { [weak self] id, button in self?.onClick(id, button) }
        }
        adapters = zip(groups, targets).map { group, target in
            let adapter = NSStatusItemAdapter(
                autosaveName: AutosaveNames.group(group.id), symbolName: group.symbol.name)
            adapter.item.button?.target = target
            adapter.item.button?.action = #selector(ClickTarget.clicked(_:))
            adapter.item.button?.setAccessibilityTitle(OwnItems.groupTitle(group))
            return adapter
        }
    }
}

/// Receives the button action for one group; a status item button has one target only.
@MainActor
private final class ClickTarget: NSObject {
    private let groupID: UUID
    private let handler: (UUID, NSStatusBarButton) -> Void

    init(groupID: UUID, handler: @escaping (UUID, NSStatusBarButton) -> Void) {
        self.groupID = groupID
        self.handler = handler
    }

    @objc func clicked(_ sender: NSStatusBarButton) {
        handler(groupID, sender)
    }
}
