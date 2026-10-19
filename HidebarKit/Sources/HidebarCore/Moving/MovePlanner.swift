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

/// Turns the bar's current order and a desired order into the fewest drags that reach it.
///
/// Only items that are movable and named by the desired order take part. Everything else
/// (unmovable system items, items the desired order does not mention, ids that are not on the bar)
/// is never dragged and never used as a drop anchor; moved items may end up on either side of it.
/// Drags needed: the managed items minus the longest run of them already in the right order.
public enum MovePlanner {
    /// - Parameters:
    ///   - current: items left to right, as observed now.
    ///   - desired: ids left to right in the order they should end up.
    /// - Returns: steps to run in order; empty when the managed items are already in order.
    public static func plan(current: [MenuBarItem], desired: [MenuBarItemID]) -> [MoveStep] {
        let rank = Dictionary(
            desired.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let managed: [(item: MenuBarItem, rank: Int)] = current.compactMap { item in
            guard item.isMovable, let place = rank[item.id] else { return nil }
            return (item, place)
        }
        // From here on an item is its index `k` in `managed` (current order); `order[p]` is the
        // item that belongs at final position `p`, `position[k]` the inverse.
        let order = managed.indices.sorted { (managed[$0].rank, $0) < (managed[$1].rank, $1) }
        var position = order
        for (place, k) in order.enumerated() {
            position[k] = place
        }

        return drops(order: order, position: position).map { drop in
            MoveStep(item: managed[drop.moved].item, anchor: managed[drop.anchor].item.id, side: drop.side)
        }
    }

    /// Drags that put every item outside the longest already-ordered run into its final place,
    /// building the final order from the front.
    private static func drops(
        order: [Int], position: [Int]
    ) -> [(moved: Int, anchor: Int, side: DropSide)] {
        let stay = Set(longestIncreasing(position))
        var working = Array(position.indices)
        var result: [(moved: Int, anchor: Int, side: DropSide)] = []
        for k in order where !stay.contains(k) {
            working.remove(at: working.firstIndex(of: k)!)
            if position[k] == 0 {
                result.append((k, working[0], .leftOf))
                working.insert(k, at: 0)
            } else {
                // The predecessor in the final order was placed earlier or never moved, so it is
                // still in `working`.
                let anchor = order[position[k] - 1]
                result.append((k, anchor, .rightOf))
                working.insert(k, at: working.firstIndex(of: anchor)! + 1)
            }
        }
        return result
    }

    /// Indices into `keys` of one longest strictly increasing subsequence.
    private static func longestIncreasing(_ keys: [Int]) -> [Int] {
        var length = [Int](repeating: 1, count: keys.count)
        var previous = [Int?](repeating: nil, count: keys.count)
        for index in keys.indices {
            for earlier in 0..<index where keys[earlier] < keys[index] && length[earlier] >= length[index] {
                length[index] = length[earlier] + 1
                previous[index] = earlier
            }
        }
        var chain: [Int] = []
        var cursor = length.indices.max { length[$0] < length[$1] }
        while let found = cursor {
            chain.append(found)
            cursor = previous[found]
        }
        return chain
    }
}
