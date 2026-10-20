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
    /// Time the bar needs after the separator changes length before the icons are where they
    /// will be read from.
    public static let settleMilliseconds = 150

    private let separator: SeparatorController
    private let clickProxy: ClickProxy
    private let clock: any MoveClock
    private let discover: @MainActor () -> [DiscoveredItem]

    public init(
        separator: SeparatorController, clickProxy: ClickProxy, clock: any MoveClock,
        discover: @escaping @MainActor () -> [DiscoveredItem]
    ) {
        self.separator = separator
        self.clickProxy = clickProxy
        self.clock = clock
        self.discover = discover
        // The proxy's own timeout restore would drag towards an off-screen anchor.
        clickProxy.onRestoreTimeout = { [weak self] in self?.restoreIfDisplaced() }
    }

    /// Runs `body` with the separator showing everything. A hiding separator is shown first,
    /// given time to settle, and hidden again afterwards; a shown one is left alone.
    public func withRevealed<Result>(_ body: () -> Result) -> Result {
        guard separator.state == .hiding else { return body() }
        separator.show()
        clock.wait(milliseconds: Self.settleMilliseconds)
        defer { separator.hide() }
        return body()
    }

    /// Every item on the bar, hidden ones included, for a group panel to match its rows against.
    public func discoverRevealed() -> [DiscoveredItem] {
        withRevealed { discover() }
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
