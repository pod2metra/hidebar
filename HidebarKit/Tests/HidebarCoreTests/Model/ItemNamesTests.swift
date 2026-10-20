import Testing

@testable import HidebarCore

struct StubAppNames: AppNaming {
    var names: [String: String] = [:]
    func name(ofBundleID bundleID: String) -> String? { names[bundleID] }
}

/// Names for tests that do not care: no app is known, so every id reads as its bundle id.
let unknownApps = ItemNames(apps: StubAppNames())

@Suite struct ItemNamesTests {
    private let names = ItemNames(
        apps: StubAppNames(names: [
            "info.marcel-dierkes.KeepingYouAwake": "KeepingYouAwake",
            "com.apple.controlcenter": "Control Center",
            "com.example.blank": "",
        ]))

    private func name(_ bundleID: String, _ title: String = "") -> String {
        names.name(of: MenuBarItemID(ownerBundleID: bundleID, title: title))
    }

    @Test func untitledItemIsNamedAfterItsApp() {
        #expect(name("info.marcel-dierkes.KeepingYouAwake") == "KeepingYouAwake")
    }

    @Test func titleThatDiffersFromTheAppNameFollowsIt() {
        #expect(name("com.apple.controlcenter", "Wi-Fi") == "Control Center — Wi-Fi")
    }

    @Test func titleThatRepeatsTheAppNameIsNotRepeated() {
        #expect(name("info.marcel-dierkes.KeepingYouAwake", "KeepingYouAwake") == "KeepingYouAwake")
        #expect(name("info.marcel-dierkes.KeepingYouAwake", "keepingyouawake") == "KeepingYouAwake")
    }

    @Test func unknownAppFallsBackToItsBundleID() {
        #expect(name("com.example.gone") == "com.example.gone")
        #expect(name("com.example.gone", "Status") == "com.example.gone — Status")
    }

    @Test func emptyAppNameCountsAsUnknown() {
        #expect(name("com.example.blank") == "com.example.blank")
    }
}
