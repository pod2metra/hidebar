/// Horizontal scroll state of the overflow strip.
///
/// `offset` is how far the content is scrolled from its start; a positive `deltaX` scrolls
/// towards the content end. Mapping the wheel's sign to `deltaX` is the caller's job.
public struct ScrollModel: Sendable, Equatable {
    public let contentWidth: Double
    public let viewportWidth: Double
    public private(set) var offset: Double

    public init(contentWidth: Double, viewportWidth: Double, offset: Double = 0) {
        self.contentWidth = contentWidth
        self.viewportWidth = viewportWidth
        self.offset = 0
        self.offset = clamped(offset)
    }

    /// Largest reachable offset; `0` when the content fits the viewport.
    public var maxOffset: Double { max(0, contentWidth - viewportWidth) }

    public mutating func apply(deltaX: Double) {
        offset = clamped(offset + deltaX)
    }

    /// Indices of items, laid out left to right from `0` with `spacing` between them, that
    /// overlap the viewport by a positive width. Empty (`0..<0`) when none does.
    public func visibleRange(itemWidths: [Double], spacing: Double) -> Range<Int> {
        var first: Int?
        var end = 0
        var start = 0.0
        for (index, width) in itemWidths.enumerated() {
            let itemEnd = start + width
            if itemEnd > offset && start < offset + viewportWidth {
                first = first ?? index
                end = index + 1
            }
            start = itemEnd + spacing
        }
        return (first ?? 0)..<end
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), maxOffset)
    }
}
