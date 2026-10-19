import HidebarCore

/// Thin adapters over system APIs. No logic lives here; it belongs in HidebarCore.
public enum HidebarSystem {
    public static let coreLinked: Bool = clamp(1, lower: 0, upper: 2) == 1
}
