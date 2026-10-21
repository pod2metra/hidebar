import Testing

@testable import HidebarCore

@Suite struct NotchIndicatorTests {
    @Test func nothingHiddenShowsNoIndicatorAndNoTooltip() {
        let indicator = NotchIndicator(hiddenCount: 0, canReach: true)
        #expect(!indicator.isShown)
        #expect(indicator.tooltip == nil)
    }

    @Test func oneHiddenIconShowsTheIndicator() {
        #expect(NotchIndicator(hiddenCount: 1, canReach: true).isShown)
    }

    @Test func theTooltipCountsTheIconsAndPointsAtTheStrip() {
        #expect(
            NotchIndicator(hiddenCount: 1, canReach: true).tooltip
                == "1 icon is behind the notch or the app's menus. Click it in the strip below the menu bar.")
        #expect(
            NotchIndicator(hiddenCount: 3, canReach: true).tooltip
                == "3 icons are behind the notch or the app's menus. Click them in the strip below the menu bar.")
    }

    @Test func withoutAccessibilityTheTooltipPointsAtTheMenuItem() {
        #expect(
            NotchIndicator(hiddenCount: 1, canReach: false).tooltip
                == "1 icon is behind the notch or the app's menus. "
                + "To click it, right-click the arrow and choose Reach Icons Behind the Notch…")
        #expect(
            NotchIndicator(hiddenCount: 2, canReach: false).tooltip
                == "2 icons are behind the notch or the app's menus. "
                + "To click them, right-click the arrow and choose Reach Icons Behind the Notch…")
    }
}
