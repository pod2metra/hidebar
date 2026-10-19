/// Clamps `value` to the closed range `[lower, upper]`.
public func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
    if value < lower { return lower }
    if value > upper { return upper }
    return value
}
