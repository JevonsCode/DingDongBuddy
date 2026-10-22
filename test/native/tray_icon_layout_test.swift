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
        let bubbles: [[String: Any]] = [0xDB7333, 0xE95795, 0x397DDD, 0x29A071, 0x9575CD, 0x9B6B00].map { ["colorRgb": NSNumber(value: $0), "count": NSNumber(value: 1)] }
        func capture(_ name: String) throws {
         let image = NSImage(size: icon.bounds.size)
         image.lockFocus(); icon.draw(icon.bounds); image.unlockFocus()
         let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
         try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(CommandLine.arguments[2])/\(name).png"))
        }
        icon.setTitle(" 6", "unreadBadge", 0x9575CD)
        precondition(icon.frame.width < 55, "One digit must not reserve the former fixed width")
        icon.setTitle(" 6", "unreadBadge", 0x9575CD, bubbles, false)
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
        precondition(icon.frame.width > expanded)
        try capture("expanded-99")
        let largeExpanded = icon.frame.width
        icon.setHoverExpanded(false, animated: false)
        precondition(icon.frame.width < largeExpanded, "Reduced-motion path switches immediately")
        icon.setHoverExpanded(true)
        icon.setTitle("", "", nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.25))
        precondition(icon.statusItem!.length == NSStatusItem.squareLength)
        print("PASS: hover expands \(collapsed) -> \(expanded); continuous reversal and immediate switching pass; clearing cancels animation")
        NSStatusBar.system.removeStatusItem(icon.statusItem!)

    }
}
