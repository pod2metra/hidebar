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
/// `restoreTimeout`: the closing of a foreign menu is not observable, so it cannot be the only trigger.
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
    private let restoreTimeout: TimeInterval
    private var displaced: Displaced?
    private var restoreTimer: (any Cancellable)?

    public var hasDisplacedItem: Bool { displaced != nil }

    /// `revealSide` is the side of `separator` where icons are on screen.
    public init(
        executor: MoveExecutor, poster: any EventPosting, locator: any ItemLocating,
        separator: MenuBarItemID, revealSide: DropSide, clock: any SchedulingClock,
        restoreTimeout: TimeInterval = 10
    ) {
        self.executor = executor
        self.poster = poster
        self.locator = locator
        self.separator = separator
        self.revealSide = revealSide
        self.clock = clock
        self.restoreTimeout = restoreTimeout
    }

    public func click(_ id: MenuBarItemID, among items: [DiscoveredItem]) -> ClickOutcome {
        guard displaced == nil else { return .refused(.displacedItemPending) }
        guard let found = items.managedItem(id) else { return .refused(.notManaged) }
        guard found.item.isMovable else { return .refused(.unmovable) }
        guard let home = Self.homeAnchor(of: found, among: items) else { return .refused(.noHomeAnchor) }
        guard let origin = locator.frame(of: id) else { return .refused(.notLocated) }
        displaced = Displaced(
            item: found.item, originX: origin.x, homeAnchor: home.anchor, homeSide: home.side)
        let reveal = MoveStep(item: found.item, anchor: separator, side: revealSide)
        guard executor.move(reveal) == .moved else {
            returnHome()
            return .revealFailed
        }
        guard postClick(on: id) else {
            returnHome()
            return .clickFailed
        }
        restoreTimer = clock.schedule(after: restoreTimeout) { [weak self] in self?.menuDidClose() }
        return .clicked
    }

    /// Call when the clicked icon's menu has closed. Withdraws the timeout restore.
    @discardableResult
    public func menuDidClose() -> RestoreOutcome {
        restoreTimer?.cancel()
        restoreTimer = nil
        return returnHome()
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
        guard let frame = locator.frame(of: id) else { return false }
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
