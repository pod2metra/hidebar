import ApplicationServices

/// Raw Accessibility reads; a failed call is `nil`, never an error.
enum AX {
    static func application(pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        _ = AXUIElementSetMessagingTimeout(element, 0.3)
        return element
    }

    static func value(_ name: String, of node: AXUIElement) -> CFTypeRef? {
        var ref: CFTypeRef?
        return AXUIElementCopyAttributeValue(node, name as CFString, &ref) == .success ? ref : nil
    }

    static func element(_ ref: CFTypeRef) -> AXUIElement? {
        CFGetTypeID(ref) == AXUIElementGetTypeID() ? unsafeDowncast(ref, to: AXUIElement.self) : nil
    }

    static func pid(of node: AXUIElement) -> Int? {
        var pid: pid_t = 0
        return AXUIElementGetPid(node, &pid) == .success ? Int(pid) : nil
    }
}
