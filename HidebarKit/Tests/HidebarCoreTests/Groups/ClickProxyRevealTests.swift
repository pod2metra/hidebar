import Testing

@testable import HidebarCore

/// Where a clicked icon is dropped. Bar: separator 0..20, then icons 10 wide. An icon already
/// first after the separator cannot be "moved next to" it, so it hops over a neighbour instead.
@MainActor @Suite struct ClickProxyRevealTests {
    private let bar = MoveFakeBar()
    private let timer = ManualClock()
    private let deadline: MoveDeadline

    init() {
        deadline = MoveDeadline(budgetMilliseconds: 1000, uptime: bar.uptime.reader)
    }

    private func place(_ name: String, x: Double, width: Double = 10) {
        bar.frames[moveID(name)] = ItemFrame(x: x, y: 0, width: width, height: 20)
    }

    private func proxy(revealSide: DropSide = .rightOf) -> ClickProxy {
        ClickProxy(
            executor: MoveExecutor(
                poster: bar, locator: bar, windows: bar, clock: bar, deadline: deadline),
            poster: bar, locator: bar, separator: moveID("sep"), revealSide: revealSide, clock: timer,
            deadline: deadline, isMenuOpen: { false })
    }

    private func separator(x: Double = 0) -> DiscoveredItem {
        discovered("sep", x: x, windowID: 9)
    }

    /// The `n`-th wait since creation moves `item` to the given x.
    private func moves(_ script: [Int: Double], item: String) {
        bar.onWait = { [bar] count in
            if let x = script[count] { bar.frames[moveID(item)] = ItemFrame(x: x, y: 0, width: 10, height: 20) }
        }
    }

    private func arrange(_ names: [(String, Double)]) -> [DiscoveredItem] {
        place("sep", x: 0, width: 20)
        return [separator()]
            + names.map { name, x in
                place(name, x: x)
                return discovered(name, x: x)
            }
    }

    @Test func theFirstIconAfterTheSeparatorHopsOverItsNearestMovableNeighbour() {
        let items = arrange([("a", 30), ("b", 50), ("c", 70)])
        moves([1: 55], item: "a")
        let proxy = proxy()

        #expect(proxy.click(moveID("a"), among: items) == .clicked)

        #expect(bar.downs == [CommandDrag.pressPoint])
        #expect(bar.ups == [CursorPoint(x: 60, y: 10)])
        #expect(bar.clicks == [CursorPoint(x: 60, y: 10)])
    }

    @Test func theHopTargetIsTheNearestNeighbourWhateverTheListOrder() {
        let items = arrange([("a", 30), ("c", 70), ("b", 50)])
        moves([1: 55], item: "a")

        #expect(proxy().click(moveID("a"), among: items) == .clicked)
        #expect(bar.ups == [CursorPoint(x: 60, y: 10)])
    }

    @Test func theIconGoesHomeToTheLeftOfTheNeighbourItHoppedOver() {
        let items = arrange([("a", 30), ("b", 50)])
        moves([1: 55, 2: 30], item: "a")
        let proxy = proxy()

        #expect(proxy.click(moveID("a"), among: items) == .clicked)
        #expect(proxy.menuDidClose() == .restored)

        #expect(bar.ups == [CursorPoint(x: 60, y: 10), CursorPoint(x: 50, y: 10)])
    }

    @Test func unmanagedAndUnmovableNeighboursAreNotHoppedOver() {
        place("sep", x: 0, width: 20)
        place("a", x: 30)
        place("b", x: 50)
        place("c", x: 70)
        place("d", x: 90)
        let items = [
            separator(), discovered("a", x: 30), discovered("b", x: 50, managed: false),
            discovered("c", x: 70, movable: false), discovered("d", x: 90),
        ]
        moves([1: 95], item: "a")

        #expect(proxy().click(moveID("a"), among: items) == .clicked)
        #expect(bar.ups == [CursorPoint(x: 100, y: 10)])
    }

    @Test func withNothingToHopOverTheIconIsClickedWhereItIsAndNotDragged() {
        place("sep", x: 0, width: 20)
        place("a", x: 30)
        place("c", x: 50)
        let items = [separator(), discovered("a", x: 30), discovered("c", x: 50, movable: false)]
        let proxy = proxy()

        #expect(proxy.click(moveID("a"), among: items) == .clicked)

        #expect(bar.downs.isEmpty)
        #expect(bar.clicks == [CursorPoint(x: 35, y: 10)])
        #expect(proxy.menuDidClose() == .nothingToRestore)
        #expect(!proxy.hasDisplacedItem)
    }

    @Test func aClickIsNotPostedWhenReadingTheIconsFrameOutlastedTheGate() {
        place("sep", x: 0, width: 20)
        place("a", x: 30)
        place("c", x: 50)
        let items = [separator(), discovered("a", x: 30), discovered("c", x: 50, movable: false)]
        let proxy = proxy()
        bar.readCost = 1100

        #expect(proxy.click(moveID("a"), among: items) == .clickFailed)

        #expect(bar.clicks.isEmpty)
        #expect(!proxy.hasDisplacedItem)
    }

    @Test func anIconWithAnotherOneBetweenItAndTheSeparatorIsDroppedBesideTheSeparator() {
        let items = arrange([("a", 30), ("b", 50)])
        moves([1: 22], item: "b")

        #expect(proxy().click(moveID("b"), among: items) == .clicked)
        #expect(bar.ups == [CursorPoint(x: 20, y: 10)])
    }

    @Test func aHiddenIconLeftOfTheSeparatorIsDroppedBesideIt() {
        place("sep", x: 100, width: 20)
        place("h", x: 40)
        place("a", x: 130)
        let items = [discovered("h", x: 40), separator(x: 100), discovered("a", x: 130)]
        moves([1: 122], item: "h")

        #expect(proxy().click(moveID("h"), among: items) == .clicked)
        #expect(bar.ups == [CursorPoint(x: 120, y: 10)])
    }

    @Test func anIconOnTheSeparatorsOwnPositionIsDroppedBesideIt() {
        place("sep", x: 30, width: 20)
        place("a", x: 30)
        place("b", x: 60)
        let items = [separator(x: 30), discovered("a", x: 30), discovered("b", x: 60)]
        moves([1: 52], item: "a")

        #expect(proxy().click(moveID("a"), among: items) == .clicked)
        #expect(bar.ups == [CursorPoint(x: 50, y: 10)])
    }

    @Test func revealingToTheLeftHopsOverTheNeighbourOnTheFarSideOfTheFirstIcon() {
        // Bar: a, b, separator; icons are on screen left of the separator, `b` is first there.
        place("sep", x: 60, width: 20)
        place("a", x: 10)
        place("b", x: 40)
        let items = [discovered("a", x: 10), discovered("b", x: 40), separator(x: 60)]
        moves([1: 5], item: "b")

        #expect(proxy(revealSide: .leftOf).click(moveID("b"), among: items) == .clicked)
        #expect(bar.ups == [CursorPoint(x: 10, y: 10)])
    }

    @Test func anIconRightOfTheSeparatorIsDroppedBesideItWhenRevealingToTheLeft() {
        place("sep", x: 0, width: 20)
        place("a", x: 30)
        let items = [separator(), discovered("a", x: 30), discovered("b", x: 60)]
        moves([1: 2], item: "a")

        #expect(proxy(revealSide: .leftOf).click(moveID("a"), among: items) == .clicked)
        #expect(bar.ups == [CursorPoint(x: 0, y: 10)])
    }
}
