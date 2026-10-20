import CoreGraphics
import Foundation
import HidebarCore

/// Drops the user's mouse events when the `InputGate` is closed. The tap runs on its own thread,
/// as a move blocks the main one. No tap is created without Accessibility; `isActive` tells.
public final class EventTapInputGate: @unchecked Sendable {
    private static let mask: CGEventMask = [
        CGEventType.leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp, .otherMouseDown,
        .otherMouseUp, .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        .scrollWheel,
    ].reduce(0) { $0 | (1 << CGEventMask($1.rawValue)) }

    let gate: InputGate
    private(set) var port: CFMachPort?
    public var isActive: Bool { port != nil }

    public init(gate: InputGate) {
        self.gate = gate
        port = CGEvent.tapCreate(
            tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: Self.mask, callback: tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque())
        nonisolated(unsafe) let source = port.flatMap { CFMachPortCreateRunLoopSource(nil, $0, 0) }
        Thread {
            source.map { CFRunLoopAddSource(CFRunLoopGetCurrent(), $0, .commonModes) }
            CFRunLoopRun()
        }.start()
    }

    /// Invalidating the port ends the run loop, and with it the thread.
    deinit { port.map { CFMachPortInvalidate($0) } }
}
