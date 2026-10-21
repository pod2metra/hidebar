/// Whether the system will start the app at login, as the app tells it apart.
public enum LoginItemStatus: Equatable, Sendable {
    case enabled
    case notRegistered
    /// Registered, but the user has to allow it in System Settings.
    case requiresApproval
    case notFound

    /// Maps the raw value of the system's service status (0 not registered, 1 enabled, 2 requires
    /// approval, 3 not found); a value the app does not know reads as `notFound`.
    public init(serviceStatusRawValue rawValue: Int) {
        let known: [Int: LoginItemStatus] = [
            0: .notRegistered, 1: .enabled, 2: .requiresApproval, 3: .notFound,
        ]
        self = known[rawValue] ?? .notFound
    }
}

/// The check mark of the menu item. The raw values are those of `NSControl.StateValue`.
public enum LoginItemMenuState: Int, Equatable, Sendable {
    case on = 1
    case mixed = -1
    case off = 0
}

/// The system's login item of this app.
public protocol LoginItemControlling {
    var status: LoginItemStatus { get }
    func register() throws
    func unregister() throws
    /// Opens the pane of System Settings where the user allows or removes login items.
    func openSettings()
}

/// Remembers that the app has already turned the login item on once.
public protocol LoginItemOfferStoring {
    var wasOffered: Bool { get }
    func markOffered()
}

/// Opens the app at login by default, once, and lets the user turn it off from the menu.
public struct LoginItemPolicy {
    private let item: any LoginItemControlling
    private let offers: any LoginItemOfferStoring

    public init(item: any LoginItemControlling, offers: any LoginItemOfferStoring) {
        self.item = item
        self.offers = offers
    }

    /// Registers the login item on the first launch only: a user who turned it off in System
    /// Settings is not asked again. The launch counts as offered even when registering failed, so a
    /// failure does not repeat on every launch. Returns the failure, for the caller to log.
    public func onLaunch() -> (any Error)? {
        guard !offers.wasOffered else { return nil }
        let failure = attempt { try item.register() }
        offers.markOffered()
        return failure
    }

    /// The menu item was chosen: turns the login item off when it is on, sends the user to System
    /// Settings when it waits for approval, turns it on otherwise. Returns the failure, if any.
    public func toggle() -> (any Error)? {
        switch item.status {
        case .enabled:
            return attempt { try item.unregister() }
        case .requiresApproval:
            item.openSettings()
            return nil
        case .notRegistered, .notFound:
            return attempt { try item.register() }
        }
    }

    /// The check mark for the status read when the menu opens.
    public static func menuState(for status: LoginItemStatus) -> LoginItemMenuState {
        switch status {
        case .enabled: return .on
        case .requiresApproval: return .mixed
        case .notRegistered, .notFound: return .off
        }
    }

    private func attempt(_ action: () throws -> Void) -> (any Error)? {
        do {
            try action()
            return nil
        } catch {
            return error
        }
    }
}
