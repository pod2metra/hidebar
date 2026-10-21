import Foundation
import HidebarCore

/// Keeps in the app's defaults that the login item was already offered once.
public struct UserDefaultsOfferStore: LoginItemOfferStoring, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "LoginItemOffered"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var wasOffered: Bool {
        defaults.bool(forKey: key)
    }

    public func markOffered() {
        defaults.set(true, forKey: key)
    }
}
