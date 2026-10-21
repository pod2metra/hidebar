import Testing

@testable import HidebarCore

@Suite struct PermissionsStateTests {
    @Test func withoutAccessibilityOnlyHidingWorks() {
        let caps = PermissionsState(accessibility: false).capabilities
        #expect(caps.canHide)
        #expect(!caps.canMove)
        #expect(!caps.canIdentifyOwners)
    }

    @Test func accessibilityEnablesMovingAndOwnerIdentification() {
        let caps = PermissionsState(accessibility: true).capabilities
        #expect(caps.canHide)
        #expect(caps.canMove)
        #expect(caps.canIdentifyOwners)
    }
}
