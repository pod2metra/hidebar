import AppKit
import HidebarCore

/// The settings window: the draft layout as a list, buttons to apply or revert it, and the
/// message of whatever went wrong last. Every decision is made by `SettingsViewModel` and
/// `AppComposition`; this class shows the state and forwards the clicks.
@MainActor
final class SettingsWindow: NSObject, NSWindowDelegate {
    /// Called with the saved layout after an apply that succeeded.
    var onApplied: (Layout) -> Void = { _ in }
    var onClose: () -> Void = {}

    private let model: SettingsViewModel
    private let composition: AppComposition
    private let table: SettingsTable
    private let names: ItemNames
    private let notice: String?
    private let window = NSWindow(
        contentRect: NSRect(x: 0, y: 0, width: 460, height: 520),
        styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: true)
    private let message = NSTextField(wrappingLabelWithString: "")
    private let applyButton = NSButton(title: "Apply", target: nil, action: nil)
    private let revertButton = NSButton(title: "Revert", target: nil, action: nil)
    /// The reason the last edit of the draft was refused.
    private var editError: String?

    init(model: SettingsViewModel, composition: AppComposition, names: ItemNames, notice: String?) {
        self.model = model
        self.composition = composition
        self.names = names
        self.notice = notice
        table = SettingsTable(model: model, names: names)
        super.init()
        table.onDrop = { [weak self] item, drop in
            self?.edit { try $0.move(item, to: drop.placement, at: drop.index) }
        }
        table.onChangeSymbol = { [weak self] id, view in self?.pickSymbol(from: view, forGroup: id) }
        table.onDeleteGroup = { [weak self] id in self?.edit { try $0.deleteGroup(id) } }
        build()
        refresh()
    }

    func show() {
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onClose()
    }

    // MARK: actions

    @objc private func applyTapped() {
        let refusal = composition.apply(model)
        logApply(desired: model.desiredBarOrder, refusal: refusal, failure: model.failure)
        editError = refusal.map { UserMessages.text(for: $0) }
        refresh()
        if refusal == nil && model.failure == nil { onApplied(model.saved) }
    }

    @objc private func revertTapped() {
        model.revert()
        editError = nil
        refresh()
    }

    @objc private func newGroupTapped(_ sender: NSButton) {
        SymbolPickerView.present(from: sender, categories: model.symbolCategories) { [weak self] name in
            self?.edit { _ = try $0.createGroup(symbolName: name) }
        }
    }

    private func pickSymbol(from view: NSView, forGroup id: UUID) {
        SymbolPickerView.present(from: view, categories: model.symbolCategories) { [weak self] name in
            self?.edit { try $0.setSymbol(ofGroup: id, symbolName: name) }
        }
    }

    private func edit(_ change: (SettingsViewModel) throws -> Void) {
        do {
            try change(model)
            editError = nil
        } catch {
            editError = UserMessages.text(forEditError: error, names: names)
        }
        refresh()
    }

    // MARK: state

    private func refresh() {
        table.reload()
        applyButton.isEnabled = model.isDirty
        revertButton.isEnabled = model.isDirty || model.failure != nil
        let failure = model.failure.map { UserMessages.text(for: $0, names: names) }
        message.stringValue = editError ?? failure ?? notice ?? ""
        message.textColor = (editError ?? failure) == nil ? .secondaryLabelColor : .systemRed
        message.isHidden = message.stringValue.isEmpty
    }

    // MARK: layout

    private func build() {
        window.title = "Hidebar Settings"
        window.isReleasedWhenClosed = false
        window.delegate = self
        let scroll = NSScrollView()
        scroll.documentView = table.tableView
        scroll.hasVerticalScroller = true
        scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 300).isActive = true
        let newGroup = NSButton(title: "New Group", target: self, action: #selector(newGroupTapped(_:)))
        applyButton.target = self
        applyButton.action = #selector(applyTapped)
        applyButton.keyEquivalent = "\r"
        revertButton.target = self
        revertButton.action = #selector(revertTapped)
        let buttons = NSStackView(views: [newGroup, NSView(), revertButton, applyButton])
        let root = NSStackView(views: [message, scroll, buttons])
        root.orientation = .vertical
        root.alignment = .width
        root.spacing = 12
        root.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        window.contentView = root
    }
}
