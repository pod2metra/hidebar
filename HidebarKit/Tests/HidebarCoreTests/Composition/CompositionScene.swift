import Foundation

@testable import HidebarCore

/// The parts `AppComposition` wires together, on fakes that share one bar: separator `sep` at
/// x 0..20, then `a`, `b`, `c` (10 wide) at x 100, 120, 140. Revealing `a` drops it at x 22.
@MainActor
final class CompositionScene {
    let item = FakeStatusItem()
    let timer = ManualClock()
    let bar = MoveFakeBar()
    let gate = InputGate()
    let backing = InMemoryStore()
    let separator: SeparatorController

    /// What the fake discovery returns.
    var found: [DiscoveredItem] = []
    /// `item.length` at every discovery and at every wait of the bar.
    private(set) var lengthAtDiscovery: [Double] = []
    private(set) var lengthAtWaits: [Double] = []
    private var scripts: [Int: [(name: String, x: Double)]] = [:]
    private var shiftsEveryWait = false

    var normal: Double { SeparatorController.normalLength }
    var hiding: Double { SeparatorController.hidingLength }

    private(set) lazy var proxy = ClickProxy(
        executor: MoveExecutor(poster: bar, locator: bar, clock: bar, inputGate: gate),
        poster: bar, locator: bar, separator: moveID("sep"), revealSide: .rightOf, clock: timer,
        inputGate: gate)

    private(set) lazy var composition = AppComposition(
        separator: separator, clickProxy: proxy, clock: bar,
        discover: { [unowned self] in
            lengthAtDiscovery.append(item.length)
            return found
        })

    init() {
        separator = SeparatorController(item: item, clock: timer)
        bar.frames[moveID("sep")] = ItemFrame(x: 0, y: 0, width: 20, height: 20)
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
                place(move.name, x: move.x)
            }
            if shiftsEveryWait { shiftEveryItem() }
        }
    }

    /// Wait number `count` since creation moves item `name` to `x`.
    func script(wait count: Int, moves name: String, to x: Double) {
        scripts[count, default: []].append((name, x))
    }

    /// Every wait shifts every item, so each drag is confirmed on its first poll.
    func confirmEveryDrag() {
        shiftsEveryWait = true
    }

    func place(_ name: String, x: Double) {
        guard let old = bar.frames[moveID(name)] else { return }
        bar.frames[moveID(name)] = ItemFrame(x: x, y: old.y, width: old.width, height: old.height)
    }

    private func shiftEveryItem() {
        for (id, frame) in bar.frames {
            bar.frames[id] = ItemFrame(x: frame.x + 1, y: frame.y, width: frame.width, height: frame.height)
        }
    }
}
