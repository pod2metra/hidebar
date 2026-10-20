/// Which side of the anchor item a moved item is dropped on.
public enum DropSide: Equatable, Sendable {
    case leftOf
    case rightOf
}

/// One drag: put `item` immediately `side` of the item `anchor`.
///
/// The anchor, not a coordinate, is the target: every earlier step shifts the bar, so the drop
/// point is read from the anchor's live frame when the step runs.
public struct MoveStep: Equatable, Sendable {
    public let item: MenuBarItem
    public let anchor: MenuBarItemID
    public let side: DropSide

    public init(item: MenuBarItem, anchor: MenuBarItemID, side: DropSide) {
        self.item = item
        self.anchor = anchor
        self.side = side
    }
}
