import HidebarCore
import ServiceManagement

/// The app's own login item, kept by the system (System Settings → General → Login Items).
public struct SMAppServiceLoginItem: LoginItemControlling {
    public init() {}

    public var status: LoginItemStatus {
        LoginItemStatus(serviceStatusRawValue: SMAppService.mainApp.status.rawValue)
    }

    public func register() throws {
        try SMAppService.mainApp.register()
    }

    public func unregister() throws {
        try SMAppService.mainApp.unregister()
    }

    public func openSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
