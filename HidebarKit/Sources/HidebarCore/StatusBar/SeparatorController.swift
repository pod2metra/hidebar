import Foundation

public enum SeparatorState: Sendable, Equatable {
    case shown
    case hiding

    /// SF Symbol of the toggle that sits next to the separator: it points at the side the
    /// hidden icons are on while they are hidden.
    public var toggleSymbolName: String {
        switch self {
        case .shown: "chevron.right"
        case .hiding: "chevron.left"
        }
    }
}

/// Hides menu-bar icons by stretching the separator so everything left of it
/// is pushed off-screen. The length is restored to `normalLength` on
/// termination and again at the next launch, so a crash cannot leave icons hidden.
@MainActor
public final class SeparatorController {
    /// Matches `NSStatusItem.variableLength`.
    public static let normalLength: Double = -1
    public static let hidingLength: Double = 10_000

    public private(set) var state: SeparatorState = .shown

    private let item: any StatusItemControlling
    private let clock: any SchedulingClock
    private var autoHide: (any Cancellable)?

    public init(item: any StatusItemControlling, clock: any SchedulingClock) {
        self.item = item
        self.clock = clock
    }

    /// Call first thing at launch: the previous run may have died while hiding.
    public func prepareForLaunch() {
        item.length = Self.normalLength
        item.isVisible = true
        cancelAutoHide()
        state = .shown
    }

    /// Call first thing on termination: restoring the length precedes everything else.
    public func prepareForTermination() {
        item.length = Self.normalLength
        cancelAutoHide()
        state = .shown
    }

    public func hide() {
        cancelAutoHide()
        guard state == .shown else { return }
        item.length = Self.hidingLength
        state = .hiding
    }

    /// Reveals the icons; with `autoHideAfter` they hide again after that many seconds.
    public func show(autoHideAfter delay: TimeInterval? = nil) {
        cancelAutoHide()
        if state == .hiding {
            item.length = Self.normalLength
            state = .shown
        }
        guard let delay else { return }
        autoHide = clock.schedule(after: delay) { [weak self] in self?.hide() }
    }

    public func toggle(autoHideAfter delay: TimeInterval? = nil) {
        switch state {
        case .shown: hide()
        case .hiding: show(autoHideAfter: delay)
        }
    }

    private func cancelAutoHide() {
        autoHide?.cancel()
        autoHide = nil
    }
}
