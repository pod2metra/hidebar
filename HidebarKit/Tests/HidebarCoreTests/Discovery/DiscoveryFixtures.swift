@testable import HidebarCore

struct StubWindowList: WindowListProvider {
    var list: [WindowInfo]
    func windows() -> [WindowInfo] { list }
}

/// Answers from a fixed table; a window that is not in it has no Accessibility answer.
struct StubOwnerResolver: ItemOwnerResolving {
    var owners: [Int: ItemOwner] = [:]
    func owner(ofWindow windowID: Int) -> ItemOwner? { owners[windowID] }
}

let controlCenter = "com.apple.controlcenter"

/// The row sample in Spikes/FINDINGS.md has no height; 24 is the menu bar height on that machine.
func window(
    _ id: Int, x: Double, width: Double = 46, height: Double = 24, layer: Int = 25,
    onscreen: Bool = true, owner: String? = controlCenter, title: String = ""
) -> WindowInfo {
    WindowInfo(
        windowID: id, layer: layer,
        frame: ItemFrame(x: x, y: 0, width: width, height: height),
        isOnscreen: onscreen, ownerBundleID: owner, title: title)
}

func discover(_ windows: [WindowInfo], owners: [Int: ItemOwner] = [:]) -> [DiscoveredItem] {
    ItemDiscovery(
        windowList: StubWindowList(list: windows), ownerResolver: StubOwnerResolver(owners: owners)
    ).discover()
}

func managed(_ item: MenuBarItemID, windowID: Int = 1) -> DiscoveredItem {
    DiscoveredItem(
        windowID: windowID,
        item: MenuBarItem(
            id: item, frame: ItemFrame(x: 0, y: 0, width: 46, height: 24), isMovable: true,
            isHidable: true),
        isManaged: true)
}

func unmanaged(_ item: MenuBarItemID, windowID: Int = 1) -> DiscoveredItem {
    DiscoveredItem(
        windowID: windowID,
        item: MenuBarItem(
            id: item, frame: ItemFrame(x: 0, y: 0, width: 46, height: 24), isMovable: false,
            isHidable: false),
        isManaged: false)
}
