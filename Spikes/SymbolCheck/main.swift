import AppKit
import Foundation

// Usage: swift main.swift <catalog.md> [--render <out.png>]
// Reads symbol names from the second column of the catalog table (names in backticks),
// checks that each resolves via NSImage(systemSymbolName:), exits 1 if any is missing.

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

func parseSymbols(_ markdown: String) -> [String] {
    markdown.split(separator: "\n").compactMap { line in
        let cells = line.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard cells.count >= 4, cells[2].hasPrefix("`"), cells[2].hasSuffix("`") else { return nil }
        return String(cells[2].dropFirst().dropLast())
    }
}

func render(_ symbols: [String], to path: String) {
    let columns = 8
    let cell = CGSize(width: 150, height: 64)
    let scale: CGFloat = 3
    let rows = (symbols.count + columns - 1) / columns
    let size = CGSize(width: cell.width * CGFloat(columns), height: cell.height * CGFloat(rows))
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(size.width * scale), pixelsHigh: Int(size.height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: rep) else { fail("cannot create bitmap") }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: scale, y: scale)
    NSColor.white.setFill()
    NSRect(origin: .zero, size: size).fill()

    let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
    let labelAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 7), .foregroundColor: NSColor.darkGray,
    ]
    for (index, name) in symbols.enumerated() {
        let originX = CGFloat(index % columns) * cell.width
        let originY = size.height - CGFloat(index / columns + 1) * cell.height
        guard let base = NSImage(systemSymbolName: name, accessibilityDescription: nil),
              let image = base.withSymbolConfiguration(config) else { continue }
        let target = NSRect(
            x: originX + (cell.width - image.size.width) / 2, y: originY + 28,
            width: image.size.width, height: image.size.height
        )
        // Template images draw as black in a plain context.
        image.draw(in: target)
        let label = NSAttributedString(string: name, attributes: labelAttributes)
        label.draw(at: NSPoint(x: originX + (cell.width - label.size().width) / 2, y: originY + 10))
    }
    NSGraphicsContext.restoreGraphicsState()

    guard let png = rep.representation(using: .png, properties: [:]) else { fail("cannot encode png") }
    let url = URL(fileURLWithPath: path)
    do {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try png.write(to: url)
    } catch {
        fail("cannot write \(path): \(error)")
    }
    print("preview written to \(path)")
}

var arguments = Array(CommandLine.arguments.dropFirst())
var renderPath: String?
if let flag = arguments.firstIndex(of: "--render") {
    guard flag + 1 < arguments.count else { fail("--render needs an output path") }
    renderPath = arguments[flag + 1]
    arguments.removeSubrange(flag...(flag + 1))
}
guard let catalogPath = arguments.first else { fail("usage: main.swift <catalog.md> [--render <out.png>]") }
guard let markdown = try? String(contentsOfFile: catalogPath, encoding: .utf8) else {
    fail("cannot read \(catalogPath)")
}

let symbols = parseSymbols(markdown)
guard !symbols.isEmpty else { fail("no symbols found in \(catalogPath)") }

let missing = symbols.filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil }
if !missing.isEmpty {
    print("missing \(missing.count) of \(symbols.count): \(missing.joined(separator: ", "))")
    exit(1)
}
print("all \(symbols.count) symbols resolve")
if let renderPath { render(symbols, to: renderPath) }
