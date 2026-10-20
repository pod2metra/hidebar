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
    /// A wheel only moves vertically, so its `deltaY` drives the strip. A trackpad drives it with
    /// `deltaX`, and falls back to `deltaY` for a purely vertical swipe. Content follows the
    /// gesture, hence the sign flip.
    public var offsetDelta: Double {
        guard hasPreciseDeltas else { return -deltaY * Self.pointsPerWheelLine }
        return -(deltaX == 0 ? deltaY : deltaX)
    }
}
