//
//  TrayIcon.swift
//  tray_manager
//
//  Created by Lijy91 on 2022/5/15.
//

import AppKit
import QuartzCore

public class TrayIcon: NSView {
    public var onTrayIconMouseDown:(() -> Void)?
    public var onTrayIconMouseUp:(() -> Void)?
    public var onTrayIconRightMouseDown:(() -> Void)?
    public var onTrayIconRightMouseUp:(() -> Void)?
    
    var statusItem: NSStatusItem?
    
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
    
    public func setImage(_ image: NSImage, _ imagePosition: String) {
        if let button = statusItem?.button {
            button.image = image
            setImagePosition(imagePosition)
        }


        self.frame = statusItem!.button!.frame
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
        _ badgeColorRgb: UInt32?
    ) {
        guard let button = statusItem?.button else { return }

        let countText = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let isUnreadBadge = style == "unreadBadge" && !countText.isEmpty

        if isUnreadBadge {
            button.title = ""
            button.attributedTitle = NSAttributedString(
                string: " \(countText)\u{2009}",
                attributes: [
                    .foregroundColor: NSColor.white,
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
                ]
            )
            button.imagePosition = .imageLeading
            button.wantsLayer = true
            button.layer?.backgroundColor = badgeBackgroundColor(badgeColorRgb)
            button.layer?.cornerRadius = 12
            button.layer?.masksToBounds = true
            statusItem?.length = countText.count > 2 ? 65 : 55
        } else {
            button.title = title
            button.attributedTitle = NSAttributedString(string: title)
            button.imagePosition = title.isEmpty ? .imageOnly : .imageLeading
            button.layer?.backgroundColor = nil
            button.layer?.cornerRadius = 0
            button.layer?.masksToBounds = false
            button.wantsLayer = false
            statusItem?.length = title.isEmpty
                ? NSStatusItem.squareLength
                : NSStatusItem.variableLength
        }
        self.frame = statusItem!.button!.frame
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
            alpha: 0.95
        ).cgColor
    }
    
    public func setToolTip(_ toolTip: String) {
        if let button = statusItem?.button {
            button.toolTip  = toolTip
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
