import Foundation
import Synchronization
import Testing

@testable import HidebarCore

final class InMemoryStore: KeyValueStore {
    struct WriteFailure: Error {}

    private let storage = Mutex<[String: Data]>([:])
    private let failingKeys: Set<String>

    init(_ initial: [String: Data] = [:], failingKeys: Set<String> = []) {
        storage.withLock { $0 = initial }
        self.failingKeys = failingKeys
    }

    func data(forKey key: String) -> Data? {
        storage.withLock { $0[key] }
    }

    func set(_ data: Data, forKey key: String) throws {
        if failingKeys.contains(key) { throw WriteFailure() }
        storage.withLock { $0[key] = data }
    }
}

@Suite struct LayoutStoreTests {
    private let key = LayoutStore.defaultKey

    private func sampleLayout() throws -> Layout {
        try Layout(
            visible: [itemID("com.a")],
            hidden: [itemID("com.b", "Title")],
            groups: [try makeGroup(items: [itemID("com.c")])])
    }

    private func isRecovered(_ status: LayoutLoadStatus) -> Bool {
        if case .recoveredFromCorruption(let reason) = status { return !reason.isEmpty }
        return false
    }

    @Test func missingKeyLoadsEmptyLayoutWithMissingStatus() throws {
        let result = try LayoutStore(store: InMemoryStore()).load()
        #expect(result.layout == .empty)
        #expect(result.status == .missing)
    }

    @Test func saveThenLoadRoundTripsWithLoadedStatus() throws {
        let backing = InMemoryStore()
        let layout = try sampleLayout()
        try LayoutStore(store: backing).save(layout)
        let result = try LayoutStore(store: backing).load()
        #expect(result.layout == layout)
        #expect(result.status == .loaded)
    }

    @Test func backupKeyIsDerivedFromKey() {
        #expect(LayoutStore(store: InMemoryStore()).backupKey == "hidebar.layout.corrupt-backup")
        #expect(LayoutStore(store: InMemoryStore(), key: "k").backupKey == "k.corrupt-backup")
    }

    @Test func savingOverMissingOrLoadedDataMakesNoBackup() throws {
        let backing = InMemoryStore()
        let store = LayoutStore(store: backing)
        try store.save(.empty)
        try store.save(try sampleLayout())
        #expect(backing.data(forKey: store.backupKey) == nil)
    }

    @Test func saveWritesUnderTheConfiguredKey() throws {
        let backing = InMemoryStore()
        try LayoutStore(store: backing, key: "custom").save(.empty)
        #expect(backing.data(forKey: "custom") != nil)
        #expect(backing.data(forKey: key) == nil)
    }

    @Test func saveWritesSortedJSONWithVersion() throws {
        let backing = InMemoryStore()
        try LayoutStore(store: backing).save(.empty)
        let json = String(decoding: try #require(backing.data(forKey: key)), as: UTF8.self)
        #expect(json == #"{"groups":[],"hidden":[],"version":1,"visible":[]}"#)
    }

    @Test func saveSurfacesStoreFailure() {
        let store = LayoutStore(store: InMemoryStore(failingKeys: [LayoutStore.defaultKey]))
        #expect(throws: InMemoryStore.WriteFailure.self) {
            try store.save(.empty)
        }
    }

    @Test(arguments: [
        "not json at all",
        "",
        "{",
        "[]",
        #"{"visible":[],"hidden":[],"groups":[]}"#,
        #"{"version":"1","visible":[],"hidden":[],"groups":[]}"#,
        #"{"version":1,"visible":"x","hidden":[],"groups":[]}"#,
        #"{"version":1,"visible":[],"hidden":[],"groups":[{"id":"not-a-uuid","symbol":"star","items":[]}]}"#,
        #"{"version":1,"visible":[],"hidden":[],"groups":[{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","symbol":"bogus","items":[]}]}"#,
        #"{"version":1,"visible":[{"ownerBundleID":"a","title":""}],"hidden":[{"ownerBundleID":"a","title":""}],"groups":[]}"#,
    ])
    func corruptJSONLoadsEmptyLayoutAndLeavesStoreUntouched(_ raw: String) throws {
        let original = Data(raw.utf8)
        let backing = InMemoryStore([key: original])
        let store = LayoutStore(store: backing)
        let result = try store.load()
        #expect(result.layout == .empty)
        #expect(isRecovered(result.status))
        #expect(backing.data(forKey: key) == original)
        #expect(backing.data(forKey: store.backupKey) == nil)
    }

    @Test func firstSaveBacksUpCorruptBytesThenOverwrites() throws {
        let original = Data("garbage".utf8)
        let backing = InMemoryStore([key: original])
        let store = LayoutStore(store: backing)
        _ = try store.load()
        let layout = try sampleLayout()
        try store.save(layout)
        #expect(backing.data(forKey: store.backupKey) == original)
        #expect(try store.load().layout == layout)
        #expect(try store.load().status == .loaded)
    }

    @Test func backupIsTakenOnlyOnce() throws {
        let original = Data("garbage".utf8)
        let backing = InMemoryStore([key: original])
        let store = LayoutStore(store: backing)
        try store.save(try sampleLayout())
        try backing.set(Data("second garbage".utf8), forKey: key)
        try store.save(.empty)
        #expect(backing.data(forKey: store.backupKey) == original)
    }

    @Test func existingBackupIsNeverOverwritten() throws {
        let oldBackup = Data("old backup".utf8)
        let backing = InMemoryStore([
            key: Data("newer garbage".utf8), LayoutStore(store: InMemoryStore()).backupKey: oldBackup,
        ])
        let store = LayoutStore(store: backing)
        try store.save(.empty)
        #expect(backing.data(forKey: store.backupKey) == oldBackup)
        #expect(try store.load().status == .loaded)
    }

    @Test func failedBackupWriteLeavesCorruptBytesInPlace() throws {
        let original = Data("garbage".utf8)
        let backupKey = LayoutStore(store: InMemoryStore()).backupKey
        let backing = InMemoryStore([key: original], failingKeys: [backupKey])
        #expect(throws: InMemoryStore.WriteFailure.self) {
            try LayoutStore(store: backing).save(.empty)
        }
        #expect(backing.data(forKey: key) == original)
    }

    @Test(arguments: [2, 99, 0, -1])
    func unsupportedVersionThrowsAndLeavesStoreUntouched(_ version: Int) {
        let original = Data(#"{"version":\#(version),"payload":{"anything":true}}"#.utf8)
        let backing = InMemoryStore([key: original])
        let store = LayoutStore(store: backing)
        #expect(throws: LayoutStoreError.unsupportedVersion(version)) {
            try store.load()
        }
        #expect(backing.data(forKey: key) == original)
        #expect(backing.data(forKey: store.backupKey) == nil)
    }

    @Test(arguments: [false, true])
    func savingOverUnsupportedVersionIsRefusedAndWritesNothing(_ backupExists: Bool) {
        let original = Data(#"{"version":99}"#.utf8)
        let oldBackup = Data("old backup".utf8)
        let backupKey = LayoutStore(store: InMemoryStore()).backupKey
        let backing = InMemoryStore(backupExists ? [key: original, backupKey: oldBackup] : [key: original])
        #expect(throws: LayoutStoreError.refusingToOverwriteNewerVersion(99)) {
            try LayoutStore(store: backing).save(.empty)
        }
        #expect(backing.data(forKey: key) == original)
        #expect(backing.data(forKey: backupKey) == (backupExists ? oldBackup : nil))
    }
}
