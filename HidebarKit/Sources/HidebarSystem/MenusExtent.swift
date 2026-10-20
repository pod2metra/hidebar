import AppKit
import ApplicationServices

/// Right edge of the menus of the app that owns the menu bar, in screen coordinates.
/// `nil` when Accessibility answers nothing, notably without the permission.
public struct MenusExtent: Sendable {
    public init() {}

    public func maxX() -> Double? {
        let owner = NSWorkspace.shared.menuBarOwningApplication
        let menuBar = owner
            .flatMap { AX.value(kAXMenuBarAttribute, of: AX.application(pid: $0.processIdentifier)) }
            .flatMap(AX.element)
        let menus = menuBar.flatMap { AX.value(kAXChildrenAttribute, of: $0) as? [AXUIElement] }
        return menus?.compactMap(AX.rect(of:)).map { $0.x + $0.width }.max()
    }
}
