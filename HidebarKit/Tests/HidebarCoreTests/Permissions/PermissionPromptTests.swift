import Testing

@testable import HidebarCore

@Suite struct PermissionPromptTests {
    @Test func accessibilityPointsAtItsPrivacyPane() {
        let prompt = PermissionPrompt.accessibility
        #expect(prompt.title == "Accessibility")
        #expect(prompt.settingsURL.hasPrefix("x-apple.systempreferences:"))
        #expect(prompt.settingsURL.hasSuffix("Privacy_Accessibility"))
    }

    @Test func theDetailSaysWhyItIsAskedForAndWhatWorksWithoutIt() {
        let detail = PermissionPrompt.accessibility.detail
        #expect(detail.contains("behind the notch"))
        #expect(detail.contains("puts it back"))
        #expect(detail.contains("works without it"))
    }

    @Test func theRequestIsNeededOnlyWhileAccessibilityIsOff() {
        #expect(PermissionPrompt.isNeeded(in: PermissionsState(accessibility: false)))
        #expect(!PermissionPrompt.isNeeded(in: PermissionsState(accessibility: true)))
    }

    @Test func theMenuOffersTheRequestOnlyWhileAccessibilityIsOff() {
        #expect(
            PermissionPrompt.reachIconsMenuTitle(for: PermissionsState(accessibility: false))
                == "Reach Icons Behind the Notch…")
        #expect(PermissionPrompt.reachIconsMenuTitle(for: PermissionsState(accessibility: true)) == nil)
    }
}
