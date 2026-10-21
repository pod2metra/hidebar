/// Rows of the overflow strip: the icons that do not fit the menu bar, shown in a panel under it.
///
/// Only the visible section takes part: the icons right of the separator, which are the ones the
/// user wants on the bar. Hidden icons and the app's own items (the separator and its arrow)
/// never become rows, but the own ones take room on the bar and so count in the fit.
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
    /// What the arrow shows about the rows.
    public private(set) var indicator = NotchIndicator(hiddenCount: 0, canReach: true)

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

    private let names: ItemNames
    private let clickIcon: @MainActor (MenuBarItemID) -> ClickOutcome

    /// `click` is how an icon gets clicked; the app passes `AppComposition.click`, so every click
    /// from the strip is made with the separator revealed and the icon put back afterwards.
    public init(names: ItemNames, click: @escaping @MainActor (MenuBarItemID) -> ClickOutcome) {
        self.names = names
        self.clickIcon = click
    }

    /// Rebuilds the rows, keeping the scroll offset within the new content.
    ///
    /// `own` is where the app's pipe and arrow are, read from their windows. It decides which
    /// items are the app's and where the visible section starts, so that the icons hidden left of
    /// the pipe are never counted. Without it the id heuristics still shape the rows, but the
    /// indicator stays at zero: there is no boundary to count against.
    public func recompute(
        screen: OverflowCalculator, viewportWidth: Double, items: [DiscoveredItem],
        capabilities: Capabilities, own: OwnBarItems?
    ) {
        let section = Self.visibleSection(items, boundaryX: own?.separator.x)
        let rightToLeft = Self.rightToLeft(section)
        let overflow = screen.partition(itemWidths: rightToLeft.map(Self.width)).overflow
        let strip = rightToLeft[overflow].reversed().filter { Self.isForeign($0, own: own) }
        itemWidths = strip.map(Self.width)
        spacing = screen.spacing
        scrollModel = ScrollModel(
            contentWidth: Self.contentWidth(itemWidths, spacing: spacing), viewportWidth: viewportWidth,
            offset: scrollModel.offset)
        rows = strip.map { Self.row(for: $0, named: names.name(of: $0.item.id), capabilities: capabilities) }
        indicator = NotchIndicator(hiddenCount: own == nil ? 0 : rows.count, canReach: capabilities.canMove)
    }

    public func scroll(_ input: ScrollInput) {
        scrollModel.apply(deltaX: input.offsetDelta)
    }

    /// Clicks the icon of row `index`. While Accessibility is off nothing is clicked: the row asks
    /// for the permission instead. Nil when there is no such row or the row is not clickable.
    public func click(rowAt index: Int) -> RowActivation? {
        guard rows.indices.contains(index) else { return nil }
        let row = rows[index]
        if row.needsAccessibility { return .accessibilityNeeded }
        guard row.isClickable else { return nil }
        return .outcome(clickIcon(row.id))
    }

    /// The separator and everything right of it. The boundary is the pipe's own window when it is
    /// known, else the pipe found by id; all items when neither is on the bar.
    private static func visibleSection(_ items: [DiscoveredItem], boundaryX: Double?) -> [DiscoveredItem] {
        let byID = items.first(where: { $0.item.id == OwnItems.separatorID })?.item.frame.x
        guard let boundary = boundaryX ?? byID else { return items }
        return items.filter { $0.item.frame.x >= boundary }
    }

    private static func isForeign(_ found: DiscoveredItem, own: OwnBarItems?) -> Bool {
        !OwnItems.isOwn(found.item.id) && !(own?.contains(found.item.frame) ?? false)
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

    private static func row(
        for found: DiscoveredItem, named name: String, capabilities: Capabilities
    ) -> GroupPanelRow {
        GroupPanelRow(
            id: found.item.id, name: name,
            isClickable: capabilities.canMove && found.isManaged && found.item.isMovable,
            needsAccessibility: !capabilities.canMove)
    }
}
