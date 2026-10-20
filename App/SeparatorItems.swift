import AppKit
import HidebarCore
import HidebarSystem

/// The status items of the one separator: a pipe that hides what is left of it when it stretches,
/// and an arrow right of the pipe that the user clicks to collapse and expand the section.
@MainActor
final class SeparatorItems {
    /// Called when the user left-clicks the arrow.
    var onArrowClick: () -> Void = {}
    /// Called with the item the user right-clicked, control-clicked or middle-clicked.
    var onMenuRequest: (NSStatusItem) -> Void = { _ in }

    let controller: SeparatorController

    private let pipe: NSStatusItemAdapter
    private let arrow: NSStatusItemAdapter
    private var targets: [ButtonTarget] = []

    init(clock: any SchedulingClock) {
        // Everything left of the pipe can be hidden, so the arrow must be right of it: the
        // positions are written before the items are created.
        StatusItemSeeding().seedFixedItems()
        pipe = NSStatusItemAdapter(autosaveName: AutosaveNames.separator)
        arrow = NSStatusItemAdapter(
            autosaveName: AutosaveNames.toggle, symbolName: SeparatorState.shown.arrowSymbolName)
        controller = SeparatorController(item: pipe, clock: clock)
        controller.prepareForLaunch()
        SeparatorMark.apply(to: pipe.item)
        arrow.item.button?.setAccessibilityTitle("Hidebar arrow")
        targets = [
            ButtonTarget(button: pipe.item.button) { [weak self, pipe] click in
                if click == .secondary { self?.onMenuRequest(pipe.item) }
            },
            ButtonTarget(button: arrow.item.button) { [weak self, arrow] click in
                switch click {
                case .primary: self?.onArrowClick()
                case .secondary: self?.onMenuRequest(arrow.item)
                }
            },
        ]
    }

    /// Where the pipe and the arrow sit now, for the core to check their order before it collapses.
    var pipeX: Double? { pipe.item.leftEdge }
    var arrowX: Double? { arrow.item.leftEdge }

    /// Points the arrow at the side the section is hidden on, or away from it.
    func showArrow(collapsed: Bool) {
        let state: SeparatorState = collapsed ? .hiding : .shown
        arrow.setSymbol(state.arrowSymbolName)
    }

    /// Removes the middle-click monitors (left and right clicks need no cleanup); call when the app quits.
    func invalidate() {
        targets.forEach { $0.invalidate() }
    }
}

extension NSStatusItem {
    /// Where the item's window starts, in AppKit screen coordinates. The window stays readable while
    /// the pipe pushes the item off the screen; `nil` when the item has no window.
    @MainActor var leftEdge: Double? {
        button?.window.map { Double($0.frame.minX) }
    }
}
