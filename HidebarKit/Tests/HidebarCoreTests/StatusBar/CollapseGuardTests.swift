import Testing

@testable import HidebarCore

@Suite struct CollapseGuardTests {
    @Test func aPipeWithoutAFrameIsRefused() {
        #expect(CollapseGuard.check(pipeX: nil, arrowX: nil) == .separatorNotOnBar)
        #expect(CollapseGuard.check(pipeX: nil, arrowX: 150) == .separatorNotOnBar)
    }

    @Test func theLiveBugAnArrowLeftOfThePipeIsRefused() {
        // [icon, arrow, MAIN]: the arrow at 50 is left of the pipe at 100.
        #expect(CollapseGuard.check(pipeX: 100, arrowX: 50) == .arrowWouldHide)
        #expect(CollapseGuard.check(pipeX: 100, arrowX: 99.5) == .arrowWouldHide)
    }

    @Test func anArrowAtOrRightOfThePipeIsAllowed() {
        #expect(CollapseGuard.check(pipeX: 100, arrowX: 100) == nil)
        #expect(CollapseGuard.check(pipeX: 100, arrowX: 150) == nil)
    }

    @Test func anArrowWithoutAFrameStrandsNothing() {
        #expect(CollapseGuard.check(pipeX: 100, arrowX: nil) == nil)
    }
}
