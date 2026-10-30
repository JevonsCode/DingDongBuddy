import AppKit

@main
enum NotchBubbleOverflowTest {
    static func main() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        guard let screen = NSScreen.screens.first(where: { NotchBubbleGeometry.forScreen($0) != nil }),
              let geometry = NotchBubbleGeometry.forScreen(screen) else {
            print("SKIP: no display with a camera housing")
            return
        }
        var fillers = [NSStatusItem]()
        for _ in 0..<24 {
            let item = NSStatusBar.system.statusItem(withLength: 42)
            item.button?.title = " "
            fillers.append(item)
        }
        defer { fillers.forEach { NSStatusBar.system.removeStatusItem($0) } }
        let icon = TrayIcon()
        let artwork = NSImage(contentsOfFile: CommandLine.arguments[1])!
        artwork.size = NSSize(width: 22, height: 22)
        icon.setImage(artwork, "left")
        icon.setNotchBubbleDirection("down")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.8))
        if let button = icon.statusItem?.button, let window = button.window {
            let frame = window.convertToScreen(button.convert(button.bounds, to: nil))
            print("Crowded status item frame: \(frame), isVisible: \(icon.statusItem?.isVisible == true)")
        } else {
            print("Crowded status item has no accessible window")
        }
        fflush(stdout)
        let hoverPoint = NSPoint(x: geometry.notch.midX, y: geometry.notch.midY)
        icon.handleNotchHover(at: hoverPoint)
        let hoverTimer = Timer(timeInterval: 0.03, repeats: true) { _ in
            icon.handleNotchHover(at: hoverPoint)
        }
        RunLoop.main.add(hoverTimer, forMode: .common)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))
        let hoverPanel = app.windows.first { $0.identifier?.rawValue == "dingdong.notch-preview" }
        precondition(hoverPanel?.isVisible == true, "Moving to the notch must reveal the hidden icon")
        hoverTimer.invalidate()
        icon.setNotchBubbleDirection("off")
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.3))
        precondition(hoverPanel?.isVisible == false)
        icon.showNotchReminderIfHidden()
        precondition(hoverPanel?.isVisible == false, "Off must not reveal hidden reminders")
        for direction in ["down", "left"] {
            icon.setNotchBubbleDirection(direction)
            icon.setTitle(" 1", "unreadBadge", 0x9575CD)
            icon.showNotchReminderIfHidden()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.9))
            let panel = app.windows.first { $0.identifier?.rawValue == "dingdong.notch-preview" }
            precondition(panel?.isVisible == true, "A hidden reminder must be revealed")
            // Legacy down settings migrate to the same left reveal.
            precondition(abs(panel!.frame.maxX - geometry.notch.minX) < 1)
            if direction == "left" {
                precondition(abs(panel!.frame.maxX - geometry.notch.minX) < 1)
                precondition(!panel!.ignoresMouseEvents, "The revealed bubble must receive clicks")
                let realWidth = panel!.frame.width
                precondition(icon.previewNotchBubble("left"))
                let deadline = Date(timeIntervalSinceNow: 7)
                repeat {
                    RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
                } while Date() < deadline &&
                    (!panel!.isVisible || panel!.ignoresMouseEvents || panel!.frame.width > realWidth + 1)
                precondition(panel!.isVisible && !panel!.ignoresMouseEvents && panel!.frame.width <= realWidth + 1,
                             "Finishing a preview must restore the still-unread real bubble")
                var opened = false
                icon.onTrayIconMouseDown = { opened = true }
                let event = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero,
                    modifierFlags: [], timestamp: 0, windowNumber: panel!.windowNumber,
                    context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
                panel!.contentView?.mouseDown(with: event)
                precondition(opened, "Clicking the bubble must open the same tray action")
                precondition(icon.consumeNotchClickFrame() != nil, "The popup must anchor to the bubble")
                precondition(icon.consumeNotchClickFrame() == nil, "The temporary anchor is consumed once")
            }
            icon.setTitle("", "plain", nil)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
            precondition(panel?.isVisible == false, "Reading the reminder must retract the bubble")
        }
        icon.setNotchBubbleDirection("off")
        print("PASS: a hidden icon responds to notch hover and reveals new reminders")
    }
}
