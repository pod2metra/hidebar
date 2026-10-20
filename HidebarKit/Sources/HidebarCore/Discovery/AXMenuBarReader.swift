/// A status item as Accessibility shows it: the real owner and where it sits right now.
public struct AXMenuBarEntry: Equatable, Sendable {
    public let frame: ItemFrame
    public let owner: ItemOwner

    public var id: MenuBarItemID {
        MenuBarItemID(ownerBundleID: owner.bundleID, title: owner.title)
    }

    public init(frame: ItemFrame, owner: ItemOwner) {
        self.frame = frame
        self.owner = owner
    }
}

/// Walks every app's `AXExtrasMenuBar` and lists its items. Without the Accessibility permission
/// the tree answers nothing and the list is empty.
public struct AXMenuBarReader<Tree: AXTreeReading>: Sendable {
    /// Tried in order; the first non-empty value is the item's title. Image-only items usually
    /// carry their name in the description.
    static var titleAttributes: [String] { ["AXTitle", "AXDescription"] }

    private let tree: Tree
    private let bundleIDOfPID: @Sendable (Int) -> String?

    public init(tree: Tree, bundleIDOfPID: @escaping @Sendable (Int) -> String?) {
        self.tree = tree
        self.bundleIDOfPID = bundleIDOfPID
    }

    /// Items with no frame or no identifiable owning process are skipped.
    public func entries() -> [AXMenuBarEntry] {
        tree.applications().flatMap(items).compactMap(entry)
    }

    private func items(of application: Tree.Node) -> [Tree.Node] {
        tree.extrasMenuBar(of: application).map { tree.children(of: $0) } ?? []
    }

    private func entry(for node: Tree.Node) -> AXMenuBarEntry? {
        guard let frame = tree.frame(of: node), let pid = tree.pid(of: node),
            let bundleID = bundleIDOfPID(pid)
        else { return nil }
        return AXMenuBarEntry(frame: frame, owner: ItemOwner(bundleID: bundleID, title: title(of: node)))
    }

    private func title(of node: Tree.Node) -> String {
        Self.titleAttributes.lazy
            .compactMap { tree.attribute($0, of: node) }
            .first { !$0.isEmpty } ?? ""
    }
}
