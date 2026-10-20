import AppKit
import HidebarCore

/// The list in the settings window: section headers and the icons under them, with drag and
/// drop between sections. Which rows exist and where a drop lands comes from `SettingsRows`;
/// whether a drop is allowed comes from `SettingsViewModel`.
@MainActor
final class SettingsTable: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    /// An icon was dropped; the window applies it to the draft.
    var onDrop: (MenuBarItemID, SettingsDrop) -> Void = { _, _ in }
    var onChangeSymbol: (UUID, NSView) -> Void = { _, _ in }
    var onDeleteGroup: (UUID) -> Void = { _ in }

    let tableView = NSTableView()

    private static let dragType = NSPasteboard.PasteboardType("app.hidebar.settings-row")

    private let model: SettingsViewModel
    private var rows: SettingsRows
    /// `canDrop` reads the bar, so each placement is asked once per drag.
    private var dropAnswers: [Placement: Bool] = [:]

    init(model: SettingsViewModel) {
        self.model = model
        rows = SettingsRows(sections: model.sections)
        super.init()
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("main"))
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 28
        tableView.floatsGroupRows = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.registerForDraggedTypes([Self.dragType])
    }

    func reload() {
        rows = SettingsRows(sections: model.sections)
        tableView.reloadData()
    }

    // MARK: data

    func numberOfRows(in tableView: NSTableView) -> Int { rows.rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        switch rows.rows[row] {
        case .header(_, let title, let symbolName):
            return headerView(title: title, symbolName: symbolName, groupID: rows.groupID(atRow: row))
        case .item(let id, _):
            return itemView(id)
        }
    }

    private func headerView(title: String, symbolName: String?, groupID: UUID?) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .boldSystemFont(ofSize: NSFont.systemFontSize)
        let icon = NSImageView(
            image: symbolName.flatMap { NSImage(systemSymbolName: $0, accessibilityDescription: nil) }
                ?? NSImage())
        let stack = NSStackView(views: [icon, label])
        stack.spacing = 6
        guard let groupID else { return stack }
        for (symbol, action) in [("square.grid.2x2", #selector(changeSymbol(_:))), ("trash", #selector(deleteGroup(_:)))] {
            let button = NSButton(
                image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage(),
                target: self, action: action)
            button.bezelStyle = .texturedRounded
            button.identifier = NSUserInterfaceItemIdentifier(groupID.uuidString)
            stack.addArrangedSubview(button)
        }
        return stack
    }

    private func itemView(_ id: MenuBarItemID) -> NSView {
        let icon = NSImageView(image: AppIcons.image(bundleID: id.ownerBundleID))
        let label = NSTextField(labelWithString: id.displayName)
        let stack = NSStackView(views: [icon, label])
        stack.edgeInsets = NSEdgeInsets(top: 0, left: 18, bottom: 0, right: 0)
        stack.spacing = 6
        return stack
    }

    @objc private func changeSymbol(_ sender: NSButton) {
        UUID(uuidString: sender.identifier?.rawValue ?? "").map { onChangeSymbol($0, sender) }
    }

    @objc private func deleteGroup(_ sender: NSButton) {
        UUID(uuidString: sender.identifier?.rawValue ?? "").map(onDeleteGroup)
    }

    // MARK: drag and drop

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
        guard rows.item(atRow: row) != nil else { return nil }
        let item = NSPasteboardItem()
        item.setString(String(row), forType: Self.dragType)
        return item
    }

    func tableView(
        _ tableView: NSTableView, draggingSession session: NSDraggingSession, willBeginAt screenPoint: NSPoint,
        forRowIndexes rowIndexes: IndexSet
    ) {
        dropAnswers = [:]
    }

    func tableView(
        _ tableView: NSTableView, validateDrop info: any NSDraggingInfo, proposedRow row: Int,
        proposedDropOperation dropOperation: NSTableView.DropOperation
    ) -> NSDragOperation {
        guard let (item, drop) = target(of: info, aboveRow: row), allows(item, drop.placement) else {
            return []
        }
        tableView.setDropRow(row, dropOperation: .above)
        return .move
    }

    func tableView(
        _ tableView: NSTableView, acceptDrop info: any NSDraggingInfo, row: Int,
        dropOperation: NSTableView.DropOperation
    ) -> Bool {
        guard let (item, drop) = target(of: info, aboveRow: row) else { return false }
        onDrop(item, drop)
        return true
    }

    private func target(of info: any NSDraggingInfo, aboveRow row: Int) -> (MenuBarItemID, SettingsDrop)? {
        let source = info.draggingPasteboard.string(forType: Self.dragType).flatMap { Int($0) }
        guard let item = source.flatMap(rows.item(atRow:)),
            let drop = rows.drop(of: item, aboveRow: row)
        else { return nil }
        return (item, drop)
    }

    private func allows(_ item: MenuBarItemID, _ placement: Placement) -> Bool {
        let answer = dropAnswers[placement] ?? model.canDrop(item, on: placement)
        dropAnswers[placement] = answer
        return answer
    }
}
