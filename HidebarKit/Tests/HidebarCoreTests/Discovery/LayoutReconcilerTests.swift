import Foundation
import Testing

@testable import HidebarCore

@Suite struct LayoutReconcilerTests {
    private let a = itemID("com.a")
    private let b = itemID("com.b", "Title")
    private let c = itemID("com.c")
    private let d = itemID("com.d")

    @Test func newManagedItemsGoToVisibleInBarOrder() throws {
        let result = try LayoutReconciler.reconcile(
            discovered: [managed(b), managed(a)], stored: .empty)
        #expect(result.visible == [b, a])
        #expect(result.hidden.isEmpty)
        #expect(result.groups.isEmpty)
    }

    @Test func newItemsAreAppendedAfterStoredVisible() throws {
        let stored = try Layout(visible: [c], hidden: [], groups: [])
        let result = try LayoutReconciler.reconcile(discovered: [managed(a), managed(c)], stored: stored)
        #expect(result.visible == [c, a])
    }

    @Test func knownItemsKeepTheirPlaceInHiddenAndGroups() throws {
        let group = try makeGroup(items: [c])
        let stored = try Layout(visible: [a], hidden: [b], groups: [group])
        let result = try LayoutReconciler.reconcile(
            discovered: [managed(a), managed(b), managed(c), managed(d)], stored: stored)
        #expect(result.visible == [a, d])
        #expect(result.hidden == [b])
        #expect(result.groups == [group])
    }

    @Test func itemsMissingRightNowAreKept() throws {
        let group = try makeGroup(items: [c])
        let stored = try Layout(visible: [a], hidden: [b], groups: [group])
        let result = try LayoutReconciler.reconcile(discovered: [], stored: stored)
        #expect(result == stored)
    }

    @Test func partiallyMissingItemsAreKeptWhileOthersAreAdded() throws {
        let stored = try Layout(visible: [a], hidden: [b], groups: [])
        let result = try LayoutReconciler.reconcile(discovered: [managed(d)], stored: stored)
        #expect(result.visible == [a, d])
        #expect(result.hidden == [b])
    }

    @Test func unmanagedItemsAreNeverWritten() throws {
        let result = try LayoutReconciler.reconcile(
            discovered: [unmanaged(a), managed(b), unmanaged(c)], stored: .empty)
        #expect(result.visible == [b])
    }

    @Test func storedIDOfNowUnmanagedItemIsNotRemoved() throws {
        let stored = try Layout(visible: [], hidden: [a], groups: [])
        let result = try LayoutReconciler.reconcile(discovered: [unmanaged(a)], stored: stored)
        #expect(result == stored)
    }

    @Test func repeatedManagedIDIsAddedOnce() throws {
        let result = try LayoutReconciler.reconcile(
            discovered: [managed(a, windowID: 1), managed(a, windowID: 2)], stored: .empty)
        #expect(result.visible == [a])
    }

    @Test func reconcilingTwiceChangesNothing() throws {
        let first = try LayoutReconciler.reconcile(discovered: [managed(a), managed(b)], stored: .empty)
        let second = try LayoutReconciler.reconcile(discovered: [managed(a), managed(b)], stored: first)
        #expect(second == first)
    }

    @Test func twoUntitledItemsOfOneBundleNeverReachTheLayout() throws {
        let rows = [window(1, x: 10), window(2, x: 60), window(3, x: 110)]
        let owners = [
            1: ItemOwner(bundleID: "com.twin", title: ""),
            2: ItemOwner(bundleID: "com.twin", title: ""),
            3: ItemOwner(bundleID: "com.solo", title: ""),
        ]
        let result = try LayoutReconciler.reconcile(
            discovered: discover(rows, owners: owners), stored: .empty)
        #expect(result.visible == [itemID("com.solo")])
    }

    @Test func realOwnerWithoutAccessibilityNeverReachesTheLayout() throws {
        let rows = [
            window(8, x: 10, owner: "com.apple.systemuiserver"),
            window(9, x: 60, owner: "com.example.app", title: "Status"),
        ]
        let result = try LayoutReconciler.reconcile(discovered: discover(rows), stored: .empty)
        #expect(result == .empty)
    }

    @Test func controlCenterItemsWithoutAccessibilityNeverReachTheLayout() throws {
        let rows = [window(21, x: 1566), window(19, x: 1612, width: 118)]
        let result = try LayoutReconciler.reconcile(discovered: discover(rows), stored: .empty)
        #expect(result == .empty)
    }
}
