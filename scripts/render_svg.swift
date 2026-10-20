// Renders an SVG into square PNGs at exact pixel sizes.
// Usage: swift scripts/render_svg.swift <logo.svg> <pixels>=<out.png> [<pixels>=<out.png> ...]
import AppKit

let arguments = CommandLine.arguments
guard arguments.count >= 3, let svg = NSImage(contentsOf: URL(fileURLWithPath: arguments[1])) else {
    FileHandle.standardError.write(Data("render_svg: cannot load the SVG or no outputs given\n".utf8))
    exit(1)
}

for spec in arguments.dropFirst(2) {
    let parts = spec.split(separator: "=", maxSplits: 1).map(String.init)
    guard parts.count == 2, let pixels = Int(parts[0]), pixels > 0 else {
        FileHandle.standardError.write(Data("render_svg: bad spec \(spec)\n".utf8))
        exit(1)
    }
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        FileHandle.standardError.write(Data("render_svg: no bitmap for \(pixels)px\n".utf8))
        exit(1)
    }
    bitmap.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    svg.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        FileHandle.standardError.write(Data("render_svg: PNG encoding failed for \(pixels)px\n".utf8))
        exit(1)
    }
    try png.write(to: URL(fileURLWithPath: parts[1]))
}
