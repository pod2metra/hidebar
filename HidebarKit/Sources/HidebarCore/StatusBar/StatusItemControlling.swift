/// The slice of a menu-bar status item the separator needs.
@MainActor
public protocol StatusItemControlling: AnyObject {
    /// Width in points; a negative value means the system's variable length.
    var length: Double { get set }
    var isVisible: Bool { get set }
}
