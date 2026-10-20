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

/// A main display wide enough for every row the tests use.
let mainDisplay = ItemFrame(x: 0, y: 0, width: 3_000, height: 1_000)

/// The row sample in Spikes/FINDINGS.md has no height; 24 is the menu bar height on that machine.
func window(
    _ id: Int, x: Double, y: Double = 0, width: Double = 46, height: Double = 24, layer: Int = 25,
    onscreen: Bool = true, ownerPID: Int = 688, owner: String? = controlCenter, title: String = ""
) -> WindowInfo {
    WindowInfo(
        windowID: id, layer: layer,
        frame: ItemFrame(x: x, y: y, width: width, height: height),
        isOnscreen: onscreen, ownerPID: ownerPID, ownerBundleID: owner, title: title)
}

func discover(
    _ windows: [WindowInfo], owners: [Int: ItemOwner] = [:], display: ItemFrame = mainDisplay
) -> [DiscoveredItem] {
    ItemDiscovery(
        windowList: StubWindowList(list: windows), ownerResolver: StubOwnerResolver(owners: owners),
        mainDisplay: { display }
    ).discover()
}

func managed(_ item: MenuBarItemID, windowID: Int = 1) -> DiscoveredItem {
    DiscoveredItem(
        windowID: windowID, ownerPID: 688,
        item: MenuBarItem(
            id: item, frame: ItemFrame(x: 0, y: 0, width: 46, height: 24), isMovable: true),
        isManaged: true)
}

func unmanaged(_ item: MenuBarItemID, windowID: Int = 1) -> DiscoveredItem {
    DiscoveredItem(
        windowID: windowID, ownerPID: 688,
        item: MenuBarItem(
            id: item, frame: ItemFrame(x: 0, y: 0, width: 46, height: 24), isMovable: false),
        isManaged: false)
}
