import Synchronization
import Testing

@testable import HidebarCore

/// Counts the window lists it serves, so a test can tell when the read happened.
final class CountingWindowList: WindowListProvider {
    private let served = Mutex(0)
    private let list: [WindowInfo]

    init(_ list: [WindowInfo]) {
        self.list = list
    }

    var reads: Int { served.withLock { $0 } }

    func windows() -> [WindowInfo] {
        served.withLock { $0 += 1 }
        return list
    }
}

/// Runs the work inline and notes how many window lists had been read when it was handed over.
final class InlineRunner: BackgroundRunning {
    private let seen = Mutex<[Int]>([])
    private let windowList: CountingWindowList

    init(watching windowList: CountingWindowList) {
        self.windowList = windowList
    }

    var readsAtHandover: [Int] { seen.withLock { $0 } }

    func run<Value: Sendable>(_ work: @escaping @Sendable () -> Value) async -> Value {
        seen.withLock { $0.append(windowList.reads) }
        return work()
    }
}

@Suite struct BackgroundDiscoveryTests {
    private let windows = CountingWindowList([window(1, x: 200), window(2, x: 100)])

    private var discovery: ItemDiscovery {
        ItemDiscovery(
            windowList: windows, ownerResolver: StubOwnerResolver(), mainDisplay: { mainDisplay })
    }

    @Test func theWindowsAreReadInsideTheRunnerNotBeforeIt() async {
        let runner = InlineRunner(watching: windows)

        let items = await discovery.discover(on: runner)

        #expect(runner.readsAtHandover == [0])
        #expect(windows.reads == 1)
        #expect(items.map(\.windowID) == [2, 1])
    }

    @Test func theResultIsTheSameAsTheSynchronousOne() async {
        let runner = InlineRunner(watching: windows)
        #expect(await discovery.discover(on: runner) == discovery.discover())
    }
}
