/// The order in which the app's parts work together; the AppKit layer only calls it.
///
/// Icons the pipe pushed off screen cannot be seen, located or dragged, so everything that reads or
/// moves them runs with the pipe revealed. Where the pipe ends up is decided by one thing, the
/// user's wish (`isCollapsed`): after a reveal it hides iff the user collapsed the section.
/// The app's own status items are never clicked or moved (`OwnItems`).
@MainActor
public final class AppComposition {
    /// Gap between two reads of the separator's frame while the bar re-lays out.
    public static let settlePollMilliseconds = 25
    /// The longest the bar is given to settle; after that the icons are read where they are.
    public static let settleDeadlineMilliseconds = 1000

    private let separator: SeparatorController
    private let clickProxy: ClickProxy
    private let clock: any MoveClock
    private let locator: any ItemLocating
    private let uptime: Uptime
    private let discover: @MainActor () -> [DiscoveredItem]
    /// What the user asked for: the section left of the pipe hidden. The app starts expanded.
    public private(set) var isCollapsed = false

    /// `locator` reads the separator's frame to tell when the bar has settled. `discover` reads
    /// the bar on the main thread, where moves run.
    public init(
        separator: SeparatorController, clickProxy: ClickProxy, clock: any MoveClock,
        locator: any ItemLocating, uptime: @escaping Uptime = systemUptimeMilliseconds,
        discover: @escaping @MainActor () -> [DiscoveredItem]
    ) {
        self.separator = separator
        self.clickProxy = clickProxy
        self.clock = clock
        self.locator = locator
        self.uptime = uptime
        self.discover = discover
        // The proxy's own timeout restore would drag towards an off-screen anchor.
        clickProxy.onRestoreTimeout = { [weak self] in self?.restoreIfDisplaced() }
    }

    /// Hides everything left of the pipe, unless the arrow would be stranded by that. On a refusal
    /// nothing is written and the wish stays as it was. The positions are the items' left edges.
    public func collapse(pipeX: Double?, arrowX: Double?) -> CollapseRefusal? {
        let refusal = CollapseGuard.check(pipeX: pipeX, arrowX: arrowX)
        if refusal != nil { return refusal }
        isCollapsed = true
        separator.hide()
        return nil
    }

    /// Shows what is left of the pipe and keeps it shown.
    public func expand() {
        isCollapsed = false
        separator.show()
    }

    /// Runs `body` with the pipe showing everything. A hiding pipe is shown first, given time to
    /// settle, and hidden again afterwards if the section is collapsed; a shown one is left alone.
    public func withRevealed<Result>(_ body: () -> Result) -> Result {
        guard separator.state == .hiding else { return body() }
        separator.show()
        awaitSettledBar()
        defer { hideIfCollapsed() }
        return body()
    }

    private func hideIfCollapsed() {
        if isCollapsed { separator.hide() }
    }

    /// The bar has settled once the separator's frame is the same in two reads in a row. An
    /// unreadable frame counts as a frame: without Accessibility there is nothing to wait for.
    private func awaitSettledBar() {
        let deadline = uptime() + Self.settleDeadlineMilliseconds
        var frame = locator.frame(of: OwnItems.separatorID)
        while uptime() < deadline {
            clock.wait(milliseconds: Self.settlePollMilliseconds)
            if !separatorMoved(from: &frame) { return }
        }
    }

    /// Reads the separator's frame again into `frame`; true when it differs from the previous one.
    private func separatorMoved(from frame: inout ItemFrame?) -> Bool {
        let current = locator.frame(of: OwnItems.separatorID)
        defer { frame = current }
        return current != frame
    }

    /// Clicks a hidden icon. An icon still away from an earlier click is brought home first.
    public func click(_ id: MenuBarItemID) -> ClickOutcome {
        withRevealed {
            if clickProxy.hasDisplacedItem { clickProxy.restoreIfDisplaced() }
            return clickProxy.click(id, among: discover())
        }
    }

    /// Brings a displaced icon home. Call when a panel closes.
    @discardableResult
    public func restoreIfDisplaced() -> RestoreOutcome {
        guard clickProxy.hasDisplacedItem else { return .nothingToRestore }
        return withRevealed { clickProxy.restoreIfDisplaced() }
    }
}
