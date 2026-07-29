//
//  TrayIcon.swift
//  tray_manager
//
//  Created by Lijy91 on 2022/5/15.
//

import AppKit

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
