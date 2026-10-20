import Testing

@testable import HidebarCore

@Suite struct PermissionsStateTests {
    private static let none = PermissionsState(accessibility: false, screenRecording: false)
    private static let axOnly = PermissionsState(accessibility: true, screenRecording: false)
    private static let srOnly = PermissionsState(accessibility: false, screenRecording: true)
    private static let both = PermissionsState(accessibility: true, screenRecording: true)

    @Test func nothingGrantedOnlyHides() {
        let caps = Self.none.capabilities
        #expect(caps.canHide)
        #expect(!caps.canMove)
        #expect(!caps.canIdentifyOwners)
        #expect(!caps.canSnapshot)
        #expect(caps.panelPresentation == .appNameAndIcon)
        #expect(Self.none.missingRequired == [.accessibility])
    }

    @Test func accessibilityOnlyMovesWithoutSnapshots() {
        let caps = Self.axOnly.capabilities
        #expect(caps.canHide)
        #expect(caps.canMove)
        #expect(caps.canIdentifyOwners)
        #expect(!caps.canSnapshot)
        #expect(caps.panelPresentation == .appNameAndIcon)
        #expect(Self.axOnly.missingRequired.isEmpty)
    }

    @Test func screenRecordingOnlySnapshotsWithoutMoving() {
        let caps = Self.srOnly.capabilities
        #expect(caps.canHide)
        #expect(!caps.canMove)
        #expect(!caps.canIdentifyOwners)
        #expect(caps.canSnapshot)
        #expect(caps.panelPresentation == .snapshots)
        #expect(Self.srOnly.missingRequired == [.accessibility])
    }

    @Test func everythingGrantedEnablesAll() {
        let caps = Self.both.capabilities
        #expect(caps.canHide)
        #expect(caps.canMove)
        #expect(caps.canIdentifyOwners)
        #expect(caps.canSnapshot)
        #expect(caps.panelPresentation == .snapshots)
        #expect(Self.both.missingRequired.isEmpty)
    }

    @Test func onlyAccessibilityIsRequired() {
        #expect(Permission.accessibility.isRequired)
        #expect(!Permission.screenRecording.isRequired)
    }

    @Test func isGrantedReadsEachPermission() {
        #expect(Self.axOnly.isGranted(.accessibility))
        #expect(!Self.axOnly.isGranted(.screenRecording))
        #expect(!Self.srOnly.isGranted(.accessibility))
        #expect(Self.srOnly.isGranted(.screenRecording))
    }

    @Test func gainingBothReportsOnboardingOrder() {
        let change = Self.both.transition(from: Self.none)
        #expect(change.gained == [.accessibility, .screenRecording])
        #expect(change.lost.isEmpty)
    }

    @Test func gainingOneReportsOnlyThatOne() {
        #expect(Self.axOnly.transition(from: Self.none) == PermissionsTransition(gained: [.accessibility], lost: []))
        #expect(Self.srOnly.transition(from: Self.none) == PermissionsTransition(gained: [.screenRecording], lost: []))
    }

    @Test func revokedScreenRecordingIsLost() {
        let change = Self.axOnly.transition(from: Self.both)
        #expect(change.gained.isEmpty)
        #expect(change.lost == [.screenRecording])
    }

    @Test func losingBothReportsOnboardingOrder() {
        let change = Self.none.transition(from: Self.both)
        #expect(change.gained.isEmpty)
        #expect(change.lost == [.accessibility, .screenRecording])
    }

    @Test func swappingPermissionsReportsGainAndLoss() {
        let change = Self.srOnly.transition(from: Self.axOnly)
        #expect(change.gained == [.screenRecording])
        #expect(change.lost == [.accessibility])
    }

    @Test func unchangedStateReportsNothing() {
        for state in [Self.none, Self.axOnly, Self.srOnly, Self.both] {
            #expect(state.transition(from: state) == PermissionsTransition(gained: [], lost: []))
        }
    }
}
