/// One scroll event as the adapter reads it from the platform, without any interpretation.
///
/// The deltas are in the direction the user configured: the platform has already applied
/// natural scrolling to them, so the mapping must not invert them a second time.
public struct ScrollInput: Sendable, Equatable {
    /// Points scrolled per wheel line; a wheel reports lines, a trackpad reports points.
    public static let pointsPerWheelLine = 20.0

    public let deltaX: Double
    public let deltaY: Double
    /// `true` for a trackpad or Magic Mouse, `false` for a wheel.
    public let hasPreciseDeltas: Bool

    public init(deltaX: Double, deltaY: Double, hasPreciseDeltas: Bool) {
        self.deltaX = deltaX
        self.deltaY = deltaY
        self.hasPreciseDeltas = hasPreciseDeltas
    }

    /// The `ScrollModel.apply(deltaX:)` argument: positive scrolls towards the content end.
    ///
    /// The axis with the larger magnitude drives the strip, whatever the device: a wheel turned
    /// vertically, a Shift-wheel or horizontal wheel, a trackpad swipe in either direction. On a
    /// tie the vertical axis wins. A wheel counts in lines, a trackpad in points. Content follows
    /// the gesture, hence the sign flip.
    public var offsetDelta: Double {
        let dominant = abs(deltaX) > abs(deltaY) ? deltaX : deltaY
        return -dominant * (hasPreciseDeltas ? 1 : Self.pointsPerWheelLine)
    }
}
