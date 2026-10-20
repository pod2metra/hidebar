import Foundation
import HidebarCore
import HidebarSystem

/// The autosave names of the app's status items; the system keys each item's position by them.
enum AutosaveNames {
    static let toggle = "hidebar.toggle"
    static let separator = "hidebar.separator"

    static func group(_ id: UUID) -> String { "hidebar.group.\(id.uuidString)" }
}

/// Writes the positions `StatusItemSlots` computes, before the items exist, so that the toggle
/// and the group icons are created right of the separator and stay on the bar when it hides.
struct StatusItemSeeding {
    private let positions = StatusItemPositions()

    func seedFixedItems() {
        seed(AutosaveNames.toggle, slot: StatusItemSlots.toggle)
        seed(AutosaveNames.separator, slot: StatusItemSlots.separator)
    }

    /// Each group gets its position in turn, so a later one is placed against the earlier ones.
    func seedGroups(_ groups: [ItemGroup]) {
        let names = [AutosaveNames.toggle] + groups.map { AutosaveNames.group($0.id) }
        for group in groups {
            let name = AutosaveNames.group(group.id)
            let separator = positions.position(of: AutosaveNames.separator) ?? StatusItemSlots.separator
            StatusItemSlots.groupSeed(
                stored: positions.position(of: name), separator: separator,
                taken: names.compactMap(positions.position(of:))
            ).map { positions.set($0, of: name) }
        }
    }

    private func seed(_ name: String, slot: Double) {
        StatusItemSlots.fixedSeed(stored: positions.position(of: name), slot: slot)
            .map { positions.set($0, of: name) }
    }
}
