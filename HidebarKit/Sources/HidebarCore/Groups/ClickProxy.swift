import Foundation

public enum ClickRefusal: Equatable, Sendable {
    /// A previous icon is still away from its place; `menuDidClose()` returns it first.
    case displacedItemPending
    case notManaged
    case unmovable
    /// No managed neighbour to return the icon to.
    case noHomeAnchor
    case notLocated
}

public enum ClickOutcome: Equatable, Sendable {
    /// Revealed and clicked; the icon stays out until `menuDidClose()`.
    case clicked
    /// Refused before any event was posted.
    case refused(ClickRefusal)
    case revealFailed
    case clickFailed
}

public enum RestoreOutcome: Equatable, Sendable {
    case nothingToRestore
    case restored
    /// The icon is still away; `menuDidClose()` can be called again.
    case failed
}

/// Clicks an icon that is not within reach: moves it next to the separator, clicks
/// it, and moves it back once its menu is closed. On every path that leaves the icon
/// away from its place `hasDisplacedItem` stays true until a restore succeeds.
///
/// A clicked icon also returns by itself when `menuDidClose()` is not called within
/// `restoreTimeout`: the closing of a foreign menu is not observable, so it cannot be the only
/// trigger. Dragging the icon away while its menu is open would close the menu, so while
/// `isMenuOpen` says one is, the timeout starts over instead, but never past `maxDisplacement` in
/// total: a probe that keeps reporting a menu (a foreign window stuck on the menu layer) must not
/// keep the icon away for good.
@MainActor
public final class ClickProxy {
    private struct Displaced {
        let item: MenuBarItem
        let originX: Double
        let homeAnchor: MenuBarItemID
        let homeSide: DropSide
    }

    private let executor: MoveExecutor
    private let poster: any EventPosting
    private let locator: any ItemLocating
    private let separator: MenuBarItemID
    private let revealSide: DropSide
    private let clock: any SchedulingClock
    private let deadline: MoveDeadline
    private let isMenuOpen: @MainActor () -> Bool
    private let restoreTimeout: TimeInterval
    private let maxDisplacement: TimeInterval
    /// How long the clicked icon has been away: the timeouts armed since the click.
    private var displacedFor: TimeInterval = 0
    private var displaced: Displaced?
    private var restoreTimer: (any Cancellable)?

    public var hasDisplacedItem: Bool { displaced != nil }

    /// Runs, instead of the proxy's own restore, when `restoreTimeout` passes without
    /// `menuDidClose()`. A composition sets it to restore with the separator revealed, which the
    /// proxy cannot do itself: the icon's home may be off screen.
    public var onRestoreTimeout: (@MainActor () -> Void)?

    /// `revealSide` is the side of `separator` where icons are on screen. `deadline` is the one
    /// the executor holds: it bounds the events from the reveal to the end of the click.
    /// It has no default, so a composition cannot leave rule 4 unbounded by forgetting it.
    /// `isMenuOpen` tells whether any menu is open on screen; it has no default either, so the
    /// timeout cannot silently go back to closing a menu under the user. After `maxDisplacement`
    /// seconds in all, the icon is restored whatever the probe says.
    public init(
        executor: MoveExecutor, poster: any EventPosting, locator: any ItemLocating,
        separator: MenuBarItemID, revealSide: DropSide, clock: any SchedulingClock,
        deadline: MoveDeadline, isMenuOpen: @escaping @MainActor () -> Bool,
        restoreTimeout: TimeInterval = 10, maxDisplacement: TimeInterval = 120
    ) {
        self.executor = executor
        self.poster = poster
        self.locator = locator
        self.separator = separator
        self.revealSide = revealSide
        self.clock = clock
        self.deadline = deadline
        self.isMenuOpen = isMenuOpen
        self.restoreTimeout = restoreTimeout
        self.maxDisplacement = maxDisplacement
    }

    public func click(_ id: MenuBarItemID, among items: [DiscoveredItem]) -> ClickOutcome {
        guard displaced == nil else { return .refused(.displacedItemPending) }
        guard let found = items.managedItem(id) else { return .refused(.notManaged) }
        guard found.item.isMovable else { return .refused(.unmovable) }
        guard let home = Self.homeAnchor(of: found, among: items) else { return .refused(.noHomeAnchor) }
        guard let origin = locator.frame(of: id) else { return .refused(.notLocated) }
        displaced = Displaced(
            item: found.item, originX: origin.x, homeAnchor: home.anchor, homeSide: home.side)
        // One deadline around reveal, click and cursor restore.
        deadline.begin()
        defer { deadline.end() }
        let reveal = RevealPlanner.step(
            for: found, among: items, separator: separator, side: revealSide)
        if let reveal, executor.move(reveal) != .moved {
            returnHome()
            return .revealFailed
        }
        guard postClick(on: id) else {
            returnHome()
            return .clickFailed
        }
        displacedFor = 0
        armRestoreTimer()
        return .clicked
    }

    /// Call when the clicked icon's menu has closed. Withdraws the timeout restore.
    @discardableResult
    public func menuDidClose() -> RestoreOutcome {
        restoreTimer?.cancel()
        restoreTimer = nil
        return returnHome()
    }

    /// Brings a displaced icon home now. The app calls it whenever a group panel opens or closes:
    /// a restore that failed (on the timeout or on `menuDidClose()`) leaves the icon pending and
    /// refuses every further click, and nothing else would retry it. Does nothing when no icon is away.
    @discardableResult
    public func restoreIfDisplaced() -> RestoreOutcome {
        menuDidClose()
    }

    private func armRestoreTimer() {
        displacedFor += restoreTimeout
        restoreTimer = clock.schedule(after: restoreTimeout) { [weak self] in self?.restoreTimedOut() }
    }

    /// The probe is not asked once another timeout would pass `maxDisplacement`.
    private func restoreTimedOut() {
        let mayWaitLonger = displacedFor + restoreTimeout <= maxDisplacement
        guard !mayWaitLonger || !isMenuOpen() else {
            armRestoreTimer()
            return
        }
        guard let handler = onRestoreTimeout else {
            menuDidClose()
            return
        }
        handler()
    }

    @discardableResult
    private func returnHome() -> RestoreOutcome {
        guard let away = displaced else { return .nothingToRestore }
        guard isAway(away) else {
            displaced = nil
            return .nothingToRestore
        }
        let step = MoveStep(item: away.item, anchor: away.homeAnchor, side: away.homeSide)
        guard executor.move(step) == .moved else { return .failed }
        displaced = nil
        return .restored
    }

    /// A vanished icon counts as home: there is nothing left to drag.
    private func isAway(_ away: Displaced) -> Bool {
        guard let now = locator.frame(of: away.item.id) else { return false }
        return now.x != away.originX
    }

    private func postClick(on id: MenuBarItemID) -> Bool {
        guard let frame = locator.frame(of: id), !deadline.isOverdue else { return false }
        let savedCursor = poster.cursorPosition()
        defer { poster.setCursorPosition(savedCursor) }
        return poster.postClick(
            at: CursorPoint(x: frame.x + frame.width / 2, y: frame.y + frame.height / 2))
    }

    /// The neighbour to drop the icon beside when returning it: the nearest managed
    /// icon to its right, else the nearest to its left.
    private static func homeAnchor(
        of found: DiscoveredItem, among items: [DiscoveredItem]
    ) -> (anchor: MenuBarItemID, side: DropSide)? {
        let x = found.item.frame.x
        let others = items.filter { $0.isManaged && $0.item.id != found.item.id }
        if let right = others.filter({ $0.item.frame.x > x }).min(by: { $0.item.frame.x < $1.item.frame.x }) {
            return (right.item.id, .leftOf)
        }
        if let left = others.max(by: { $0.item.frame.x < $1.item.frame.x }) {
            return (left.item.id, .rightOf)
        }
        return nil
    }
}
