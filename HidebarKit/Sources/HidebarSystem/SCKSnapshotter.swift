import CoreGraphics
import HidebarCore
import ScreenCaptureKit

/// Captures one window through ScreenCaptureKit. Any failure is a nil snapshot.
@MainActor
public struct SCKSnapshotter: Snapshotting {
    public init() {}

    public func snapshot(ofWindow windowID: Int) async -> SnapshotImage? {
        let content = try? await SCShareableContent.excludingDesktopWindows(
            false, onScreenWindowsOnly: false)
        let window = content?.windows.firstWindow(withID: windowID) { Int($0.windowID) }
        guard let window else { return nil }
        return try? await capture(window)
    }

    private func capture(_ window: SCWindow) async throws -> SnapshotImage {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let scale = CGFloat(filter.pointPixelScale)
        let configuration = SCStreamConfiguration()
        configuration.showsCursor = false
        configuration.captureResolution = .best
        configuration.width = Int(window.frame.width * scale)
        configuration.height = Int(window.frame.height * scale)
        let image = try await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: configuration)
        return SnapshotImage(payload: image)
    }
}
