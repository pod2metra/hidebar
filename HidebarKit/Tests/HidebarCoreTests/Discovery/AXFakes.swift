import Synchronization

@testable import HidebarCore

final class WalkCounter: Sendable {
    private let count = Mutex<Int>(0)
    var value: Int { count.withLock { $0 } }
    func increment() { count.withLock { $0 += 1 } }
}

struct FakeAXItem: Sendable {
    var pid: Int? = 10
    var frame: ItemFrame? = ItemFrame(x: 100, y: 0, width: 46, height: 24)
    var title: String? = "Item"
    var description: String?
    var identifier: String?
}

struct FakeAXApp: Sendable {
    /// `nil` means the app has no `AXExtrasMenuBar`.
    var items: [FakeAXItem]?
}

/// Nodes are paths: `[app]` is an application, `[app, -1]` its menu bar, `[app, i]` its i-th item.
struct FakeAXTree: AXTreeReading {
    typealias Node = [Int]

    let apps: [FakeAXApp]
    let walks = WalkCounter()

    func applications() -> [[Int]] {
        walks.increment()
        return apps.indices.map { [$0] }
    }

    func extrasMenuBar(of application: [Int]) -> [Int]? {
        apps[application[0]].items == nil ? nil : [application[0], -1]
    }

    func children(of node: [Int]) -> [[Int]] {
        node.count == 2 && node[1] == -1
            ? (apps[node[0]].items ?? []).indices.map { [node[0], $0] } : []
    }

    private func item(_ node: [Int]) -> FakeAXItem? {
        node.count == 2 && node[1] >= 0 ? apps[node[0]].items?[node[1]] : nil
    }

    func attribute(_ name: String, of node: [Int]) -> String? {
        switch name {
        case "AXTitle": item(node)?.title
        case "AXDescription": item(node)?.description
        case "AXIdentifier": item(node)?.identifier
        default: nil
        }
    }

    func frame(of node: [Int]) -> ItemFrame? { item(node)?.frame }
    func pid(of node: [Int]) -> Int? { item(node)?.pid }
}

/// Bundle id for pids 10 and 20 only.
let fakeBundleID: @Sendable (Int) -> String? = { pid in
    [10: "com.example.alpha", 20: "com.example.beta"][pid]
}

func axFrame(_ x: Double, width: Double = 46) -> ItemFrame {
    ItemFrame(x: x, y: 0, width: width, height: 24)
}
