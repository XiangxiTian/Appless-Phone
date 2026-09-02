import AppKit
import Foundation

let symbols = [
    "magnifyingglass", "person.crop.circle", "ellipsis", "chevron.right",
    "chevron.left", "xmark", "square.and.arrow.up", "pin", "pin.fill",
    "line.3.horizontal", "minus.circle", "circle.inset.filled",
    "rectangle.3.group", "square.stack.3d.up", "sparkles", "arrow.up",
    "doc.text", "photo", "person.2", "checkmark", "clock", "paperclip",
    "folder", "arrow.right", "chevron.up", "chevron.down", "cellularbars",
    "wifi", "battery.100percent", "plus", "slider.horizontal.3", "pencil",
    "trash", "square.grid.2x2", "person", "calendar", "rectangle.stack",
    "mic.fill", "mic.slash.fill", "video.fill", "video.slash.fill",
    "square.fill", "play.fill", "eye.slash.fill"
]

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: swift export_symbols.swift OUTPUT_DIR\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: outputURL, withIntermediateDirectories: true)

let canvas = NSSize(width: 96, height: 96)
let configuration = NSImage.SymbolConfiguration(pointSize: 24, weight: .medium)

for name in symbols {
    guard let source = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration) else {
        fputs("Missing symbol: \(name)\n", stderr)
        continue
    }

    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(canvas.width),
        pixelsHigh: Int(canvas.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else { continue }

    bitmap.size = NSSize(width: 32, height: 32)
    NSGraphicsContext.saveGraphicsState()
    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else { continue }
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    NSColor.black.set()

    let symbolSize = source.size
    let scale = min(26 / symbolSize.width, 26 / symbolSize.height)
    let drawSize = NSSize(width: symbolSize.width * scale, height: symbolSize.height * scale)
    let drawRect = NSRect(
        x: (32 - drawSize.width) / 2,
        y: (32 - drawSize.height) / 2,
        width: drawSize.width,
        height: drawSize.height
    )
    source.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1)
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    if let data = bitmap.representation(using: .png, properties: [:]) {
        try data.write(to: outputURL.appendingPathComponent("\(name).png"))
    }
}
