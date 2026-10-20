import Foundation
import Testing

@testable import HidebarCore

@MainActor @Suite struct GroupPanelViewModelTests {
    private let snapshotter = FakeSnapshotter()
    private let full = PermissionsState(accessibility: true, screenRecording: true).capabilities
    private let accessibilityOnly = PermissionsState(accessibility: true, screenRecording: false).capabilities
    private let screenRecordingOnly = PermissionsState(accessibility: false, screenRecording: true).capabilities
    private let none = PermissionsState(accessibility: false, screenRecording: false).capabilities

    private var viewModel: GroupPanelViewModel {
        GroupPanelViewModel(
            snapshotter: snapshotter,
            names: ItemNames(apps: StubAppNames(names: ["com.example.app": "Example"])))
    }

    private func group(_ names: String...) -> ItemGroup {
        ItemGroup(id: UUID(), symbol: try! GroupSymbol(name: "star"), items: names.map(moveID))
    }

    private func image() -> SnapshotImage { SnapshotImage(payload: FakeImage()) }

    @Test func fullAccessGivesSnapshotsInGroupOrderFromTheManagedWindows() async {
        let a = image()
        let b = image()
        snapshotter.images = [11: a, 22: b]
        let model = viewModel
        await model.refresh(
            group: group("b", "a"),
            items: [discovered("a", windowID: 11), discovered("b", windowID: 22)], capabilities: full)
        #expect(model.rows.map(\.id) == [moveID("b"), moveID("a")])
        #expect(model.rows.map(\.content) == [.snapshot(b), .snapshot(a)])
        #expect(model.rows.map(\.isClickable) == [true, true])
        #expect(snapshotter.requested == [22, 11])
        #expect(!model.isEmpty)
    }

    @Test func accessibilityOnlyShowsAppNamesAndNeverCaptures() async {
        let model = viewModel
        await model.refresh(group: group("a"), items: [discovered("a", windowID: 11)], capabilities: accessibilityOnly)
        #expect(model.rows.map(\.content) == [.appName])
        #expect(model.rows.map(\.isClickable) == [true])
        #expect(snapshotter.requested.isEmpty)
    }

    @Test func screenRecordingOnlyCannotIdentifyOwnersSoNothingIsMatchedOrClickable() async {
        snapshotter.images = [11: image()]
        let model = viewModel
        await model.refresh(group: group("a"), items: [discovered("a", windowID: 11)], capabilities: screenRecordingOnly)
        #expect(model.rows.map(\.content) == [.appName])
        #expect(model.rows.map(\.isClickable) == [false])
        #expect(snapshotter.requested.isEmpty)
    }

    @Test func noPermissionsShowsAppNamesThatCannotBeClicked() async {
        let model = viewModel
        await model.refresh(group: group("a", "b"), items: [discovered("a")], capabilities: none)
        #expect(model.rows.map(\.content) == [.appName, .appName])
        #expect(model.rows.map(\.isClickable) == [false, false])
        #expect(snapshotter.requested.isEmpty)
    }

    @Test func iconMissingFromDiscoveryKeepsItsRowInPlaceAsUnavailable() async {
        let a = image()
        let c = image()
        snapshotter.images = [11: a, 33: c]
        let model = viewModel
        await model.refresh(
            group: group("a", "gone", "c"),
            items: [discovered("a", windowID: 11), discovered("c", windowID: 33)], capabilities: full)
        #expect(model.rows.map(\.id) == [moveID("a"), moveID("gone"), moveID("c")])
        #expect(model.rows.map(\.content) == [.snapshot(a), .unavailable, .snapshot(c)])
        #expect(model.rows.map(\.isClickable) == [true, false, true])
        #expect(snapshotter.requested == [11, 33])
    }

    @Test func unmanagedItemWithTheSameIdIsNeverMatched() async {
        snapshotter.images = [99: image(), 11: image()]
        let model = viewModel
        await model.refresh(
            group: group("a"),
            items: [discovered("a", windowID: 99, managed: false), discovered("a", windowID: 11)],
            capabilities: full)
        #expect(snapshotter.requested == [11])

        let lone = viewModel
        await lone.refresh(
            group: group("a"), items: [discovered("a", windowID: 99, managed: false)], capabilities: full)
        #expect(lone.rows.map(\.content) == [.unavailable])
        #expect(lone.rows.map(\.isClickable) == [false])
        #expect(snapshotter.requested == [11])
    }

    @Test func unmovableManagedItemIsShownButNotClickable() async {
        let a = image()
        snapshotter.images = [11: a]
        let model = viewModel
        await model.refresh(
            group: group("a"), items: [discovered("a", windowID: 11, movable: false)], capabilities: full)
        #expect(model.rows.map(\.content) == [.snapshot(a)])
        #expect(model.rows.map(\.isClickable) == [false])
    }

    @Test func itemThatCannotBeClickedWithoutMovePermissionStillGetsItsSnapshot() async {
        let move = Capabilities(canHide: true, canMove: false, canIdentifyOwners: true, canSnapshot: true)
        let a = image()
        snapshotter.images = [11: a]
        let model = viewModel
        await model.refresh(group: group("a"), items: [discovered("a", windowID: 11)], capabilities: move)
        #expect(model.rows.map(\.content) == [.snapshot(a)])
        #expect(model.rows.map(\.isClickable) == [false])
    }

    @Test func failedCaptureKeepsTheAppNameAndDoesNotStopTheOthers() async {
        let b = image()
        snapshotter.images = [22: b]
        let model = viewModel
        await model.refresh(
            group: group("a", "b"),
            items: [discovered("a", windowID: 11), discovered("b", windowID: 22)], capabilities: full)
        #expect(model.rows.map(\.content) == [.appName, .snapshot(b)])
        #expect(snapshotter.requested == [11, 22])
    }

    @Test func rowNameIsTheAppNameWithTheTitleOrTheBundleIdOfAnUnknownApp() async {
        let titled = MenuBarItemID(ownerBundleID: "com.example.app", title: "Sync")
        let untitled = MenuBarItemID(ownerBundleID: "com.example.other", title: "")
        let model = viewModel
        await model.refresh(
            group: ItemGroup(id: UUID(), symbol: try! GroupSymbol(name: "star"), items: [titled, untitled]),
            items: [], capabilities: none)
        #expect(model.rows.map(\.name) == ["Example — Sync", "com.example.other"])
    }

    @Test func emptyGroupIsTheEmptyState() async {
        let model = viewModel
        #expect(model.isEmpty)
        await model.refresh(group: group("a"), items: [], capabilities: full)
        #expect(!model.isEmpty)
        await model.refresh(group: group(), items: [discovered("a")], capabilities: full)
        #expect(model.isEmpty)
        #expect(model.rows.isEmpty)
        #expect(snapshotter.requested.isEmpty)
    }

    @Test func newRefreshReplacesTheRowsOfTheOldOne() async {
        let model = viewModel
        await model.refresh(group: group("a"), items: [], capabilities: full)
        await model.refresh(group: group("b"), items: [], capabilities: full)
        #expect(model.rows.map(\.id) == [moveID("b")])
    }

    @Test func snapshotArrivingAfterANewerRefreshIsDropped() async {
        let stale = image()
        let fresh = image()
        snapshotter.images = [11: stale]
        snapshotter.holdWindows = [11]
        let model = viewModel
        let items = [discovered("a", windowID: 11), discovered("b", windowID: 22)]
        let first = Task { await model.refresh(group: group("a", "b"), items: items, capabilities: full) }
        // Bounded: a broken match must fail this test, not hang the whole run.
        for _ in 0..<100 where snapshotter.requested.isEmpty { await Task.yield() }

        snapshotter.holdWindows = []
        snapshotter.images = [11: fresh]
        await model.refresh(group: group("a"), items: items, capabilities: full)
        snapshotter.release(11)
        await first.value

        #expect(model.rows.map(\.content) == [.snapshot(fresh)])
        #expect(snapshotter.requested == [11, 11])
    }

    @Test func snapshotImagesAreEqualOnlyForTheSamePayload() {
        let payload = FakeImage()
        #expect(SnapshotImage(payload: payload) == SnapshotImage(payload: payload))
        #expect(SnapshotImage(payload: payload) != SnapshotImage(payload: FakeImage()))
    }
}
