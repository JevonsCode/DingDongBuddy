//
//  TrayIcon.swift
//  tray_manager
//
//  Created by Lijy91 on 2022/5/15.
//

import AppKit
import CoreText
import QuartzCore

public class TrayIcon: NSView {
    public var onTrayIconMouseDown:(() -> Void)?
    public var onTrayIconMouseUp:(() -> Void)?
    public var onTrayIconRightMouseDown:(() -> Void)?
    public var onTrayIconRightMouseUp:(() -> Void)?
    public var onAppearanceChanged:((Bool) -> Void)?
    
    var statusItem: NSStatusItem?
    private var unreadBadgeTitle: NSAttributedString?
    private var sourceImage: NSImage?
    private var stillBadgeImage: NSImage?
    private var badgeWidth: CGFloat = 55
    private var badgeRgb: UInt32?
    private var reminderBubbles: [[String: Any]] = []
    private var bubbleDimmed = false
    
    public init() {
        super.init(frame: NSRect.zero)
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "DingDong"
        statusItem?.autosaveName = "\(bundleIdentifier).primary-status-item"
        statusItem?.button?.addSubview(self)
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame:frameRect);
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var surfaceIsLight: Bool {
        effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) != .darkAqua
    }

    public override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChanged?(surfaceIsLight)
    }
    
    public func setImage(_ image: NSImage, _ imagePosition: String) {
        if let button = statusItem?.button {
            sourceImage = image
            button.image = unreadBadgeTitle == nil ? image : nil
            setImagePosition(imagePosition)
        }


        self.frame = statusItem!.button!.frame
        needsDisplay = true
    }
    
    public func setImagePosition(_ imagePosition: String) {
        if let button = statusItem?.button {
            button.imagePosition = imagePosition == "right" ? NSControl.ImagePosition.imageRight : NSControl.ImagePosition.imageLeft
        }
        self.frame = statusItem!.button!.frame
    }
    
    public func removeImage() {
        statusItem?.button?.image = nil
        self.frame = statusItem!.button!.frame
    }

    public func shake() {
        guard let button = statusItem?.button else { return }

        button.wantsLayer = true
        let animation = CAKeyframeAnimation(keyPath: "transform.rotation.z")
        animation.values = [0.0, -0.13, 0.12, -0.08, 0.05, 0.0]
        animation.keyTimes = [0.0, 0.18, 0.42, 0.64, 0.82, 1.0]
        animation.duration = 0.42
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        button.layer?.add(animation, forKey: "dingdong-copy-shake")
    }

    public func nudge() {
        guard let button = statusItem?.button else { return }

        button.wantsLayer = true
        let animation = CAKeyframeAnimation(keyPath: "transform.translation.x")
        animation.values = [0.0, -4.0, 4.0, -3.0, 3.0, -1.5, 0.0]
        animation.keyTimes = [0.0, 0.16, 0.32, 0.50, 0.68, 0.84, 1.0]
        animation.duration = 0.56
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        button.layer?.add(animation, forKey: "dingdong-reminder-nudge")
    }

    public func setTitle(
        _ title: String,
        _ style: String,
        _ badgeColorRgb: UInt32?,
        _ bubbles: [[String: Any]] = [],
        _ badgeDimmed: Bool = false
    ) {
        guard let button = statusItem?.button else { return }
        let countText = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let isUnreadBadge = style == "unreadBadge" && !countText.isEmpty
        button.wantsLayer = true
        button.layer?.backgroundColor = nil
        button.layer?.masksToBounds = false
        if isUnreadBadge {
            // Preserve DingDong's artwork and count. Reminder types are separate
            // trailing bubbles, never replacements for the app's identity.
            if unreadBadgeTitle == nil { stillBadgeImage = sourceImage }
            unreadBadgeTitle = NSAttributedString(string: countText, attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            ])
            badgeWidth = countText.count > 2 ? 65 : 55
            badgeRgb = badgeColorRgb
            reminderBubbles = Array(bubbles.prefix(64))
            bubbleDimmed = badgeDimmed
            button.image = nil
            button.attributedTitle = NSAttributedString(string: "")
            let shown = min(reminderBubbles.count, 3)
            let overflowWidth: CGFloat = reminderBubbles.count > 3 ? 25 : 0
            statusItem?.length = badgeWidth + (shown > 0 ? 5 + CGFloat(shown) * 17 : 0) + overflowWidth
        } else {
            unreadBadgeTitle = nil
            stillBadgeImage = nil
            reminderBubbles = []
            button.image = sourceImage
            button.title = title
            button.attributedTitle = NSAttributedString(string: title)
            button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
            statusItem?.length = title.isEmpty ? NSStatusItem.squareLength : NSStatusItem.variableLength
        }
        self.frame = button.bounds
        needsDisplay = true
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let title = unreadBadgeTitle else { return }
        let pill = NSRect(x: 0, y: 0, width: badgeWidth, height: bounds.height)
        NSColor(cgColor: badgeBackgroundColor(badgeRgb))?.setFill()
        NSBezierPath(roundedRect: pill, xRadius: 12, yRadius: 12).fill()
        let artwork = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? stillBadgeImage : sourceImage
        artwork?.draw(in: NSRect(x: 5, y: bounds.midY - 11, width: 22, height: 22))
        drawCentered(title, x: 30)
        for (index, bubble) in reminderBubbles.prefix(3).enumerated() {
            let rgb = (bubble["colorRgb"] as? NSNumber)?.uint32Value
            let pulse = bubble["pulse"] as? Bool ?? false
            let color = badgeDisplayRgb(rgb, dimmed: bubbleDimmed && pulse)
            NSColor(cgColor: badgeBackgroundColor(color))?.setFill()
            NSBezierPath(ovalIn: NSRect(
                x: badgeWidth + 7 + CGFloat(index) * 17,
                y: bounds.midY - 6, width: 12, height: 12
            )).fill()
        }
        if reminderBubbles.count > 3 {
            drawCentered(NSAttributedString(string: "+\(reminderBubbles.count - 3)", attributes: [
                .foregroundColor: NSColor.labelColor,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
            ]), x: badgeWidth + 58)
        }
    }

    private func drawCentered(_ text: NSAttributedString, x: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let line = CTLineCreateWithAttributedString(text)
        let glyphBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: x, y: bounds.midY - glyphBounds.midY)
        CTLineDraw(line, context)
        context.restoreGState()
    }

    private func badgeBackgroundColor(_ rgb: UInt32?) -> CGColor {
        let value = rgb ?? 0xDB7333
        let red = CGFloat((value >> 16) & 0xFF) / 255
        let green = CGFloat((value >> 8) & 0xFF) / 255
        let blue = CGFloat(value & 0xFF) / 255
        return NSColor(
            calibratedRed: red,
            green: green,
            blue: blue,
            alpha: 1.0
        ).cgColor
    }
    
    private func badgeDisplayRgb(_ rgb: UInt32?, dimmed: Bool) -> UInt32 {
        let value = rgb ?? 0xDB7333
        guard dimmed && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return value }
        let red = UInt32(Double((value >> 16) & 0xFF) * 0.88)
        let green = UInt32(Double((value >> 8) & 0xFF) * 0.88)
        let blue = UInt32(Double(value & 0xFF) * 0.88)
        return (red << 16) | (green << 8) | blue
    }

    public func setToolTip(_ toolTip: String) {
        if let button = statusItem?.button {
            button.toolTip = toolTip
            button.setAccessibilityLabel(toolTip)
        }
    }
    
    public override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.command),
           let button = statusItem?.button
        {
            // Let NSStatusBarButton run its native tracking loop so macOS can
            // rearrange this status item and persist the new autosave slot.
            button.mouseDown(with: event)
            return
        }
        statusItem?.button?.highlight(true)
        self.onTrayIconMouseDown!()
    }
    
    public override func mouseUp(with event: NSEvent) {
        statusItem?.button?.highlight(false)
        self.onTrayIconMouseUp!()
    }
    
    public override func rightMouseDown(with event: NSEvent) {
        self.onTrayIconRightMouseDown!()
    }
    
    public override func rightMouseUp(with event: NSEvent) {
        self.onTrayIconRightMouseUp!()
    }
}
