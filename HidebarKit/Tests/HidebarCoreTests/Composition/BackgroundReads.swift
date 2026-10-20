@testable import HidebarCore

/// Stands in for the off-main discovery: every read is held until a test releases it, so the test
/// can look at the composition while reads are in flight.
actor BackgroundReads {
    private var waiting: [CheckedContinuation<Void, Never>?] = []
    private var isOpen = false
    private let items: [DiscoveredItem]

    init(returning items: [DiscoveredItem]) {
        self.items = items
    }

    /// Reads that have started, finished or not.
    var started: Int { waiting.count }

    func read() async -> [DiscoveredItem] {
        let index = waiting.count
        waiting.append(nil)
        if !isOpen { await withCheckedContinuation { waiting[index] = $0 } }
        return items
    }

    /// Lets the `index`-th read (in order of arrival) finish.
    func release(_ index: Int) {
        guard waiting.indices.contains(index) else { return }
        waiting[index]?.resume()
        waiting[index] = nil
    }

    /// Lets every read finish, now and later: a test that broke must fail, not hang.
    func releaseAll() {
        isOpen = true
        waiting.indices.forEach(release)
    }
}

/// Waits until `reads` has seen `count` reads start; false after a few seconds without them.
func waitForReads(_ count: Int, in reads: BackgroundReads) async -> Bool {
    let deadline = ContinuousClock.now + .seconds(5)
    while ContinuousClock.now < deadline {
        if await reads.started >= count { return true }
        try? await Task.sleep(for: .milliseconds(1))
    }
    return false
}
