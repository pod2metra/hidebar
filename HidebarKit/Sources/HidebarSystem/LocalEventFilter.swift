import CoreGraphics

/// Keeps the system from swallowing the events a drag posts: during a remote drag no local event
/// is held back, and no suppression interval follows a posted event.
enum LocalEventFilter {
    private static let permitted: CGEventFilterMask = [
        .permitLocalMouseEvents, .permitLocalKeyboardEvents, .permitSystemDefinedEvents,
    ]

    static func permitAll() {
        let source = CGEventSource(stateID: .combinedSessionState)
        [CGEventSuppressionState.eventSuppressionStateRemoteMouseDrag, .eventSuppressionStateSuppressionInterval]
            .forEach { source?.setLocalEventsFilterDuringSuppressionState(permitted, state: $0) }
        source?.localEventsSuppressionInterval = 0
    }
}
