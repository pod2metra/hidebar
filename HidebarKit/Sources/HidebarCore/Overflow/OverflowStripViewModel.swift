/// Rows of the overflow strip: the icons that do not fit the menu bar, shown in a panel under it.
///
/// Rows run left to right in bar order. Their widths and `spacing` are the single source for
/// both the scroll content width and the visible range.
@MainActor
public final class OverflowStripViewModel {
    public private(set) var rows: [GroupPanelRow] = []
    public private(set) var scrollModel = ScrollModel(contentWidth: 0, viewportWidth: 0)

    /// True when every icon fits the bar: the strip is not shown.
    public var isHidden: Bool { rows.isEmpty }

    /// Rows that overlap the viewport at the current offset.
    public var visibleRange: Range<Int> {
        scrollModel.visibleRange(itemWidths: itemWidths, spacing: spacing)
    }

    private let snapshotter: any Snapshotting
    private let clickProxy: ClickProxy
    private var items: [DiscoveredItem] = []
    private var itemWidths: [Double] = []
    private var spacing = 0.0
    private var generation = 0

    public init(snapshotter: any Snapshotting, clickProxy: ClickProxy) {
        self.snapshotter = snapshotter
        self.clickProxy = clickProxy
    }

    /// Rebuilds the rows at once, keeping the scroll offset within the new content, then upgrades
    /// them to snapshots one by one. A newer call supersedes this one: its late snapshots are dropped.
    public func recompute(
        screen: OverflowCalculator, viewportWidth: Double, items: [DiscoveredItem],
        capabilities: Capabilities
    ) async {
        generation += 1
        let mine = generation
        self.items = items
        let rightToLeft = Self.rightToLeft(items)
        let overflow = screen.partition(itemWidths: rightToLeft.map(Self.width)).overflow
        let strip = Array(rightToLeft[overflow].reversed())
        itemWidths = strip.map(Self.width)
        spacing = screen.spacing
        scrollModel = ScrollModel(
            contentWidth: Self.contentWidth(itemWidths, spacing: spacing), viewportWidth: viewportWidth,
            offset: scrollModel.offset)
        rows = strip.map { Self.row(for: $0, capabilities: capabilities) }
        guard capabilities.panelPresentation == .snapshots else { return }
        await loadSnapshots(for: strip, generation: mine)
    }

    public func scroll(_ input: ScrollInput) {
        scrollModel.apply(deltaX: input.offsetDelta)
    }

    /// Clicks the icon of row `index` through the proxy. Nil when there is no such row or the row
    /// is not clickable: no event is posted then.
    public func click(rowAt index: Int) -> ClickOutcome? {
        guard rows.indices.contains(index), rows[index].isClickable else { return nil }
        return clickProxy.click(rows[index].id, among: items)
    }

    private func loadSnapshots(for strip: [DiscoveredItem], generation mine: Int) async {
        for (index, item) in strip.enumerated() {
            let image = await snapshotter.snapshot(ofWindow: item.windowID)
            guard mine == generation else { return }
            if let image { rows[index].content = .snapshot(image) }
        }
    }

    /// Rightmost first, as `OverflowCalculator.partition` expects; equal positions keep input order.
    private static func rightToLeft(_ items: [DiscoveredItem]) -> [DiscoveredItem] {
        items.enumerated()
            .sorted { ($0.element.item.frame.x, $1.offset) > ($1.element.item.frame.x, $0.offset) }
            .map(\.element)
    }

    private static func width(_ item: DiscoveredItem) -> Double { item.item.frame.width }

    private static func contentWidth(_ widths: [Double], spacing: Double) -> Double {
        max(0, widths.reduce(0) { $0 + $1 + spacing } - spacing)
    }

    private static func row(for found: DiscoveredItem, capabilities: Capabilities) -> GroupPanelRow {
        let id = found.item.id
        return GroupPanelRow(
            id: id, name: id.title.isEmpty ? id.ownerBundleID : id.title, content: .appName,
            isClickable: capabilities.canMove && found.isManaged && found.item.isMovable)
    }
}
