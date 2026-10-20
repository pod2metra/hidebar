import AppKit
import HidebarCore

/// A grid of the catalog's SF Symbols, one row per category, shown in a popover.
@MainActor
final class SymbolPickerView: NSView {
    private final class SymbolButton: NSButton {
        var symbolName = ""
    }

    private let onPick: (String) -> Void

    init(categories: [SymbolCatalog.Category], onPick: @escaping (String) -> Void) {
        self.onPick = onPick
        super.init(frame: .zero)
        let content = NSStackView(views: categories.map(row(for:)))
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 10
        content.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: topAnchor),
            content.bottomAnchor.constraint(equalTo: bottomAnchor),
            content.leadingAnchor.constraint(equalTo: leadingAnchor),
            content.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not used") }

    /// Shows the picker under `view`; `onPick` gets the chosen symbol name and the popover closes.
    static func present(
        from view: NSView, categories: [SymbolCatalog.Category], onPick: @escaping (String) -> Void
    ) {
        let popover = NSPopover()
        popover.behavior = .transient
        let controller = NSViewController()
        controller.view = SymbolPickerView(categories: categories) { name in
            popover.close()
            onPick(name)
        }
        popover.contentViewController = controller
        popover.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    }

    private func row(for category: SymbolCatalog.Category) -> NSView {
        let title = NSTextField(labelWithString: category.name)
        title.font = .boldSystemFont(ofSize: NSFont.smallSystemFontSize)
        let buttons = NSStackView(views: category.symbols.map(button(for:)))
        buttons.spacing = 4
        let column = NSStackView(views: [title, buttons])
        column.orientation = .vertical
        column.alignment = .leading
        column.spacing = 4
        return column
    }

    private func button(for name: String) -> NSView {
        let button = SymbolButton()
        button.symbolName = name
        button.image = NSImage(systemSymbolName: name, accessibilityDescription: name)
        button.toolTip = name
        button.bezelStyle = .texturedRounded
        button.target = self
        button.action = #selector(picked(_:))
        return button
    }

    @objc private func picked(_ sender: SymbolButton) {
        onPick(sender.symbolName)
    }
}
