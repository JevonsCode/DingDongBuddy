import AppKit

private final class NotchMenuObserver: NSObject, NSMenuDelegate {
    var openCount = 0
    func menuWillOpen(_ menu: NSMenu) { openCount += 1 }
}

@main
enum NotchBubblePreviewTest {
    static func main() {
        let geometry = NotchBubbleGeometry(notch: NSRect(x: 200, y: 970, width: 160, height: 32))
        let size = NSSize(width: 100, height: 24)
        precondition(geometry.frame(size: size, direction: .down, progress: 1) ==
                     NSRect(x: 230, y: 946, width: 100, height: 24))
        precondition(geometry.frame(size: size, direction: .down, progress: 0.5) ==
                     NSRect(x: 230, y: 958, width: 100, height: 12))
        precondition(geometry.frame(size: size, direction: .left, progress: 1) ==
                     NSRect(x: 100, y: 974, width: 100, height: 24))
        precondition(geometry.frame(size: size, direction: .left, progress: 0.5) ==
                     NSRect(x: 150, y: 974, width: 50, height: 24))
        precondition(geometry.frame(size: size, direction: .left, progress: 2).width == 100)
        let display = NSRect(x: 0, y: 0, width: 560, height: 1002)
        precondition(geometry.obscures(item: NSRect(x: 220, y: 970, width: 40, height: 32), screen: display))
        precondition(geometry.obscures(item: NSRect(x: 345, y: 970, width: 30, height: 32), screen: display))
        precondition(!geometry.obscures(item: NSRect(x: 150, y: 970, width: 30, height: 32), screen: display),
                     "A visible item to the left of the notch must not be treated as hidden")
        precondition(!geometry.obscures(item: NSRect(x: 370, y: 970, width: 30, height: 32), screen: display))
        precondition(geometry.obscures(item: NSRect(x: -80, y: 970, width: 20, height: 32), screen: display))
        precondition(!geometry.obscures(item: NSRect(x: 220, y: 900, width: 40, height: 20), screen: display))
        let earlyFirst = NotchBubbleMotion.layerProgress(index: 0, count: 3, progress: 0.18)
        let earlyLast = NotchBubbleMotion.layerProgress(index: 2, count: 3, progress: 0.18)
        precondition(earlyFirst > 0 && earlyLast == 0, "Bubbles must begin at different times")
        let middle = (0..<3).map { NotchBubbleMotion.layerProgress(index: $0, count: 3, progress: 0.5) }
        precondition(middle[0] > middle[1] && middle[1] > middle[2])
        precondition((0..<3).allSatisfy { NotchBubbleMotion.layerProgress(index: $0, count: 3, progress: 1) == 1 })
        let layers = [
            NSRect(x: 0, y: 0, width: 52, height: 24),
            NSRect(x: 44, y: 0, width: 24, height: 24),
            NSRect(x: 60, y: 0, width: 24, height: 24)
        ]
        let content = NSSize(width: 84, height: 24)
        for (index, layer) in layers.enumerated() {
            let start = NotchBubbleMotion.position(layer: layer, content: content,
                index: index, count: layers.count, progress: 0)
            precondition(start.minX == content.width,
                         "A bubble must start behind the notch rather than fade in on screen")
        }
        for step in 0...20 {
            for (index, layer) in layers.enumerated() {
                let position = NotchBubbleMotion.position(layer: layer, content: content,
                    index: index, count: layers.count, progress: CGFloat(step) / 20)
                precondition(position.minY == layer.minY && position.maxY == layer.maxY,
                             "Leftward bubbles must stay vertically aligned without clipping")
                precondition(position.minX >= layer.minX - 0.001,
                             "The reveal must not overshoot the left edge of the panel")
            }
        }
        func primaryX(_ progress: CGFloat) -> CGFloat {
            NotchBubbleMotion.position(layer: layers[0], content: content,
                index: 0, count: layers.count, progress: progress).minX
        }
        precondition(primaryX(0) - primaryX(0.20) > (primaryX(0) - primaryX(1)) * 0.45,
                     "The horizontal reveal must become visible promptly")

        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let icon = TrayIcon()
        let artwork = NSImage(contentsOfFile: CommandLine.arguments[1])!
        artwork.size = NSSize(width: 22, height: 22)
        icon.setImage(artwork, "left")
        precondition(!icon.previewNotchBubble("invalid"))
        if let screen = NSScreen.screens.first(where: { NotchBubbleGeometry.forScreen($0) != nil }),
           let actual = NotchBubbleGeometry.forScreen(screen) {
            icon.statusItem?.isVisible = false
            icon.setNotchBubbleDirection("left")
            let hoverPoint = NSPoint(x: actual.notch.midX, y: actual.notch.midY)
            icon.handleNotchHover(at: hoverPoint)
            let hoverTimer = Timer(timeInterval: 0.03, repeats: true) { _ in
                icon.handleNotchHover(at: hoverPoint)
            }
            RunLoop.main.add(hoverTimer, forMode: .common)
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.9))
            let hoverPanel = app.windows.first { $0.identifier?.rawValue == "dingdong.notch-preview" }
            precondition(hoverPanel?.isVisible == true && hoverPanel?.ignoresMouseEvents == false,
                         "Notch hover must reveal an interactive icon without an unread reminder")
            var rightClicked = false
            let menu = NSMenu()
            menu.addItem(withTitle: "Context menu test", action: nil, keyEquivalent: "")
            let menuObserver = NotchMenuObserver()
            menu.delegate = menuObserver
            icon.onTrayIconRightMouseDown = {
                rightClicked = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { menu.cancelTracking() }
                precondition(icon.popUpNotchContextMenu(menu), "The context menu must anchor to the notch bubble")
            }
            let rightEvent = NSEvent.mouseEvent(with: .rightMouseDown, location: .zero,
                modifierFlags: [], timestamp: 0, windowNumber: hoverPanel!.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
            precondition(hoverPanel!.contentView?.acceptsFirstMouse(for: rightEvent) == true,
                         "An inactive notch bubble must accept the first click")
            hoverPanel!.contentView?.rightMouseDown(with: rightEvent)
            precondition(rightClicked, "Right-click must reach the normal tray context-menu handler")
            precondition(menuObserver.openCount == 1, "Right-click must display the context menu")
            hoverTimer.invalidate()
            icon.setNotchBubbleDirection("off")
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.5))
            icon.statusItem?.isVisible = true
            for direction in [NotchBubbleDirection.down, .left] {
                precondition(icon.previewNotchBubble(direction.rawValue))
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.9))
                let panel = app.windows.first { $0.identifier?.rawValue == "dingdong.notch-preview" }!
                let expected = actual.frame(size: panel.frame.size, direction: direction, progress: 1)
                precondition(abs(panel.frame.minX - expected.minX) < 1)
                precondition(abs(panel.frame.minY - expected.minY) < 1)
                precondition(panel.isVisible)
                precondition(!panel.ignoresMouseEvents, "The preview bubble must be usable")
                precondition(icon.statusItem?.button?.title == "", "Preview must not create a reminder")
                if direction == .left {
                    let previewRightEvent = NSEvent.mouseEvent(with: .rightMouseDown, location: .zero,
                        modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
                        context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
                    panel.contentView?.rightMouseDown(with: previewRightEvent)
                    precondition(menuObserver.openCount == 2, "The preview bubble must open the same context menu")
                }
            }
            let opaquePreview = NotchBubblePreview()
            let opaqueSize = NSSize(width: 32, height: 24)
            let opaqueImage = NSImage(size: opaqueSize)
            opaqueImage.lockFocus()
            NSColor.red.setFill()
            NSRect(origin: .zero, size: opaqueSize).fill()
            opaqueImage.unlockFocus()
            precondition(opaquePreview.show(image: opaqueImage, direction: .left, preview: false))
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
            let opaquePanel = app.windows.first { $0.identifier?.rawValue == "dingdong.notch-preview" && $0.isVisible && $0.contentView?.frame.width == opaqueSize.width }!
            let opaqueView = opaquePanel.contentView!
            let bitmap = opaqueView.bitmapImageRepForCachingDisplay(in: opaqueView.bounds)!
            opaqueView.cacheDisplay(in: opaqueView.bounds, to: bitmap)
            precondition((bitmap.colorAt(x: bitmap.pixelsWide - 3, y: bitmap.pixelsHigh / 2)?.alphaComponent ?? 0) > 0.95,
                         "Visible bubble pixels must stay opaque during the reveal")
            opaquePreview.dismiss()
            let presenter = NotchBubblePreview()
            let image = NSImage(size: size)
            var clicked = false
            precondition(presenter.show(image: image, direction: .down, preview: false,
                                        onClick: { clicked = true }))
            let panel = app.windows.first { $0.identifier?.rawValue == "dingdong.notch-preview" && $0.isVisible && $0.contentView?.frame.width == size.width }!
            let event = NSEvent.mouseEvent(with: .leftMouseDown, location: .zero,
                modifierFlags: [], timestamp: 0, windowNumber: panel.windowNumber,
                context: nil, eventNumber: 0, clickCount: 1, pressure: 0)!
            panel.contentView?.mouseDown(with: event)
            precondition(clicked, "A real notch bubble forwards clicks to its owner")
            presenter.dismiss()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.06))
            precondition(presenter.show(image: image, direction: .down, preview: false))
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))
            precondition(panel.isVisible && !panel.ignoresMouseEvents,
                         "Reopening during retraction must finish revealing a clickable bubble")
            presenter.dismiss()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.06))
            presenter.keepOpen()
            RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.6))
            precondition(panel.isVisible && !panel.ignoresMouseEvents,
                         "Returning the pointer during retraction must keep the bubble open")
            presenter.dismiss()
            print("PASS: both previews appear at the real notch without changing reminder state")
        } else {
            precondition(!icon.previewNotchBubble("down"))
            print("PASS: a display without a notch does not show the preview")
        }
        print("PASS: downward and leftward reveal geometry")
    }
}
