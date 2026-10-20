import Foundation
import HidebarCore

/// The layout bytes in `UserDefaults`, which is documented as thread-safe.
public struct UserDefaultsStore: KeyValueStore, @unchecked Sendable {
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func data(forKey key: String) -> Data? {
        defaults.data(forKey: key)
    }

    /// `UserDefaults` cannot fail a write, so this never throws.
    public func set(_ data: Data, forKey key: String) throws {
        defaults.set(data, forKey: key)
    }
}
