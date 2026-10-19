import Testing

@testable import HidebarCore

@Suite struct ScrollModelTests {
    @Test func maxOffsetIsContentMinusViewport() {
        let model = ScrollModel(contentWidth: 300, viewportWidth: 100)
        #expect(model.maxOffset == 200)
        #expect(model.offset == 0)
    }

    @Test func viewportLargerThanContentCannotScroll() {
        var model = ScrollModel(contentWidth: 50, viewportWidth: 100)
        #expect(model.maxOffset == 0)
        model.apply(deltaX: 30)
        #expect(model.offset == 0)
    }

    @Test func applyMovesOffset() {
        var model = ScrollModel(contentWidth: 300, viewportWidth: 100)
        model.apply(deltaX: 30)
        model.apply(deltaX: 20)
        #expect(model.offset == 50)
        model.apply(deltaX: -10)
        #expect(model.offset == 40)
    }

    @Test func applyClampsAtEnd() {
        var model = ScrollModel(contentWidth: 300, viewportWidth: 100)
        model.apply(deltaX: 500)
        #expect(model.offset == 200)
    }

    @Test func applyClampsAtStart() {
        var model = ScrollModel(contentWidth: 300, viewportWidth: 100, offset: 20)
        model.apply(deltaX: -500)
        #expect(model.offset == 0)
    }

    @Test func initClampsOffsetBeyondBounds() {
        #expect(ScrollModel(contentWidth: 300, viewportWidth: 100, offset: 999).offset == 200)
        #expect(ScrollModel(contentWidth: 300, viewportWidth: 100, offset: -5).offset == 0)
        #expect(ScrollModel(contentWidth: 300, viewportWidth: 100, offset: 150).offset == 150)
    }

    @Test func zeroItemsHaveEmptyVisibleRange() {
        let model = ScrollModel(contentWidth: 0, viewportWidth: 100)
        #expect(model.visibleRange(itemWidths: [], spacing: 5) == 0..<0)
    }

    @Test func everythingVisibleWhenViewportCoversContent() {
        let model = ScrollModel(contentWidth: 50, viewportWidth: 100)
        #expect(model.visibleRange(itemWidths: [20, 20], spacing: 5) == 0..<2)
    }

    @Test func rangeAtStartCutsItemsBeyondViewport() {
        // Items span 0-40, 50-90, 100-140, 150-190.
        let model = ScrollModel(contentWidth: 190, viewportWidth: 100)
        #expect(model.visibleRange(itemWidths: [40, 40, 40, 40], spacing: 10) == 0..<2)
    }

    @Test func rangeInMiddleIncludesPartiallyVisibleItems() {
        var model = ScrollModel(contentWidth: 190, viewportWidth: 100)
        model.apply(deltaX: 60)  // viewport 60-160
        #expect(model.visibleRange(itemWidths: [40, 40, 40, 40], spacing: 10) == 1..<4)
    }

    @Test func rangeAtEndDropsLeadingItems() {
        var model = ScrollModel(contentWidth: 190, viewportWidth: 100)
        model.apply(deltaX: 999)  // viewport 90-190
        #expect(model.visibleRange(itemWidths: [40, 40, 40, 40], spacing: 10) == 2..<4)
    }

    @Test func itemTouchingViewportEdgeIsNotVisible() {
        var model = ScrollModel(contentWidth: 190, viewportWidth: 50)
        model.apply(deltaX: 40)  // viewport 40-90: item 0 ends at 40, item 2 starts at 100
        #expect(model.visibleRange(itemWidths: [40, 40, 40, 40], spacing: 10) == 1..<2)
        model.apply(deltaX: 10)  // viewport 50-100: item 1 starts at 50, item 2 starts at 100
        #expect(model.visibleRange(itemWidths: [40, 40, 40, 40], spacing: 10) == 1..<2)
    }

    @Test func zeroViewportSeesNothing() {
        let model = ScrollModel(contentWidth: 100, viewportWidth: 0)
        #expect(model.visibleRange(itemWidths: [40, 40], spacing: 0) == 0..<0)
    }

    @Test func spacingShiftsItemStarts() {
        let model = ScrollModel(contentWidth: 100, viewportWidth: 45)
        // Item starts: 0, 30, 60 with spacing 10; 0, 45, 90 with spacing 25. Viewport is 0-45.
        #expect(model.visibleRange(itemWidths: [20, 20, 20], spacing: 10) == 0..<2)
        #expect(model.visibleRange(itemWidths: [20, 20, 20], spacing: 25) == 0..<1)
    }
}
