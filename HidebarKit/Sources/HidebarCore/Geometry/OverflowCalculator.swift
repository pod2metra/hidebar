/// Which items of a right-to-left sequence fit on screen and which overflow.
///
/// Item `0` is the rightmost one. Fitting is a prefix: the first item that does not fit
/// ends the visible run, every later item overflows.
public struct OverflowPartition: Sendable, Equatable {
    public let visible: Range<Int>
    public let overflow: Range<Int>

    public init(visible: Range<Int>, overflow: Range<Int>) {
        self.visible = visible
        self.overflow = overflow
    }
}

/// Splits menu-bar items into those that fit in the visible bar and those that overflow.
///
/// All coordinates are screen-local. Items are laid out from the right screen edge leftwards,
/// `spacing` apart. Their left limit is the right edge of the frontmost app's menus; on a
/// notched screen it is never left of the right safe area, so an item never straddles the notch.
public struct OverflowCalculator: Sendable {
    public let screenWidth: Double
    /// `auxiliaryTopRightArea` of a notched screen; `nil` when the screen has no notch.
    public let notchRightArea: BarRect?
    /// Right edge of the frontmost app's menus. On a notched screen long menus can reach past
    /// the notch and cover items there.
    public let menusWidth: Double
    public let spacing: Double

    public init(screenWidth: Double, notchRightArea: BarRect?, menusWidth: Double, spacing: Double) {
        self.screenWidth = screenWidth
        self.notchRightArea = notchRightArea
        self.menusWidth = menusWidth
        self.spacing = spacing
    }

    public func partition(itemWidths: [Double]) -> OverflowPartition {
        let available = max(0, screenWidth - leftLimit)
        var used = 0.0
        var fitting = 0
        for width in itemWidths {
            let gap = fitting == 0 ? 0 : spacing
            guard used + gap + width <= available else { break }
            used += gap + width
            fitting += 1
        }
        return OverflowPartition(visible: 0..<fitting, overflow: fitting..<itemWidths.count)
    }
}
