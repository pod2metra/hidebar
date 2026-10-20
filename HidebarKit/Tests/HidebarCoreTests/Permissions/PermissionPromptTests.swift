import Testing

@testable import HidebarCore

@Suite struct PermissionPromptTests {
    @Test func accessibilityPointsAtItsPrivacyPane() {
        let prompt = PermissionPrompt.prompt(for: .accessibility)
        #expect(prompt.title == "Accessibility")
        #expect(prompt.settingsURL.hasSuffix("Privacy_Accessibility"))
        #expect(prompt.detail.contains("not clickable"))
    }

    @Test func screenRecordingPointsAtItsPrivacyPane() {
        let prompt = PermissionPrompt.prompt(for: .screenRecording)
        #expect(prompt.title == "Screen Recording")
        #expect(prompt.settingsURL.hasSuffix("Privacy_ScreenCapture"))
        #expect(prompt.detail.contains("app names"))
        #expect(prompt.detail.contains("Optional"))
    }

    @Test func everyPermissionHasADistinctPane() {
        let urls = Permission.allCases.map { PermissionPrompt.prompt(for: $0).settingsURL }
        #expect(Set(urls).count == Permission.allCases.count)
        #expect(urls.allSatisfy { $0.hasPrefix("x-apple.systempreferences:") })
    }
}
