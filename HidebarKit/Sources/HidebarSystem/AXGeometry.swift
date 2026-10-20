import ApplicationServices
import CoreGraphics
import HidebarCore

extension AX {
    /// Position and size of the node in screen coordinates.
    static func rect(of node: AXUIElement) -> ItemFrame? {
        let origin = read(kAXPositionAttribute, .cgPoint, CGPoint.zero, of: node)
        let size = read(kAXSizeAttribute, .cgSize, CGSize.zero, of: node)
        return origin.flatMap { o in
            size.map { ItemFrame(x: o.x, y: o.y, width: $0.width, height: $0.height) }
        }
    }

    private static func read<T: BitwiseCopyable>(
        _ name: String, _ type: AXValueType, _ zero: T, of node: AXUIElement
    ) -> T? {
        var out = zero
        let ok = value(name, of: node).map {
            CFGetTypeID($0) == AXValueGetTypeID()
                && AXValueGetValue(unsafeDowncast($0, to: AXValue.self), type, &out)
        }
        return ok == true ? out : nil
    }
}
