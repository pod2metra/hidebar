import Foundation
import Testing

@testable import HidebarCore

/// The parts `AppComposition` wires together, on fakes that share one bar: the separator at
/// x 0..20, then `a`, `b`, `c` (10 wide) at x 100, 120, 140. Revealing `a` drops it at x 22.
@MainActor
final class CompositionScene {
    let item = FakeStatusItem()
    let timer = ManualClock()
    let bar = MoveFakeBar()
    /// Whether a menu is open; closed unless a test says otherwise.
    let menu = FakeMenuProbe()
    let separator: SeparatorController

    /// What the fake discovery returns.
    var found: [DiscoveredItem] = []
    /// `item.length` at every discovery and at every wait of the bar.
    private(set) var lengthAtDiscovery: [Double] = []
    private(set) var lengthAtWaits: [Double] = []
    private var scripts: [Int: [(id: MenuBarItemID, x: Double)]] = [:]

    var normal: Double { SeparatorController.normalLength }
    var hiding: Double { SeparatorController.hidingLength }

    private(set) lazy var deadline = MoveDeadline(uptime: bar.uptime.reader)

    private(set) lazy var proxy = ClickProxy(
        executor: MoveExecutor(
            poster: bar, locator: bar, windows: bar, clock: bar, deadline: deadline),
        poster: bar, locator: bar, separator: OwnItems.separatorID, revealSide: .rightOf, clock: timer,
        deadline: deadline, isMenuOpen: { [menu] in menu.isMenuOpen() })

    private(set) lazy var composition = AppComposition(
        separator: separator, clickProxy: proxy, clock: bar, locator: bar, uptime: bar.uptime.reader,
        discover: { [unowned self] in
            lengthAtDiscovery.append(item.length)
            return found
        })

    init() {
        separator = SeparatorController(item: item, clock: timer)
        bar.frames[OwnItems.separatorID] = ItemFrame(x: 0, y: 0, width: 20, height: 20)
        for (index, name) in ["a", "b", "c"].enumerated() {
            bar.frames[moveID(name)] = ItemFrame(x: 100 + Double(index) * 20, y: 0, width: 10, height: 20)
        }
        found = [
            discovered("a", x: 100, windowID: 1), discovered("b", x: 120, windowID: 2),
            discovered("c", x: 140, windowID: 3),
        ]
        bar.onWait = { [unowned self] count in
            lengthAtWaits.append(item.length)
            for move in scripts[count] ?? [] {
                place(move.id, x: move.x)
            }
        }
    }

    /// The user collapses the section with the arrow right of the pipe.
    func collapse() {
        #expect(composition.collapse(pipeX: 100, arrowX: 200) == nil)
    }

    /// Wait number `count` since creation moves item `name` to `x`.
    func script(wait count: Int, moves name: String, to x: Double) {
        scripts[count, default: []].append((moveID(name), x))
    }

    /// Wait number `count` since creation moves the separator to `x`.
    func script(wait count: Int, movesSeparatorTo x: Double) {
        scripts[count, default: []].append((OwnItems.separatorID, x))
    }

    /// Every drag lands where it was released, so each is confirmed on its first poll.
    func confirmEveryDrag() {
        bar.dragsLand = true
    }

    func place(_ name: String, x: Double) {
        place(moveID(name), x: x)
    }

    private func place(_ id: MenuBarItemID, x: Double) {
        guard let old = bar.frames[id] else { return }
        bar.frames[id] = ItemFrame(x: x, y: old.y, width: old.width, height: old.height)
    }
}
