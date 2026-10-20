import Foundation

/// The position numbers the system keeps per status item in the app's defaults. Writing one
/// before the item is created decides where the item first appears.
public struct StatusItemPositions: @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// `nil` when the item has no position yet.
    public func position(of autosaveName: String) -> Double? {
        defaults.object(forKey: key(autosaveName)) as? Double
    }

    public func set(_ position: Double, of autosaveName: String) {
        defaults.set(position, forKey: key(autosaveName))
    }

    private func key(_ autosaveName: String) -> String {
        "NSStatusItem Preferred Position \(autosaveName)"
    }
}
