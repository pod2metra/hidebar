/// Rows of the overflow strip: the icons that do not fit the menu bar, shown in a panel under it.
///
/// Only the visible section takes part: the icons right of the separator, which are the ones the
/// user wants on the bar. Hidden icons and the app's own items (the separator, the toggle, the
/// group icons) never become rows, but the own ones take room on the bar and so count in the fit.
///
/// Rows run left to right in bar order. Their widths and `spacing` are the single source for
/// both the scroll content width and the visible range, and for where a view draws each row.
@MainActor
public final class OverflowStripViewModel {
    public private(set) var rows: [GroupPanelRow] = []
    /// Width of every row, in row order.
    public private(set) var itemWidths: [Double] = []
    /// Gap between neighbouring rows.
    public private(set) var spacing = 0.0
    public private(set) var scrollModel = ScrollModel(contentWidth: 0, viewportWidth: 0)

    /// True when every icon fits the bar: the strip is not shown.
    public var isHidden: Bool { rows.isEmpty }

    /// Rows that overlap the viewport at the current offset.
    public var visibleRange: Range<Int> {
        scrollModel.visibleRange(itemWidths: itemWidths, spacing: spacing)
    }

    /// Where row `index` starts in the content, before the scroll offset is taken off.
    public func rowStart(at index: Int) -> Double {
        itemWidths.prefix(index).reduce(0, +) + spacing * Double(index)
    }

    private let snapshotter: any Snapshotting
    private let clickIcon: @MainActor (MenuBarItemID) -> ClickOutcome
    private var generation = 0

    /// `click` is how an icon gets clicked; the app passes `AppComposition.click`, so every click
    /// from the strip is made with the separator revealed and the icon put back afterwards.
    public init(
        snapshotter: any Snapshotting, click: @escaping @MainActor (MenuBarItemID) -> ClickOutcome
    ) {
        self.snapshotter = snapshotter
        self.clickIcon = click
    }

    /// Rebuilds the rows at once, keeping the scroll offset within the new content, then upgrades
    /// them to snapshots one by one. A newer call supersedes this one: its late snapshots are dropped.
    public func recompute(
        screen: OverflowCalculator, viewportWidth: Double, items: [DiscoveredItem],
        capabilities: Capabilities
    ) async {
        generation += 1
        let mine = generation
        let rightToLeft = Self.rightToLeft(Self.visibleSection(items))
        let overflow = screen.partition(itemWidths: rightToLeft.map(Self.width)).overflow
        let strip = rightToLeft[overflow].reversed().filter(Self.isForeign)
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

    /// Clicks the icon of row `index`. Nil when there is no such row or the row is not clickable:
    /// nothing is clicked then.
    public func click(rowAt index: Int) -> ClickOutcome? {
        guard rows.indices.contains(index), rows[index].isClickable else { return nil }
        return clickIcon(rows[index].id)
    }

    private func loadSnapshots(for strip: [DiscoveredItem], generation mine: Int) async {
        for (index, item) in strip.enumerated() {
            let image = await snapshotter.snapshot(ofWindow: item.windowID)
            guard mine == generation else { return }
            if let image { rows[index].content = .snapshot(image) }
        }
    }

    /// The separator and everything right of it; all items when the separator is not on the bar.
    private static func visibleSection(_ items: [DiscoveredItem]) -> [DiscoveredItem] {
        guard let boundary = items.first(where: { $0.item.id == OwnItems.separatorID }) else {
            return items
        }
        return items.filter { isAtOrRight(of: boundary, $0) }
    }

    private static func isAtOrRight(of boundary: DiscoveredItem, _ found: DiscoveredItem) -> Bool {
        found.item.frame.x >= boundary.item.frame.x
    }

    private static func isForeign(_ found: DiscoveredItem) -> Bool {
        !OwnItems.isOwn(found.item.id)
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
