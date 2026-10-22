//
//  TrayIcon.swift
//  tray_manager
//
//  Created by Lijy91 on 2022/5/15.
//

import AppKit
import CoreText
import QuartzCore

public class TrayIcon: NSView, NSPopoverDelegate {
    public var onTrayIconMouseDown:(() -> Void)?
    public var onTrayIconMouseUp:(() -> Void)?
    public var onTrayIconRightMouseDown:(() -> Void)?
    public var onTrayIconRightMouseUp:(() -> Void)?
    public var onAppearanceChanged:((Bool) -> Void)?
    
    var statusItem: NSStatusItem?
    private struct BadgeFrame {
        var id: String
        var rect: NSRect
        var text: NSAttributedString
        var textX: CGFloat
        var color: NSColor
        var alpha: CGFloat = 1
    }
    private var badgeId = "primary"
    private var transitionFrom: [BadgeFrame] = []
    private var transitionProgress: CGFloat = 1
    private var transitionWidth: CGFloat = 0
    private var transitionTimer: Timer?

    private func targetScene() -> [BadgeFrame] {
        guard let title = unreadBadgeTitle else { return [] }
        var result = [BadgeFrame(id: badgeId,
            rect: NSRect(x: 0, y: 0, width: badgeWidth, height: bounds.height),
            text: title, textX: 31 + title.size().width / 2,
            color: NSColor(cgColor: badgeBackgroundColor(badgeDisplayRgb(badgeRgb, dimmed: bubbleDimmed && badgePulse)))!)]
        var x = badgeWidth + bubbleSpacing
        for (index, bubble) in displayedBubbles.enumerated() {
            let width = bubbleWidth(bubble)
            let rgb = (bubble["colorRgb"] as? NSNumber)?.uint32Value
            let pulse = bubble["pulse"] as? Bool ?? false
            let color = badgeDisplayRgb(rgb, dimmed: bubbleDimmed && pulse)
            result.append(BadgeFrame(id: bubble["id"] as? String ?? "tail-\(index)",
                rect: NSRect(x: x, y: 1, width: width, height: bounds.height - 2),
                text: bubbleText(bubble), textX: x + width / 2,
                color: NSColor(cgColor: badgeBackgroundColor(color))!))
            x += width + bubbleSpacing
        }
        return result
    }

    private func renderedScene() -> [BadgeFrame] {
        let target = targetScene()
        guard transitionProgress < 1 else { return target }
        let progress = transitionProgress
        func mix(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * progress }
        var result = target.map { item -> BadgeFrame in
            let previous = transitionFrom.first { $0.id == item.id }
            var from = previous ?? item
            if previous == nil { from.alpha = 0; from.rect.origin.x += 8; from.textX += 8 }
            var frame = item
            frame.rect = NSRect(x: mix(from.rect.minX, item.rect.minX),
                y: mix(from.rect.minY, item.rect.minY),
                width: mix(from.rect.width, item.rect.width), height: mix(from.rect.height, item.rect.height))
            frame.textX = mix(from.textX, item.textX)
            frame.color = from.color.blended(withFraction: progress, of: item.color) ?? item.color
            frame.alpha = mix(from.alpha, 1)
            return frame
        }
        for var removed in transitionFrom where !target.contains(where: { $0.id == removed.id }) {
            removed.alpha *= 1 - progress
            result.append(removed)
        }
        return result
    }

    private func animateScene(from scene: [BadgeFrame], width: CGFloat) {
        transitionTimer?.invalidate()
        guard !scene.isEmpty, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            transitionProgress = 1
            layoutBadge()
            return
        }
        transitionFrom = scene
        transitionWidth = width
        transitionProgress = 0
        let startedAt = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let progress = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                ? 1 : min(1, (CACurrentMediaTime() - startedAt) / 0.22)
            self.transitionProgress = CGFloat(1 - pow(1 - progress, 3))
            self.layoutBadge()
            if progress >= 1 {
                timer.invalidate()
                self.transitionTimer = nil
                self.transitionFrom = []
            }
        }
        transitionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
        layoutBadge()
    }

    private var overflowPopover: NSPopover?
    private var overflowOpenWork: DispatchWorkItem?
    private var overflowCloseWork: DispatchWorkItem?
    private var overflowMonitor: Timer?

    var overflowItems: [[String: Any]] {
        reminderBubbles.count > 3 ? Array(reminderBubbles.dropFirst(2)) : []
    }

    /// Shared by the real popover and the native rendering test.
    func makeOverflowContent() -> NSViewController? {
        let items = overflowItems
        guard !items.isEmpty else { return nil }
        let width: CGFloat = 220
        let height = min(CGFloat(items.count) * 32 + 16, 272)
        let controller = NSViewController()
        let root = TrayOverflowHoverView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        root.onHover = { [weak self] inside in
            if inside { self?.overflowCloseWork?.cancel(); self?.overflowCloseWork = nil; self?.collapseWork?.cancel() }
            else { self?.scheduleOverflowClose(); self?.scheduleCollapse() }
        }
        let scroll = NSScrollView(frame: root.bounds.insetBy(dx: 8, dy: 8))
        scroll.autoresizingMask = [.width, .height]
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        let document = TrayOverflowDocument(frame: NSRect(x: 0, y: 0,
            width: width - 16, height: CGFloat(items.count) * 32))
        for (index, item) in items.enumerated() {
            let row = NSView(frame: NSRect(x: 0, y: CGFloat(index) * 32, width: width - 16, height: 32))
            let text = bubbleText(item).string
            let badgeWidth: CGFloat = text.count > 2 ? 32 : 24
            let badge = NSView(frame: NSRect(x: 0, y: 4, width: badgeWidth, height: 24))
            badge.wantsLayer = true
            badge.layer?.cornerRadius = 12
            badge.layer?.backgroundColor = badgeBackgroundColor((item["colorRgb"] as? NSNumber)?.uint32Value)
            let count = NSTextField(labelWithString: text)
            count.font = .monospacedDigitSystemFont(ofSize: 12, weight: .semibold)
            count.textColor = .white
            count.alignment = .center
            count.frame = NSRect(x: 0, y: 4, width: badgeWidth, height: 16)
            badge.addSubview(count)
            row.addSubview(badge)
            let name = item["name"] as? String ?? item["id"] as? String ?? ""
            let label = NSTextField(labelWithString: name)
            label.font = .systemFont(ofSize: 13)
            label.textColor = .labelColor
            label.lineBreakMode = .byTruncatingTail
            label.maximumNumberOfLines = 1
            label.toolTip = name
            label.frame = NSRect(x: badgeWidth + 10, y: 7, width: width - badgeWidth - 30, height: 18)
            row.addSubview(label)
            row.setAccessibilityElement(true)
            row.setAccessibilityRole(.staticText)
            row.setAccessibilityLabel("\(name), \(text)")
            badge.setAccessibilityHidden(true)
            label.setAccessibilityHidden(true)
            document.addSubview(row)
        }
        scroll.documentView = document
        root.addSubview(scroll)
        controller.view = root
        controller.preferredContentSize = root.frame.size
        return controller
    }

    private var overflowRect: NSRect? {
        renderedScene().first(where: { $0.id == "@overflow" })?.rect
    }

    private var mouseInsideOverflow: Bool {
        guard let window, let rect = overflowRect else { return false }
        return rect.contains(convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil))
    }

    private var mouseInsideOverflowPopover: Bool {
        guard overflowPopover?.isShown == true, let window = overflowPopover?.contentViewController?.view.window else { return false }
        // Include the small gap/arrow between the anchor and the content.
        return window.frame.insetBy(dx: -6, dy: -8).contains(NSEvent.mouseLocation)
    }

    public override func mouseMoved(with event: NSEvent) {
        if mouseInsideOverflow {
            overflowCloseWork?.cancel()
            overflowCloseWork = nil
            guard overflowPopover?.isShown != true, overflowOpenWork == nil else { return }
            let work = DispatchWorkItem { [weak self] in
                self?.overflowOpenWork = nil
                guard let self, self.mouseInsideOverflow else { return }
                self.showOverflow()
            }
            overflowOpenWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16, execute: work)
        } else {
            overflowOpenWork?.cancel()
            overflowOpenWork = nil
            scheduleOverflowClose()
        }
    }

    private func showOverflow() {
        guard let rect = overflowRect, let content = makeOverflowContent(), window != nil else { return }
        let popover = overflowPopover ?? NSPopover()
        popover.behavior = .transient
        popover.animates = !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        popover.delegate = self
        popover.contentViewController = content
        overflowPopover = popover
        // Native popover owns screen-edge placement, shadow and appearance.
        popover.show(relativeTo: rect, of: self, preferredEdge: .minY)
        overflowMonitor?.invalidate()
        // The arrow/chrome lies outside the root view's tracking rect. Keep
        // exit handling alive even when someone pauses there before leaving.
        let monitor = Timer(timeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self, self.overflowPopover?.isShown == true else { timer.invalidate(); return }
            if self.mouseInsideOverflow || self.mouseInsideOverflowPopover {
                self.overflowCloseWork?.cancel()
                self.overflowCloseWork = nil
            } else if self.overflowCloseWork == nil { self.scheduleOverflowClose() }
        }
        overflowMonitor = monitor
        RunLoop.main.add(monitor, forMode: .common)
    }

    private func scheduleOverflowClose() {
        overflowCloseWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.overflowCloseWork = nil
            guard let self, !self.mouseInsideOverflow, !self.mouseInsideOverflowPopover else { return }
            self.closeOverflow()
        }
        overflowCloseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28, execute: work)
    }

    private func closeOverflow() {
        overflowOpenWork?.cancel()
        overflowOpenWork = nil
        overflowCloseWork?.cancel()
        overflowCloseWork = nil
        overflowMonitor?.invalidate()
        overflowMonitor = nil
        overflowPopover?.close()
    }

    public func popoverDidClose(_ notification: Notification) {
        overflowMonitor?.invalidate()
        overflowMonitor = nil
        scheduleCollapse()
    }

    private var unreadBadgeTitle: NSAttributedString?
    private var sourceImage: NSImage?
    private var stillBadgeImage: NSImage?
    private var badgeWidth: CGFloat = 55
    private var badgeRgb: UInt32?
    private var badgePulse = false
    private var reminderBubbles: [[String: Any]] = []
    private var bubbleDimmed = false
    private var hoverExpanded = false
    private var expansion: CGFloat = 0
    private var expansionTimer: Timer?
    private var bubbleSpacing: CGFloat { -8 + 11 * expansion }

    deinit {
        expansionTimer?.invalidate()
        transitionTimer?.invalidate()
        overflowOpenWork?.cancel()
        overflowCloseWork?.cancel()
        overflowMonitor?.invalidate()
        collapseWork?.cancel()
        overflowPopover?.delegate = nil
        overflowPopover?.close()
    }

    // A single progress value drives drawing and status-item width together.
    // Retargeting starts at the rendered position, including rapid reversals.
    func setHoverExpanded(_ expanded: Bool, animated: Bool = true) {
        let target: CGFloat = expanded ? 1 : 0
        if expanded == hoverExpanded && animated &&
            (expansionTimer != nil || abs(target - expansion) < 0.001) { return }
        hoverExpanded = expanded
        expansionTimer?.invalidate()
        expansionTimer = nil
        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              !reminderBubbles.isEmpty, abs(target - expansion) > 0.001 else {
            expansion = target
            layoutBadge()
            return
        }
        let start = expansion
        let startedAt = CACurrentMediaTime()
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let elapsed = (CACurrentMediaTime() - startedAt) / 0.2
            let progress = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                ? 1 : min(1, elapsed)
            let eased = 1 - pow(1 - progress, 3)
            self.expansion = start + (target - start) * CGFloat(eased)
            self.layoutBadge()
            if progress >= 1 {
                timer.invalidate()
                self.expansionTimer = nil
            }
        }
        expansionTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    private var hoverTrackingArea: NSTrackingArea?
    private var collapseWork: DispatchWorkItem?

    public override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = hoverTrackingArea { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTrackingArea = area
    }

    public override func mouseEntered(with event: NSEvent) {
        collapseWork?.cancel()
        guard !reminderBubbles.isEmpty else { return }
        setHoverExpanded(true)
        mouseMoved(with: event)
    }

    public override func mouseExited(with event: NSEvent) {
        overflowOpenWork?.cancel()
        overflowOpenWork = nil
        scheduleOverflowClose()
        scheduleCollapse()
    }

    private func scheduleCollapse() {
        collapseWork?.cancel()
        // Resizing a status item changes its screen position. Check the new
        // bounds before collapsing, avoiding enter/exit loops under the pointer.
        let work = DispatchWorkItem { [weak self] in
            guard let self, let button = self.statusItem?.button,
                  let window = button.window else { return }
            let screenRect = window.convertToScreen(button.convert(button.bounds, to: nil))
            guard !screenRect.contains(NSEvent.mouseLocation), !self.mouseInsideOverflowPopover else { return }
            self.closeOverflow()
            self.setHoverExpanded(false)
        }
        collapseWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: work)
    }

    private func layoutBadge() {
        guard unreadBadgeTitle != nil, let button = statusItem?.button else { return }
        var width = badgeWidth
        for bubble in displayedBubbles {
            width += bubbleWidth(bubble) + bubbleSpacing
        }
        statusItem?.length = transitionWidth + (width - transitionWidth) * transitionProgress
        frame = button.bounds
        needsDisplay = true
    }
    
    public init() {
        super.init(frame: NSRect.zero)
        statusItem = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "DingDong"
        statusItem?.autosaveName = "\(bundleIdentifier).primary-status-item"
        statusItem?.button?.addSubview(self)
        statusItem?.button?.window?.acceptsMouseMovedEvents = true
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
        _ badgeDimmed: Bool = false,
        _ primaryId: String? = nil,
        _ primaryPulse: Bool = false
    ) {
        guard let button = statusItem?.button else { return }
        let countText = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let isUnreadBadge = style == "unreadBadge" && !countText.isEmpty
        button.wantsLayer = true
        button.layer?.backgroundColor = nil
        button.layer?.masksToBounds = false
        if isUnreadBadge {
            let oldScene = renderedScene()
            let oldWidth = bounds.width
            let nextId = primaryId ?? "primary"
            let changed = badgeId != nextId || unreadBadgeTitle?.string != countText || badgeRgb != badgeColorRgb ||
                !NSArray(array: reminderBubbles).isEqual(to: Array(bubbles.prefix(64)))
            badgeId = nextId
            badgePulse = primaryPulse
            // Preserve DingDong's artwork and count. Reminder types are separate
            // trailing bubbles, never replacements for the app's identity.
            if unreadBadgeTitle == nil { stillBadgeImage = sourceImage }
            unreadBadgeTitle = NSAttributedString(string: countText, attributes: [
                .foregroundColor: NSColor.white,
                .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
            ])
            badgeWidth = 5 + 22 + 4 + ceil(unreadBadgeTitle!.size().width) + 8
            badgeRgb = badgeColorRgb
            reminderBubbles = Array(bubbles.prefix(64))
            bubbleDimmed = badgeDimmed
            button.image = nil
            button.attributedTitle = NSAttributedString(string: "")
            if changed { animateScene(from: oldScene, width: oldWidth) }
            else { layoutBadge() }
            if overflowItems.isEmpty { closeOverflow() }
            else if changed && overflowPopover?.isShown == true {
                overflowPopover?.contentViewController = makeOverflowContent()
            }

        } else {
            closeOverflow()
            collapseWork?.cancel()
            hoverExpanded = false
            expansionTimer?.invalidate()
            expansionTimer = nil
            expansion = 0
            transitionTimer?.invalidate()
            transitionTimer = nil
            transitionProgress = 1
            transitionFrom = []
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
        guard unreadBadgeTitle != nil else { return }
        // Text remains centred on each complete badge, including while occluded.
        for badge in renderedScene().reversed() {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.cgContext.setAlpha(badge.alpha)
            badge.color.setFill()
            NSBezierPath(roundedRect: badge.rect, xRadius: badge.rect.height / 2,
                yRadius: badge.rect.height / 2).fill()
            if badge.id == "@overflow" {
                NSColor.white.setFill()
                for offset in [-4.0, 0.0, 4.0] {
                    NSBezierPath(ovalIn: NSRect(x: badge.rect.midX + offset - 1,
                        y: badge.rect.midY - 1, width: 2, height: 2)).fill()
                }
            } else {
                drawCentered(badge.text, centerX: badge.textX)
            }
            NSGraphicsContext.restoreGraphicsState()
        }
        let artwork = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? stillBadgeImage : sourceImage
        artwork?.draw(in: NSRect(x: 5, y: bounds.midY - 11, width: 22, height: 22))
    }

    private var displayedBubbles: [[String: Any]] {
        var result = Array(reminderBubbles.prefix(reminderBubbles.count > 3 ? 2 : 3))
        if reminderBubbles.count > 3 {
            result.append(["id": "@overflow", "label": "", "colorRgb": NSNumber(value: 0x666666)])
        }
        return result
    }

    private func bubbleText(_ bubble: [String: Any]) -> NSAttributedString {
        let count = (bubble["count"] as? NSNumber)?.intValue
        let label = bubble["label"] as? String ?? count.map { $0 > 99 ? "99+" : String($0) } ?? "?"
        return NSAttributedString(string: label, attributes: [
            .foregroundColor: NSColor.white,
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .semibold)
        ])
    }

    private func bubbleWidth(_ bubble: [String: Any]) -> CGFloat {
        if bubble["id"] as? String == "@overflow" {
            return (statusItem?.button?.bounds.height ?? 22) - 2
        }
        return max(statusItem?.button?.bounds.height ?? 22, ceil(bubbleText(bubble).size().width) + 10)
    }

    private func drawCentered(_ text: NSAttributedString, centerX: CGFloat) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        let line = CTLineCreateWithAttributedString(text)
        let glyphBounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        context.saveGState()
        context.textMatrix = .identity
        context.textPosition = CGPoint(x: centerX - glyphBounds.midX, y: bounds.midY - glyphBounds.midY)
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
        closeOverflow()
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
        closeOverflow()
        self.onTrayIconRightMouseDown!()
    }
    
    public override func rightMouseUp(with event: NSEvent) {
        self.onTrayIconRightMouseUp!()
    }
}

private final class TrayOverflowDocument: NSView {
    override var isFlipped: Bool { true }
}

private final class TrayOverflowHoverView: NSView {
    var onHover: ((Bool) -> Void)?
    private var hoverArea: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = hoverArea { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self)
        addTrackingArea(area)
        hoverArea = area
    }
    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
}
