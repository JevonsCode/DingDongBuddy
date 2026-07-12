import AppKit
import Foundation

let symbols: [(file: String, name: String)] = [
    ("refresh", "arrow.clockwise"),
    ("settings", "gearshape"),
    ("collapse", "chevron.up"),
    ("today", "sparkles"),
    ("library", "square.stack.3d.up"),
    ("clipboard", "doc.on.clipboard"),
    ("search", "magnifyingglass"),
    ("filter", "line.3.horizontal.decrease"),
    ("details", "sidebar.right"),
    ("add_title", "textformat"),
    ("archive", "archivebox"),
    ("archive_to", "folder.badge.plus"),
    ("share", "square.and.arrow.up"),
    ("close", "xmark"),
    ("manage", "rectangle.stack"),
    ("prompt", "text.quote"),
    ("skill", "wand.and.sparkles"),
    ("mcp", "server.rack"),
    ("knowledge", "folder"),
    ("enabled", "checkmark.circle.fill"),
    ("paused", "pause.circle"),
    ("copy", "doc.on.doc"),
    ("edit", "pencil"),
    ("delete", "trash"),
    ("link", "link"),
    ("text", "doc.on.clipboard"),
    ("file", "doc"),
    ("code", "chevron.left.forwardslash.chevron.right"),
    ("path", "folder"),
    ("sensitive", "lock.shield"),
    ("command", "terminal"),
    ("image", "photo")
]

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: swift export_popup_symbols.swift OUTPUT_DIRECTORY")
}

let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(
    at: outputDirectory,
    withIntermediateDirectories: true
)

// Keep only a small optical margin. A 64pt canvas made a 30pt glyph render at
// half the requested Flutter size, which caused the inconsistent tiny icons.
let canvasSize = NSSize(width: 36, height: 36)
let configuration = NSImage.SymbolConfiguration(pointSize: 30, weight: .regular)

for symbol in symbols {
    guard let source = NSImage(systemSymbolName: symbol.name, accessibilityDescription: nil)?
        .withSymbolConfiguration(configuration)
    else {
        fatalError("Missing SF Symbol: \(symbol.name)")
    }
    let rendered = NSImage(size: canvasSize)
    rendered.lockFocus()
    NSColor.black.set()
    let sourceSize = source.size
    let origin = NSPoint(
        x: (canvasSize.width - sourceSize.width) / 2,
        y: (canvasSize.height - sourceSize.height) / 2
    )
    source.draw(
        in: NSRect(origin: origin, size: sourceSize),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )
    rendered.unlockFocus()

    guard let tiff = rendered.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:])
    else {
        fatalError("Could not render SF Symbol: \(symbol.name)")
    }
    try png.write(to: outputDirectory.appendingPathComponent("\(symbol.file).png"))
}
