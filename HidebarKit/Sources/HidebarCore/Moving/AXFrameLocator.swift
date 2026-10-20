/// Live frame of a status item straight from Accessibility, so an item the separator pushed off
/// screen (its window is no longer on screen) can still be located.
///
/// Only an identity Accessibility reports exactly once counts: when two items share an id the
/// frame of either could be the wrong one, so none is returned and the item is never dragged.
@MainActor
public struct AXFrameLocator<Tree: AXTreeReading>: ItemLocating {
    private let reader: AXMenuBarReader<Tree>

    public init(reader: AXMenuBarReader<Tree>) {
        self.reader = reader
    }

    public func frame(of id: MenuBarItemID) -> ItemFrame? {
        entries(with: id).sole?.frame
    }

    private func entries(with id: MenuBarItemID) -> [AXMenuBarEntry] {
        reader.entries().filter { $0.id == id }
    }
}
