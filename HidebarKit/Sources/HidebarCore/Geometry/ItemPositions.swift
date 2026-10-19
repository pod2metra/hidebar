extension OverflowCalculator {
    /// Left edge of the visible area: the right edge of the frontmost app's menus, pushed right of
    /// the notch on a notched screen. Same value `partition` fits items against.
    public var leftLimit: Double {
        max(notchRightArea?.minX ?? menusWidth, menusWidth)
    }

    /// Left edge (`minX`) of every item when `itemWidths` are laid out from the right screen edge
    /// leftwards, `spacing` apart. Index `0` is the rightmost item, as in `partition`.
    ///
    /// Items are not clipped: those that overflow get negative or sub-`leftLimit` values, which is
    /// where the system really puts them once the separator pushes them off the bar.
    public func itemMinXs(itemWidths: [Double]) -> [Double] {
        var rightEdge = screenWidth
        return itemWidths.map { width in
            let minX = rightEdge - width
            rightEdge = minX - spacing
            return minX
        }
    }
}
