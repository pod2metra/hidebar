import Foundation

/// Minimal byte storage the layout is persisted in; adapters (UserDefaults, a file) conform to it.
public protocol KeyValueStore: Sendable {
    func data(forKey key: String) -> Data?
    func set(_ data: Data, forKey key: String) throws
}

public enum LayoutStoreError: Error, Equatable, Sendable {
    /// Stored layout has a version this build cannot read. `load` leaves the bytes untouched.
    case unsupportedVersion(Int)
    /// `save` found stored data of an unsupported version and wrote nothing.
    case refusingToOverwriteNewerVersion(Int)
}

public enum LayoutLoadStatus: Equatable, Sendable {
    case missing
    case loaded
    /// Stored bytes were unreadable; `layout` is empty and the bytes are still in the store.
    case recoveredFromCorruption(reason: String)
}

public struct LayoutLoadResult: Equatable, Sendable {
    public let layout: Layout
    public let status: LayoutLoadStatus
}

/// Loads and saves the `Layout` as JSON under one key of a `KeyValueStore`.
public struct LayoutStore: Sendable {
    public static let defaultKey = "hidebar.layout"

    private struct VersionProbe: Decodable {
        let version: Int
    }

    private let store: any KeyValueStore
    private let key: String

    public init(store: any KeyValueStore, key: String = LayoutStore.defaultKey) {
        self.store = store
        self.key = key
    }

    /// Where unreadable bytes are copied to before `save` overwrites them.
    public var backupKey: String { key + ".corrupt-backup" }

    /// The stored layout with a status telling whether it was found, read, or recovered from garbage.
    ///
    /// Never writes: unreadable data stays in the store until the first explicit `save`, so a
    /// transient bug cannot destroy the user's layout by merely launching the app. A well-formed
    /// layout of an unknown version is an error instead, never an empty fallback.
    public func load() throws -> LayoutLoadResult {
        guard let data = store.data(forKey: key) else {
            return LayoutLoadResult(layout: .empty, status: .missing)
        }
        return try LayoutStore.classify(data)
    }

    /// Writes `layout`. Stored bytes that are corrupt are first copied to `backupKey`, unless a
    /// backup already exists. Stored data of an unsupported version is never overwritten: it
    /// belongs to another build of the app, so this throws `refusingToOverwriteNewerVersion`.
    public func save(_ layout: Layout) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let encoded = try encoder.encode(layout)
        if let stored = store.data(forKey: key) {
            try backUpIfCorrupt(stored)
        }
        try store.set(encoded, forKey: key)
    }

    private func backUpIfCorrupt(_ stored: Data) throws {
        let status: LayoutLoadStatus
        do {
            status = try LayoutStore.classify(stored).status
        } catch LayoutStoreError.unsupportedVersion(let version) {
            throw LayoutStoreError.refusingToOverwriteNewerVersion(version)
        }
        if case .recoveredFromCorruption = status, store.data(forKey: backupKey) == nil {
            try store.set(stored, forKey: backupKey)
        }
    }

    private static func classify(_ data: Data) throws -> LayoutLoadResult {
        let probe: VersionProbe
        do {
            probe = try JSONDecoder().decode(VersionProbe.self, from: data)
        } catch {
            return corrupt(error)
        }
        return try migrate(data, from: probe.version)
    }

    /// Migration hook: one case per stored version, each producing a current-version `Layout`.
    private static func migrate(_ data: Data, from version: Int) throws -> LayoutLoadResult {
        switch version {
        case Layout.currentVersion:
            do {
                let layout = try JSONDecoder().decode(Layout.self, from: data)
                return LayoutLoadResult(layout: layout, status: .loaded)
            } catch {
                return corrupt(error)
            }
        default:
            throw LayoutStoreError.unsupportedVersion(version)
        }
    }

    private static func corrupt(_ error: any Error) -> LayoutLoadResult {
        LayoutLoadResult(
            layout: .empty, status: .recoveredFromCorruption(reason: String(describing: error)))
    }
}
