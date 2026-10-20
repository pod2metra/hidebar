/// Read-only view of the Accessibility tree; the adapter wraps `AXUIElement`.
public protocol AXTreeReading: Sendable {
    /// One element in the tree (an application, its menu bar or one item).
    associatedtype Node

    /// The application element of every running app that can own a status item.
    func applications() -> [Node]
    /// The app's `AXExtrasMenuBar`, where its status items live; `nil` when it has none.
    func extrasMenuBar(of application: Node) -> Node?
    func children(of node: Node) -> [Node]
    /// A string attribute such as `AXTitle`; `nil` when the node lacks it or Accessibility refuses.
    func attribute(_ name: String, of node: Node) -> String?
    /// Frame in screen coordinates, the same space as window bounds.
    func frame(of node: Node) -> ItemFrame?
    /// Process that owns the node.
    func pid(of node: Node) -> Int?
}
