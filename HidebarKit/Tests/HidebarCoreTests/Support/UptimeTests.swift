import Foundation
import Testing

@testable import HidebarCore

@Suite struct UptimeTests {
    @Test func systemUptimeAdvancesWithRealTimeInMilliseconds() {
        let before = systemUptimeMilliseconds()
        Thread.sleep(forTimeInterval: 0.05)
        let elapsed = systemUptimeMilliseconds() - before
        // Bounded on both sides: seconds or microseconds would fall outside.
        #expect(elapsed >= 40)
        #expect(elapsed < 5000)
    }
}
