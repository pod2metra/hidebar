import Foundation
import HidebarCore

/// Blocks the calling thread between frame polls. The move is a short synchronous sequence on
/// the main actor, so the pause has to be synchronous too.
@MainActor
public struct ThreadMoveClock: MoveClock {
    public init() {}

    public func wait(milliseconds: Int) {
        Thread.sleep(forTimeInterval: Double(milliseconds) / 1000)
    }
}
