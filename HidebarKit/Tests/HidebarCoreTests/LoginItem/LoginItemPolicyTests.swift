import Testing

@testable import HidebarCore

private struct Failure: Error, Equatable {}

private final class FakeLoginItem: LoginItemControlling {
    var status: LoginItemStatus
    var registerFailure: Failure?
    var unregisterFailure: Failure?
    /// Calls of the item and of the store, in order.
    var calls: [String]

    init(status: LoginItemStatus, calls: [String] = []) {
        self.status = status
        self.calls = calls
    }

    func register() throws {
        calls.append("register")
        if let registerFailure { throw registerFailure }
    }

    func unregister() throws {
        calls.append("unregister")
        if let unregisterFailure { throw unregisterFailure }
    }

    func openSettings() {
        calls.append("openSettings")
    }
}

private final class FakeOffers: LoginItemOfferStoring {
    var wasOffered: Bool
    private let item: FakeLoginItem

    init(wasOffered: Bool, item: FakeLoginItem) {
        self.wasOffered = wasOffered
        self.item = item
    }

    func markOffered() {
        wasOffered = true
        item.calls.append("markOffered")
    }
}

@Suite struct LoginItemPolicyTests {
    private func make(status: LoginItemStatus, offered: Bool = false)
        -> (policy: LoginItemPolicy, item: FakeLoginItem, offers: FakeOffers)
    {
        let item = FakeLoginItem(status: status)
        let offers = FakeOffers(wasOffered: offered, item: item)
        return (LoginItemPolicy(item: item, offers: offers), item, offers)
    }

    @Test func theFirstLaunchRegistersThenMarksTheOffer() {
        let (policy, item, offers) = make(status: .notRegistered)
        #expect(policy.onLaunch() == nil)
        #expect(item.calls == ["register", "markOffered"])
        #expect(offers.wasOffered)
    }

    @Test func aLaunchAfterTheOfferTouchesNothing() {
        let (policy, item, offers) = make(status: .notRegistered, offered: true)
        #expect(policy.onLaunch() == nil)
        #expect(item.calls.isEmpty)
        #expect(offers.wasOffered)
    }

    @Test func aFailedRegistrationStillMarksTheOfferAndIsReturned() {
        let (policy, item, offers) = make(status: .notRegistered)
        item.registerFailure = Failure()
        #expect(policy.onLaunch() as? Failure == Failure())
        #expect(item.calls == ["register", "markOffered"])
        #expect(offers.wasOffered)
    }

    @Test func togglingAnEnabledItemUnregistersIt() {
        let (policy, item, _) = make(status: .enabled)
        #expect(policy.toggle() == nil)
        #expect(item.calls == ["unregister"])
    }

    @Test func togglingAnItemThatWaitsForApprovalOpensTheSettings() {
        let (policy, item, _) = make(status: .requiresApproval)
        #expect(policy.toggle() == nil)
        #expect(item.calls == ["openSettings"])
    }

    @Test func togglingAnItemThatIsOffRegistersIt() {
        for status in [LoginItemStatus.notRegistered, .notFound] {
            let (policy, item, _) = make(status: status)
            #expect(policy.toggle() == nil)
            #expect(item.calls == ["register"])
        }
    }

    @Test func aToggleFailureIsReturnedNotThrown() {
        let (enabled, enabledItem, _) = make(status: .enabled)
        enabledItem.unregisterFailure = Failure()
        #expect(enabled.toggle() as? Failure == Failure())

        let (off, offItem, _) = make(status: .notRegistered)
        offItem.registerFailure = Failure()
        #expect(off.toggle() as? Failure == Failure())
    }

    @Test func aToggleNeverTouchesTheOfferFlag() {
        let (policy, item, offers) = make(status: .notRegistered)
        _ = policy.toggle()
        #expect(!offers.wasOffered)
        #expect(!item.calls.contains("markOffered"))
    }

    @Test func theMenuShowsTheCheckMarkOfEachStatus() {
        #expect(LoginItemPolicy.menuState(for: .enabled) == .on)
        #expect(LoginItemPolicy.menuState(for: .requiresApproval) == .mixed)
        #expect(LoginItemPolicy.menuState(for: .notRegistered) == .off)
        #expect(LoginItemPolicy.menuState(for: .notFound) == .off)
    }

    @Test func theMenuStatesCarryTheValuesOfNSControlStateValue() {
        #expect(LoginItemMenuState.on.rawValue == 1)
        #expect(LoginItemMenuState.mixed.rawValue == -1)
        #expect(LoginItemMenuState.off.rawValue == 0)
    }

    @Test func theSystemStatusMapsByItsRawValue() {
        #expect(LoginItemStatus(serviceStatusRawValue: 0) == .notRegistered)
        #expect(LoginItemStatus(serviceStatusRawValue: 1) == .enabled)
        #expect(LoginItemStatus(serviceStatusRawValue: 2) == .requiresApproval)
        #expect(LoginItemStatus(serviceStatusRawValue: 3) == .notFound)
    }

    @Test func aStatusTheAppDoesNotKnowReadsAsNotFound() {
        #expect(LoginItemStatus(serviceStatusRawValue: 4) == .notFound)
        #expect(LoginItemStatus(serviceStatusRawValue: -1) == .notFound)
    }
}
