import AppKit
import ScreenCaptureKit

struct SpikeError: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

/// Window screenshot through SCScreenshotManager. If ScreenCaptureKit does not list the window
/// as an SCWindow (status items may be absent from it), falls back to a display capture cropped
/// to the window bounds, the approach Ice uses on macOS 26 after CGWindowListCreateImage broke.
func runSnapshot(windowID: CGWindowID, outPath: String) async throws {
    guard CGPreflightScreenCaptureAccess() else {
        throw SpikeError("needs permission: Screen Recording is not granted to this process")
    }
    guard let target = Windows.find(windowID) else {
        throw SpikeError("window \(windowID) not found among menu bar windows")
    }
    let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
    let config = SCStreamConfiguration()
    config.showsCursor = false
    config.captureResolution = .best

    let filter: SCContentFilter
    let method: String
    if let scWindow = content.windows.first(where: { $0.windowID == windowID }) {
        filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let scale = CGFloat(filter.pointPixelScale)
        config.width = Int(scWindow.frame.width * scale)
        config.height = Int(scWindow.frame.height * scale)
        method = "SCContentFilter(desktopIndependentWindow:)"
    } else {
        guard let display = content.displays.first(where: { $0.frame.intersects(target.bounds) }) else {
            throw SpikeError("window \(windowID) is offscreen (no display intersects \(fmt(target.bounds)))")
        }
        filter = SCContentFilter(display: display, excludingWindows: [])
        let scale = CGFloat(filter.pointPixelScale)
        config.sourceRect = target.bounds.offsetBy(dx: -display.frame.minX, dy: -display.frame.minY)
        config.width = Int(target.bounds.width * scale)
        config.height = Int(target.bounds.height * scale)
        method = "display capture + sourceRect (window not in SCShareableContent.windows)"
    }

    let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
    guard let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
        throw SpikeError("PNG encoding failed")
    }
    try png.write(to: URL(fileURLWithPath: outPath))
    print("method: \(method)")
    print("saved \(outPath): \(image.width)x\(image.height) px, \(png.count) bytes")
}
