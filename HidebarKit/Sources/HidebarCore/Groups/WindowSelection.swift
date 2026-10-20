extension Array {
    /// The window a capture adapter asked for. `idOf` reads the platform window's id, so the
    /// selection stays here, tested, and the adapter only forwards.
    public func firstWindow(withID id: Int, idOf: (Element) -> Int) -> Element? {
        first { idOf($0) == id }
    }
}
