/// The curated set of SF Symbols a group may use as its menu bar label.
///
/// Mirrors the table in `docs/SYMBOL_CATALOG.md`; a test keeps the two in sync.
public enum SymbolCatalog {
    public struct Category: Equatable, Sendable {
        public let name: String
        public let symbols: [String]
    }

    public static let categories: [Category] = [
        Category(name: "Work", symbols: ["briefcase", "calendar", "checklist", "folder", "doc.text"]),
        Category(name: "Communication", symbols: ["message", "envelope", "phone", "video", "at"]),
        Category(
            name: "Media",
            symbols: ["music.note", "play.rectangle", "headphones", "camera", "mic"]),
        Category(
            name: "System",
            symbols: ["gearshape", "cpu", "battery.100", "speaker.wave.2", "display"]),
        Category(
            name: "Development",
            symbols: [
                "terminal", "chevron.left.forwardslash.chevron.right", "hammer", "ladybug",
                "shippingbox",
            ]),
        Category(name: "Network", symbols: ["network", "lock.shield", "wifi", "globe", "key"]),
        Category(
            name: "Utilities",
            symbols: ["wrench.and.screwdriver", "magnifyingglass", "clipboard", "timer", "bolt"]),
        Category(name: "Misc", symbols: ["star", "heart", "bookmark", "flag", "tag"]),
    ]

    private static let allNames: Set<String> = Set(categories.flatMap(\.symbols))

    public static func contains(_ name: String) -> Bool {
        allNames.contains(name)
    }
}
