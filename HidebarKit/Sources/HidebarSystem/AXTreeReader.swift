import AppKit
import ApplicationServices
import HidebarCore

/// `AXTreeReading` over `AXUIElement`. Without the Accessibility permission the system refuses
/// every read and the reader answers nothing.
public struct AXTreeReader: AXTreeReading {
    public init() {}

    /// Apps that cannot show a window are left out: they cannot own a status item.
    public func applications() -> [AXUIElement] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy != .prohibited }
            .map { AX.application(pid: $0.processIdentifier) }
    }

    public func extrasMenuBar(of application: AXUIElement) -> AXUIElement? {
        AX.value("AXExtrasMenuBar", of: application).flatMap(AX.element)
    }

    public func children(of node: AXUIElement) -> [AXUIElement] {
        AX.value(kAXChildrenAttribute, of: node) as? [AXUIElement] ?? []
    }

    public func attribute(_ name: String, of node: AXUIElement) -> String? {
        AX.value(name, of: node) as? String
    }

    public func frame(of node: AXUIElement) -> ItemFrame? {
        AX.rect(of: node)
    }

    public func pid(of node: AXUIElement) -> Int? {
        AX.pid(of: node)
    }
}
