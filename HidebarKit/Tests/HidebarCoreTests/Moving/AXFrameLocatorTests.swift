import Testing

@testable import HidebarCore

@MainActor @Suite struct AXFrameLocatorTests {
    private func locator(_ apps: [FakeAXApp]) -> AXFrameLocator<FakeAXTree> {
        AXFrameLocator(reader: AXMenuBarReader(tree: FakeAXTree(apps: apps), bundleIDOfPID: fakeBundleID))
    }

    private let alphaItem = MenuBarItemID(ownerBundleID: "com.example.alpha", title: "A")
    private let betaItem = MenuBarItemID(ownerBundleID: "com.example.beta", title: "B")

    private var apps: [FakeAXApp] {
        [
            FakeAXApp(items: [FakeAXItem(pid: 10, frame: axFrame(100), title: "A")]),
            FakeAXApp(items: [FakeAXItem(pid: 20, frame: axFrame(200), title: "B")]),
        ]
    }

    @Test func returnsTheFrameOfTheItemWithThatId() {
        let locator = locator(apps)
        #expect(locator.frame(of: alphaItem) == axFrame(100))
        #expect(locator.frame(of: betaItem) == axFrame(200))
    }

    @Test func unknownIdHasNoFrame() {
        let stranger = MenuBarItemID(ownerBundleID: "com.example.alpha", title: "Other")
        #expect(locator(apps).frame(of: stranger) == nil)
    }

    @Test func noAccessibilityAnswerMeansNoFrame() {
        #expect(locator([]).frame(of: alphaItem) == nil)
    }

    @Test func idSharedByTwoItemsIsNotLocated() {
        let twin = FakeAXApp(items: [
            FakeAXItem(pid: 10, frame: axFrame(100), title: "A"),
            FakeAXItem(pid: 10, frame: axFrame(300), title: "A"),
        ])
        #expect(locator([twin]).frame(of: alphaItem) == nil)
    }

    @Test func itemOffTheScreenIsStillLocated() {
        let hidden = FakeAXApp(items: [FakeAXItem(pid: 10, frame: axFrame(-2000), title: "A")])
        #expect(locator([hidden]).frame(of: alphaItem) == axFrame(-2000))
    }
}
