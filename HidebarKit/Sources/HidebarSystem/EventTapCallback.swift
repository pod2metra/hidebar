import CoreGraphics
import HidebarCore

let tapCallback: CGEventTapCallBack = { _, type, event, info in
    Unmanaged<EventTapInputGate>.fromOpaque(info!).takeUnretainedValue().handle(type, event)
}

extension EventTapInputGate {
    /// The system switches a tap off on a timeout or on user input, and an off tap stops dropping
    /// input; so the tap is turned back on, and never turned off here. A disabled notification
    /// carries no input and passes without its event being read.
    func handle(_ type: CGEventType, _ event: CGEvent) -> Unmanaged<CGEvent>? {
        let reenable = InputGate.shouldReenable(eventTypeRaw: type.rawValue)
        port.map { CGEvent.tapEnable(tap: $0, enable: reenable || CGEvent.tapIsEnabled(tap: $0)) }
        let tag = { event.getIntegerValueField(.eventSourceUserData) }
        let passes = reenable || gate.shouldPass(isSynthetic: InputGate.isSynthetic(userData: tag()))
        return passes ? Unmanaged.passUnretained(event) : nil
    }
}
