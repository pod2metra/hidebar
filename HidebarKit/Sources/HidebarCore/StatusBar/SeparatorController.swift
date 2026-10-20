import Foundation

public enum SeparatorState: Sendable, Equatable {
    case shown
    case hiding

    /// SF Symbol of the arrow next to the pipe: it points at the side the hidden icons are on
    /// while they are hidden.
    public var arrowSymbolName: String {
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

    public init(item: any StatusItemControlling) {
        self.item = item
    }

    /// Call first thing at launch: the previous run may have died while hiding.
    public func prepareForLaunch() {
        item.length = Self.normalLength
        item.isVisible = true
        state = .shown
    }

    /// Call first thing on termination: restoring the length precedes everything else.
    public func prepareForTermination() {
        item.length = Self.normalLength
        state = .shown
    }

    public func hide() {
        guard state == .shown else { return }
        item.length = Self.hidingLength
        state = .hiding
    }

    public func show() {
        guard state == .hiding else { return }
        item.length = Self.normalLength
        state = .shown
    }
}
