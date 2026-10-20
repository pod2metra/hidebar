import AppKit
import HidebarCore
import HidebarSystem

/// The strip under the menu bar that holds the icons which do not fit it. Which icons those are,
/// how far the strip is scrolled and what each row shows comes from `OverflowStripViewModel`;
/// this class reads the screen, positions the panel and draws the visible rows.
@MainActor
final class OverflowStripWindow: NSObject {
    private final class StripView: NSVisualEffectView {
        var onScroll: (ScrollInput) -> Void = { _ in }

        override func scrollWheel(with event: NSEvent) {
            onScroll(
                ScrollInput(
                    deltaX: event.scrollingDeltaX, deltaY: event.scrollingDeltaY,
                    hasPreciseDeltas: event.hasPreciseScrollingDeltas))
        }
    }

    /// Called with what came of clicking a row's icon.
    var onRowClick: (ClickOutcome) -> Void = { _ in }

    private static let height = 36.0

    private let services: AppServices
    private let viewModel: OverflowStripViewModel
    private let strip = StripView()
    private let panel = NSPanel(
        contentRect: NSRect(x: 0, y: 0, width: 100, height: 36),
        styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)

    init(services: AppServices) {
        self.services = services
        viewModel = OverflowStripViewModel(
            snapshotter: services.snapshotter, click: services.composition.click)
        super.init()
        strip.material = .menu
        strip.state = .active
        strip.wantsLayer = true
        strip.layer?.masksToBounds = true
        strip.onScroll = { [weak self] input in
            self?.viewModel.scroll(input)
            self?.drawRows()
        }
        panel.contentView = strip
        panel.level = .statusBar
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
    }

    /// The screens, the permissions or the arrangement of the bar changed.
    func barDidChange() {
        Task { await refresh() }
    }

    private func refresh() async {
        guard let screen = NSScreen.screens.first else { return }
        let frame = screen.frame
        let menusEdge = (services.menus.maxX() ?? frame.minX) - frame.minX
        let notch = screen.auxiliaryTopRightArea.map {
            BarRect(x: $0.minX - frame.minX, y: 0, width: $0.width, height: $0.height)
        }
        let calculator = OverflowCalculator(
            screenWidth: frame.width, notchRightArea: notch, menusWidth: menusEdge, spacing: 0)
        await viewModel.recompute(
            screen: calculator, viewportWidth: frame.width - calculator.leftLimit,
            items: services.discovery.discover(),
            capabilities: services.permissions.current().capabilities)
        place(on: screen, from: calculator.leftLimit)
        drawRows()
    }

    private func place(on screen: NSScreen, from leftLimit: Double) {
        let barHeight = screen.frame.maxY - screen.visibleFrame.maxY
        panel.setFrame(
            NSRect(
                x: screen.frame.minX + leftLimit, y: screen.frame.maxY - barHeight - Self.height,
                width: viewModel.scrollModel.viewportWidth, height: Self.height),
            display: true)
        if viewModel.isHidden {
            panel.orderOut(nil)
        } else {
            panel.orderFrontRegardless()
        }
    }

    private func drawRows() {
        strip.subviews.forEach { $0.removeFromSuperview() }
        for index in viewModel.visibleRange {
            let button = RowButton.make(for: viewModel.rows[index])
            button.imageScaling = .scaleProportionallyDown
            button.frame = NSRect(
                x: viewModel.rowStart(at: index) - viewModel.scrollModel.offset, y: 0,
                width: viewModel.itemWidths[index], height: Self.height)
            button.tag = index
            button.target = self
            button.action = #selector(rowClicked(_:))
            strip.addSubview(button)
        }
    }

    @objc private func rowClicked(_ sender: NSButton) {
        viewModel.click(rowAt: sender.tag).map(onRowClick)
    }
}
