import AppKit
import CoreGraphics

struct DragOptions {
    var stepMs: Int = 20
    var steps: Int = 10
    /// hid | session | pid (event.postToPid(owner))
    var tap: String = "hid"
    var force = false
}

/// Event fields that route a mouse event to a specific window, copied from Ice.
private let windowIDField = CGEventField(rawValue: 0x33)!

private func makeEvent(
    _ type: CGEventType, at point: CGPoint, window: MenuBarWindow, source: CGEventSource
) -> CGEvent? {
    guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: point, mouseButton: .left)
    else { return nil }
    event.flags = .maskCommand
    event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(window.pid))
    event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(window.id))
    event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(window.id))
    event.setIntegerValueField(windowIDField, value: Int64(window.id))
    return event
}

private func post(_ event: CGEvent, window: MenuBarWindow, tap: String) {
    switch tap {
    case "session": event.post(tap: .cgSessionEventTap)
    case "pid": event.postToPid(window.pid)
    default: event.post(tap: .cghidEventTap)
    }
}

private func sleepMs(_ ms: Int) { usleep(useconds_t(max(ms, 0) * 1000)) }

/// One cmd-drag attempt (no retries: never loop on unmovable items), then poll the bounds for up to 500 ms.
func runDrag(windowID: CGWindowID, deltaX: Double, options: DragOptions) throws {
    guard AXIsProcessTrusted() else { throw SpikeError("Accessibility is not granted to this process") }
    guard let window = Windows.find(windowID) else { throw SpikeError("window \(windowID) not found") }
    guard !window.isImmovable else {
        throw SpikeError("window \(windowID) (\(window.bundleID) / \(window.name)) is a system item macOS will not move")
    }
    // On macOS 26 every item is owned by Control Center; without a name or a non-Control-Center
    // AX owner we cannot tell Clock/BentoBox from a movable item, so refuse unless --force.
    if window.bundleID == "com.apple.controlcenter", !options.force {
        let owner = axOwner(for: window, in: axOwners())
        if owner == nil || owner?.bundleID == "com.apple.controlcenter" {
            throw SpikeError("window \(windowID) cannot be attributed to a third-party app (AX owner: \(owner?.bundleID ?? "unknown")); pass --force to try anyway")
        }
    }
    guard options.steps > 0, let source = CGEventSource(stateID: .hidSystemState) else {
        throw SpikeError("bad steps or no event source")
    }

    let start = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
    let end = CGPoint(x: start.x + deltaX, y: start.y)
    let originalCursor = CGEvent(source: nil)?.location ?? start
    defer {
        CGWarpMouseCursorPosition(originalCursor)
        CGAssociateMouseAndMouseCursorPosition(1)
    }

    guard
        let down = makeEvent(.leftMouseDown, at: start, window: window, source: source),
        let up = makeEvent(.leftMouseUp, at: end, window: window, source: source)
    else { throw SpikeError("event creation failed") }

    print("before: \(fmt(window.bounds))")
    CGWarpMouseCursorPosition(start)
    sleepMs(options.stepMs)
    post(down, window: window, tap: options.tap)
    sleepMs(options.stepMs)
    for i in 1...options.steps {
        let x = start.x + deltaX * Double(i) / Double(options.steps)
        guard let drag = makeEvent(.leftMouseDragged, at: CGPoint(x: x, y: start.y), window: window, source: source)
        else { throw SpikeError("drag event creation failed") }
        post(drag, window: window, tap: options.tap)
        sleepMs(options.stepMs)
    }
    post(up, window: window, tap: options.tap)

    var after = window.bounds
    for _ in 0..<50 {
        sleepMs(10)
        guard let current = Windows.find(windowID) else { throw SpikeError("window \(windowID) disappeared") }
        after = current.bounds
        if after != window.bounds { break }
    }
    print("after:  \(fmt(after))")
    let moved = after.minX - window.bounds.minX
    print("moved dx=\(Int(moved)) (requested \(Int(deltaX))); step-ms=\(options.stepMs) steps=\(options.steps) tap=\(options.tap)")
    print(moved == 0 ? "RESULT: NOT MOVED" : "RESULT: MOVED")
}
