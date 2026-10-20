import Testing

@testable import HidebarCore

@Suite struct OpenMenuProbeTests {
    private func probe(_ windows: [WindowInfo]) -> OpenMenuProbe {
        OpenMenuProbe(windowList: StubWindowList(list: windows))
    }

    @Test func aVisibleWindowOnTheMenuLayerIsAnOpenMenu() {
        #expect(probe([window(1, x: 0, layer: OpenMenuProbe.menuLayer)]).isMenuOpen())
    }

    @Test func menuLayerIsThePopUpMenuLevel() {
        #expect(OpenMenuProbe.menuLayer == 101)
    }

    @Test func noWindowsMeansNoMenu() {
        #expect(!probe([]).isMenuOpen())
    }

    @Test func statusItemAndMenuBarWindowsAreNotMenus() {
        let windows = [window(1, x: 0, layer: 25), window(2, x: 50, layer: 24), window(3, x: 90, layer: 0)]
        #expect(!probe(windows).isMenuOpen())
    }

    @Test func aMenuWindowThatIsNotOnScreenIsNotAnOpenMenu() {
        #expect(!probe([window(1, x: 0, layer: OpenMenuProbe.menuLayer, onscreen: false)]).isMenuOpen())
    }

    @Test func oneMenuAmongOtherWindowsIsFound() {
        let windows = [
            window(1, x: 0, layer: 25), window(2, x: 50, layer: OpenMenuProbe.menuLayer, onscreen: false),
            window(3, x: 90, layer: OpenMenuProbe.menuLayer),
        ]
        #expect(probe(windows).isMenuOpen())
    }
}
