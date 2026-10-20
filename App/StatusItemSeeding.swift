import Foundation
import HidebarCore
import HidebarSystem

/// The autosave names of the app's status items; the system keys each item's position by them.
enum AutosaveNames {
    static let toggle = "hidebar.toggle"
    static let separator = "hidebar.separator"
}

/// Writes the positions `StatusItemSlots` gives before the items exist, so that the arrow is
/// created right of the pipe and stays on the bar when the pipe hides what is left of it.
struct StatusItemSeeding {
    private let positions = StatusItemPositions()

    func seedFixedItems() {
        seed(AutosaveNames.toggle, slot: StatusItemSlots.toggle)
        seed(AutosaveNames.separator, slot: StatusItemSlots.separator)
    }

    private func seed(_ name: String, slot: Double) {
        StatusItemSlots.fixedSeed(stored: positions.position(of: name), slot: slot)
            .map { positions.set($0, of: name) }
    }
}
