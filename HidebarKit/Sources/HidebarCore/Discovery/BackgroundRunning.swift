/// Runs blocking work away from the main thread and hands back its result. Reading the
/// Accessibility tree costs a round trip per app, and a frozen app costs its whole timeout.
public protocol BackgroundRunning: Sendable {
    func run<Value: Sendable>(_ work: @escaping @Sendable () -> Value) async -> Value
}

extension ItemDiscovery {
    /// `discover()` on `runner`, so the caller's thread is free while the windows are read and
    /// their owners resolved.
    public func discover(on runner: any BackgroundRunning) async -> [DiscoveredItem] {
        await runner.run { discover() }
    }
}
