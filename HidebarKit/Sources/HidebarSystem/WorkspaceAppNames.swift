import AppKit
import HidebarCore

/// App names from the installed app's own Info.plist. `object(forInfoDictionaryKey:)` already
/// answers with the localized value, and unlike the file name it does not depend on whether
/// Finder shows extensions.
public struct WorkspaceAppNames: AppNaming {
    public init() {}

    public func name(ofBundleID bundleID: String) -> String? {
        let bundle = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
            .flatMap { Bundle(url: $0) }
        return ["CFBundleDisplayName", "CFBundleName"].lazy
            .compactMap { bundle?.object(forInfoDictionaryKey: $0) as? String }
            .first
    }
}
