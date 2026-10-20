/// The layout to start a session with and what to tell the user about it.
public struct StartupLayout: Equatable, Sendable {
    public let layout: Layout
    public let notice: String?
}

/// Why `AppComposition.apply` did not start. Nothing was moved or saved.
public enum ApplyRefusal: Equatable, Sendable {
    /// An icon clicked earlier is still away from its place and could not be put back, so a plan
    /// made now would be undone by the late return.
    case displacedIconPending
}

/// The order in which the app's parts work together; the AppKit layer only calls it.
///
/// Icons the separator pushed off screen cannot be seen, located or dragged, so everything that
/// reads or moves them runs with the separator revealed, then puts it back the way it was.
/// The app's own status items are kept out of the layout and out of move plans (`OwnItems`).
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
    private let discoverInBackground: @Sendable () async -> [DiscoveredItem]
    /// Reads in `discoverRevealedInBackground` that have not finished.
    private var backgroundReads = 0
    /// Whether the separator was hiding when the first of those reads began.
    private var revealedForBackgroundReads = false

    /// `locator` reads the separator's frame to tell when the bar has settled. `discover` reads
    /// the bar on the main thread, where moves run; `discoverInBackground` reads it anywhere else.
    public init(
        separator: SeparatorController, clickProxy: ClickProxy, clock: any MoveClock,
        locator: any ItemLocating, uptime: @escaping Uptime = systemUptimeMilliseconds,
        discover: @escaping @MainActor () -> [DiscoveredItem],
        discoverInBackground: @escaping @Sendable () async -> [DiscoveredItem]
    ) {
        self.separator = separator
        self.clickProxy = clickProxy
        self.clock = clock
        self.locator = locator
        self.uptime = uptime
        self.discover = discover
        self.discoverInBackground = discoverInBackground
        // The proxy's own timeout restore would drag towards an off-screen anchor.
        clickProxy.onRestoreTimeout = { [weak self] in self?.restoreIfDisplaced() }
    }

    /// Runs `body` with the separator showing everything. A hiding separator is shown first,
    /// given time to settle, and hidden again afterwards; a shown one is left alone.
    public func withRevealed<Result>(_ body: () -> Result) -> Result {
        guard separator.state == .hiding else { return body() }
        separator.show()
        awaitSettledBar()
        defer { separator.hide() }
        return body()
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

    /// Every item on the bar, hidden ones included, for a group panel to match its rows against.
    public func discoverRevealed() -> [DiscoveredItem] {
        withRevealed { discover() }
    }

    /// `discoverRevealed` with the read off the main thread. The bar stays revealed while it runs,
    /// so reads that overlap share the reveal and the last one to finish hides the separator again.
    public func discoverRevealedInBackground() async -> [DiscoveredItem] {
        backgroundReads += 1
        if separator.state == .hiding {
            separator.show()
            revealedForBackgroundReads = true
            awaitSettledBar()
        }
        let items = await discoverInBackground()
        backgroundReads -= 1
        if backgroundReads == 0 && revealedForBackgroundReads {
            revealedForBackgroundReads = false
            separator.hide()
        }
        return items
    }

    /// Flips the separator and answers with its new state. Ignored while a background read has the
    /// bar revealed: its end would undo the choice.
    public func toggleSeparator() -> SeparatorState {
        if backgroundReads == 0 { separator.toggle() }
        return separator.state
    }

    /// The bar as `SettingsViewModel` plans moves on it.
    public func barItems() -> [MenuBarItem] {
        OwnItems.planItems(discover())
    }

    /// The stored layout, topped up with the icons on the bar now. A layout that cannot be read
    /// or understood becomes an empty one, with the reason in `notice`; the store is never written.
    ///
    /// Throws only what `LayoutReconciler` throws, which a valid stored layout cannot provoke.
    public func startupLayout(from store: LayoutStore) throws -> StartupLayout {
        let stored: LayoutLoadResult
        do {
            stored = try store.load()
        } catch let error as LayoutStoreError {
            return StartupLayout(layout: .empty, notice: UserMessages.text(for: error))
        }
        let found = OwnItems.foreign(discoverRevealed())
        return StartupLayout(
            layout: try LayoutReconciler.reconcile(discovered: found, stored: stored.layout),
            notice: UserMessages.notice(for: stored.status))
    }

    /// Arranges the bar after the draft of `settings`. An icon still displaced by a click goes home
    /// first: its late return would drag it to an anchor the new arrangement has moved.
    public func apply(_ settings: SettingsViewModel) -> ApplyRefusal? {
        withRevealed { () -> ApplyRefusal? in
            guard clickProxy.restoreIfDisplaced() != .failed else { return .displacedIconPending }
            settings.apply()
            return nil
        }
    }

    /// Clicks a hidden icon. An icon still away from an earlier click is brought home first.
    public func click(_ id: MenuBarItemID) -> ClickOutcome {
        withRevealed {
            if clickProxy.hasDisplacedItem { clickProxy.restoreIfDisplaced() }
            return clickProxy.click(id, among: discover())
        }
    }

    /// Brings a displaced icon home. Call when a group panel opens or closes.
    @discardableResult
    public func restoreIfDisplaced() -> RestoreOutcome {
        guard clickProxy.hasDisplacedItem else { return .nothingToRestore }
        return withRevealed { clickProxy.restoreIfDisplaced() }
    }
}
