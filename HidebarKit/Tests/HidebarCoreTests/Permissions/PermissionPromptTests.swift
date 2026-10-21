import Testing

@testable import HidebarCore

@Suite struct PermissionPromptTests {
    @Test func accessibilityPointsAtItsPrivacyPane() {
        let prompt = PermissionPrompt.accessibility
        #expect(prompt.title == "Accessibility")
        #expect(prompt.settingsURL.hasPrefix("x-apple.systempreferences:"))
        #expect(prompt.settingsURL.hasSuffix("Privacy_Accessibility"))
        #expect(prompt.detail.contains("not clickable"))
    }
}
