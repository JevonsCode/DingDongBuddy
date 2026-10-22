// Compile with TrayIcon.swift; pass artwork path and a temporary screenshot directory.
// Exercises real AppKit rendering with example counts, without sending reminders.
import AppKit
@main
enum TrayIconLayoutTest {
    static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let icon = TrayIcon()
        let asset = NSImage(contentsOfFile: CommandLine.arguments[1])!
        asset.size = NSSize(width: 22, height: 22)
        icon.setImage(asset, "left")
        icon.setToolTip("Sensitive reminder names")
        precondition(icon.statusItem!.button!.toolTip == nil)
        precondition(icon.statusItem!.button!.accessibilityLabel() == "Sensitive reminder names")
        precondition((icon.statusItem!.button!.cell as! NSButtonCell).highlightsBy.isEmpty)
        let bubbles: [[String: Any]] = [0xDB7333, 0xE95795, 0x397DDD, 0x29A071, 0x9575CD, 0x9B6B00].enumerated().map {
            ["id": "test-\($0.offset)", "name": "Reminder \($0.offset + 1)", "colorRgb": NSNumber(value: $0.element), "count": NSNumber(value: 1)]
        }
        func capture(_ name: String) throws {
         let image = NSImage(size: icon.bounds.size)
         image.lockFocus(); icon.draw(icon.bounds); image.unlockFocus()
         let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
         try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(CommandLine.arguments[2])/\(name).png"))
        }
        icon.setTitle(" 6", "unreadBadge", 0x9575CD)
        precondition(icon.frame.width < 55, "One digit must not reserve the former fixed width")
        icon.setTitle(" 6", "unreadBadge", 0x9575CD, bubbles, false)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        let collapsed = icon.frame.width
        try capture("collapsed")
        let event = NSEvent.mouseEvent(with: .mouseMoved, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil, eventNumber: 0, clickCount: 0, pressure: 0)!
        icon.mouseEntered(with: event)
        let reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !reducedMotion {
            precondition(icon.frame.width == collapsed, "Hover starts at the current position")
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.06))
            let midway = icon.frame.width
            precondition(midway > collapsed, "Animation must produce intermediate widths")
            try capture("midway")
            icon.setHoverExpanded(false)
            precondition(icon.frame.width == midway, "Reversing must not jump")
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.28))
            precondition(abs(icon.frame.width - collapsed) < 1)
            icon.setHoverExpanded(true)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.28))
        }
        let expanded = icon.frame.width
        precondition(expanded > collapsed)
        try capture("expanded")
        icon.setTitle(" 99+", "unreadBadge", 0x9575CD, bubbles, true)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        precondition(icon.frame.width > expanded)
        try capture("expanded-99")
        let largeExpanded = icon.frame.width
        icon.statusItem!.button!.highlight(true)
        icon.statusItem!.button!.state = .on
        icon.setHoverExpanded(false, animated: false)
        precondition(!icon.statusItem!.button!.isHighlighted && icon.statusItem!.button!.state == .off,
            "Collapsing clears retained native highlight/state")
        precondition(icon.frame.width < largeExpanded, "Reduced-motion path switches immediately")
        icon.setHoverExpanded(true)
        icon.setTitle("", "", nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.25))
        precondition(icon.statusItem!.length == NSStatusItem.squareLength)
        print("PASS: hover expands \(collapsed) -> \(expanded); continuous reversal and immediate switching pass; clearing cancels animation")
        // The same A item moves from the main capsule to the first trailing
        // circle when completion appears. Stable IDs preserve its position.
        let a: [String: Any] = ["id": "a", "colorRgb": NSNumber(value: 0xDB7333), "count": 2]
        let b: [String: Any] = ["id": "b", "colorRgb": NSNumber(value: 0xE95795), "count": 1]
        icon.setTitle(" 2", "unreadBadge", 0xDB7333, [b], false, "a")
        icon.setHoverExpanded(true, animated: false)
        try capture("ordered-before")
        let beforeInsert = icon.frame.width
        icon.setTitle(" 1", "unreadBadge", 0x9575CD, [a, b], false, "completion")
        if !reducedMotion { precondition(icon.frame.width == beforeInsert, "Inserting a type must start at the current width") }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.07))
        precondition(icon.frame.width > beforeInsert)
        try capture("ordered-midway")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        try capture("ordered-after")
        let beforeRemove = icon.frame.width
        icon.setTitle(" 2", "unreadBadge", 0xDB7333, [b], false, "a")
        if !reducedMotion { precondition(icon.frame.width == beforeRemove) }
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        precondition(icon.frame.width < beforeRemove)
        try capture("ordered-restored")
        print("PASS: ordered primary promotion, insertion and removal transitions")
        icon.setTitle(" 1", "unreadBadge", 0x9575CD, Array(bubbles.prefix(3)), false, "completion")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        try capture("four-types")
        let fourWidth = icon.frame.width
        icon.setTitle(" 1", "unreadBadge", 0x9575CD, Array(bubbles.prefix(4)), false, "completion")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        precondition(icon.frame.width <= fourWidth, "More than four types replaces the fourth slot with a circle, never adds a fifth slot")
        try capture("five-types")
        icon.setHoverExpanded(false, animated: false)
        try capture("five-types-stacked")
        let overflow = icon.makeOverflowContent()
        precondition(overflow != nil, "Five types must expose hidden reminder rows")
        precondition(overflow!.preferredContentSize.width == 36, "Only a narrow vertical strip")
        let firstRow = (overflow!.view.subviews.first as! NSScrollView).documentView!.subviews.first!
        precondition(firstRow.subviews.count == 1, "No visible reminder name")
        precondition(firstRow.accessibilityLabel() == "Reminder 3, 1", "Names remain accessible")
        precondition(icon.overflowItems.count == 2, "Show hidden fourth and fifth types")
        precondition(icon.overflowItems.first?["name"] as? String == "Reminder 3")
        func captureOverflow(_ controller: NSViewController, _ name: String, _ appearance: NSAppearance.Name) throws {
            let view = controller.view
            view.appearance = NSAppearance(named: appearance)
            view.layoutSubtreeIfNeeded()
            let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds)!
            view.cacheDisplay(in: view.bounds, to: bitmap)
            let image = NSImage(size: view.bounds.size)
            image.lockFocus()
            NSAppearance(named: appearance)!.performAsCurrentDrawingAppearance {
                NSColor.clear.setFill()
                view.bounds.fill(using: .copy)
            }
            NSImage(cgImage: bitmap.cgImage!, size: view.bounds.size).draw(in: view.bounds)
            image.unlockFocus()
            let composed = NSBitmapImageRep(data: image.tiffRepresentation!)!
            try composed.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(CommandLine.arguments[2])/\(name).png"))
        }
        try captureOverflow(overflow!, "overflow-list-light", .aqua)
        try captureOverflow(overflow!, "overflow-list-dark", .darkAqua)
        icon.showOverflow(animated: false)
        let panel = NSApp.windows.first { $0.identifier?.rawValue == "dingdong.reminder-overflow" }!
        precondition(panel is NSPanel && !panel.styleMask.contains(.titled))
        precondition(panel.styleMask.contains(.nonactivatingPanel) && !panel.isKeyWindow)
        precondition(panel.frame.size == overflow!.preferredContentSize, "Capsule has no arrow/chrome")
        icon.setTitle(" 1", "unreadBadge", 0x9575CD, Array(bubbles.prefix(3)), false, "completion")
        precondition(!panel.isVisible, "Four types dismiss the capsule and its monitors")
        var clicked = false
        icon.onTrayIconMouseDown = { clicked = true }
        icon.mouseDown(with: event)
        precondition(clicked && !icon.statusItem!.button!.isHighlighted, "Press keeps the action without a highlight")

        let many = (0..<40).map { index -> [String: Any] in
            ["id": "many-\(index)", "name": "Reminder \(index + 1)", "colorRgb": 0xDB7333, "count": index + 1]
        }
        icon.setTitle(" 1", "unreadBadge", 0x9575CD, many, false, "completion")
        let scrolled = icon.makeOverflowContent()!
        precondition(scrolled.preferredContentSize.height <= 272)
        precondition(icon.overflowItems.count == 38)
        precondition((scrolled.view.subviews.first as! NSScrollView).documentView!.subviews.count == 38)
        try captureOverflow(scrolled, "overflow-list-scroll", .aqua)

        icon.setTitle(" 1", "unreadBadge", 0x9575CD, Array(bubbles.prefix(3)), false, "completion")
        precondition(icon.makeOverflowContent() == nil, "Four types have no overflow popover")
        print("PASS: overflow rows keep array order; bounded scrolling; four-type threshold")
        NSStatusBar.system.removeStatusItem(icon.statusItem!)

    }
}
