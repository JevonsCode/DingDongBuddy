import AppKit
import QuartzCore

enum NotchBubbleDirection: String {
    case down
    case left
}

struct NotchBubbleLayer {
    let image: NSImage
    let frame: NSRect
}

struct NotchBubbleContent {
    let size: NSSize
    let layers: [NotchBubbleLayer]
}

enum NotchBubbleMotion {
    static func layerProgress(index: Int, count: Int, progress: CGFloat) -> CGFloat {
        guard count > 0 else { return 0 }
        let delay = min(0.42, CGFloat(index) * 0.13)
        return min(1, max(0, (progress - delay) / (1 - delay)))
    }

    static func position(layer: NSRect, content: NSSize, index: Int,
                         count: Int, progress: CGFloat) -> NSRect {
        let p = layerProgress(index: index, count: count, progress: progress)
        let remaining = 1 - p
        let distance = max(0, content.width - layer.minX)
        var frame = layer
        frame.origin.x += remaining * remaining * remaining * distance
        return frame
    }
}

/// All rectangles are in AppKit's global screen coordinates.
struct NotchBubbleGeometry {
    let notch: NSRect

    static func forScreen(_ screen: NSScreen) -> NotchBubbleGeometry? {
        guard #available(macOS 12.0, *), screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea,
              let right = screen.auxiliaryTopRightArea,
              right.minX > left.maxX else { return nil }
        return NotchBubbleGeometry(notch: NSRect(
            x: left.maxX, y: screen.frame.maxY - screen.safeAreaInsets.top,
            width: right.minX - left.maxX, height: screen.safeAreaInsets.top))
    }

    func frame(size: NSSize, direction: NotchBubbleDirection, progress: CGFloat) -> NSRect {
        let p = min(1, max(0, progress))
        switch direction {
        case .down:
            let height = max(0.5, size.height * p)
            return NSRect(x: notch.midX - size.width / 2, y: notch.minY - height,
                          width: size.width, height: height)
        case .left:
            let width = max(0.5, size.width * p)
            return NSRect(x: notch.minX - width, y: notch.midY - size.height / 2,
                          width: width, height: size.height)
        }
    }

    /// macOS can park crowded items to the left of the display entirely.
    /// The caller excludes items actually visible on another display.
    func obscures(item: NSRect, screen: NSRect) -> Bool {
        guard item.width > 0, item.height > 0,
              item.minX < notch.maxX,
              item.maxY > notch.minY, item.minY < notch.maxY else { return false }
        return item.minX < screen.minX || item.maxX > notch.minX
    }
}

private final class NotchPreviewPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class NotchPreviewView: NSView {
    var content: NotchBubbleContent
    var progress: CGFloat = 0 { didSet { needsDisplay = true } }
    var direction: NotchBubbleDirection
    var onHover: ((Bool) -> Void)?
    var onClick: (() -> Void)?
    var onRightClick: (() -> Void)?
    var onRightMouseUp: (() -> Void)?
    private var hoverArea: NSTrackingArea?

    init(content: NotchBubbleContent, direction: NotchBubbleDirection) {
        self.content = content
        self.direction = direction
        super.init(frame: NSRect(origin: .zero, size: content.size))
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = hoverArea { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) { onHover?(true) }
    override func mouseExited(with event: NSEvent) { onHover?(false) }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func rightMouseDown(with event: NSEvent) { onRightClick?() }
    override func rightMouseUp(with event: NSEvent) { onRightMouseUp?() }
    override func accessibilityPerformPress() -> Bool {
        guard let onClick else { return false }
        onClick()
        return true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let origin = direction == .left
            ? NSPoint.zero : NSPoint(x: 0, y: bounds.height - content.size.height)
        for (index, layer) in content.layers.enumerated().reversed() {
            let layerProgress = direction == .left
                ? NotchBubbleMotion.layerProgress(index: index, count: content.layers.count, progress: progress)
                : 1
            guard layerProgress > 0 else { continue }
            var frame = direction == .left
                ? NotchBubbleMotion.position(layer: layer.frame, content: content.size,
                                             index: index, count: content.layers.count, progress: progress)
                : layer.frame
            frame.origin.x += origin.x
            frame.origin.y += origin.y
            layer.image.draw(in: frame, from: .zero, operation: .sourceOver,
                             fraction: 1, respectFlipped: true, hints: nil)
        }
    }
}

/// Native presentation shared by real hidden reminders and DEV previews.
final class NotchBubblePreview {
    private var panel: NotchPreviewPanel?
    private var animation: Timer?
    private var closeWork: DispatchWorkItem?
    private var geometry: NotchBubbleGeometry?
    private var direction: NotchBubbleDirection = .down
    private var size = NSSize.zero
    private var progress: CGFloat = 0
    private var isClosing = false
    private var menuTracking = false
    private var onClose: (() -> Void)?
    private(set) var isPreview = false

    var isVisible: Bool { panel?.isVisible == true }
    var frame: NSRect? { isVisible ? panel?.frame : nil }

    deinit {
        animation?.invalidate()
        closeWork?.cancel()
        panel?.orderOut(nil)
    }

    @discardableResult
    func show(image: NSImage, direction: NotchBubbleDirection,
              preview: Bool = true, onClick: (() -> Void)? = nil,
              onRightClick: (() -> Void)? = nil, onRightMouseUp: (() -> Void)? = nil,
              onHover: ((Bool) -> Void)? = nil, onClose: (() -> Void)? = nil,
              accessibilityLabel: String = "DingDong") -> Bool {
        let content = NotchBubbleContent(size: image.size,
            layers: [NotchBubbleLayer(image: image, frame: NSRect(origin: .zero, size: image.size))])
        return show(content: content, direction: direction, preview: preview,
                    onClick: onClick, onRightClick: onRightClick, onRightMouseUp: onRightMouseUp,
                    onHover: onHover, onClose: onClose,
                    accessibilityLabel: accessibilityLabel)
    }

    @discardableResult
    func show(content: NotchBubbleContent, direction: NotchBubbleDirection,
              preview: Bool = true, onClick: (() -> Void)? = nil,
              onRightClick: (() -> Void)? = nil, onRightMouseUp: (() -> Void)? = nil,
              onHover: ((Bool) -> Void)? = nil, onClose: (() -> Void)? = nil,
              accessibilityLabel: String = "DingDong") -> Bool {
        guard let screen = NSScreen.screens.first(where: { NotchBubbleGeometry.forScreen($0) != nil }),
              let geometry = NotchBubbleGeometry.forScreen(screen) else { return false }
        if !preview, !isPreview, isVisible, self.direction == direction {
            closeWork?.cancel()
            update(content: content)
            if isClosing { animate(to: 1) }
            return true
        }
        closeWork?.cancel()
        animation?.invalidate()
        panel?.orderOut(nil)
        self.geometry = geometry
        self.direction = direction
        self.isPreview = preview
        self.onClose = onClose
        size = content.size
        progress = 0
        let panel = self.panel ?? NotchPreviewPanel(contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.identifier = NSUserInterfaceItemIdentifier("dingdong.notch-preview")
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let view = NotchPreviewView(content: content, direction: direction)
        view.autoresizingMask = [.width, .height]
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.button)
        view.setAccessibilityLabel(accessibilityLabel)
        view.onHover = { [weak self] inside in
            if preview {
                if inside { self?.closeWork?.cancel() }
                else if self?.menuTracking == false { self?.scheduleClose(after: 0.32) }
            }
            onHover?(inside)
        }
        view.onClick = { [weak self] in
            if let onClick { onClick() } else { self?.close() }
        }
        view.onRightClick = onRightClick
        view.onRightMouseUp = onRightMouseUp
        panel.contentView = view
        self.panel = panel
        let initialFrameProgress: CGFloat = direction == .left ? 1 : 0
        panel.setFrame(geometry.frame(size: size, direction: direction, progress: initialFrameProgress), display: true)
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
        animate(to: 1)
        if preview { scheduleClose(after: 4) }
        return true
    }

    func update(content: NotchBubbleContent) {
        guard let panel, let view = panel.contentView as? NotchPreviewView,
              let geometry, panel.isVisible else { return }
        size = content.size
        view.content = content
        panel.setFrame(geometry.frame(size: size, direction: direction,
                                      progress: direction == .left ? 1 : progress), display: true)
        view.needsDisplay = true
    }

    func dismiss() { close() }

    func keepOpen() {
        closeWork?.cancel()
        if isClosing { animate(to: 1) }
    }

    func resumePreviewTimeout() {
        guard isPreview, isVisible, !menuTracking else { return }
        scheduleClose(after: 0.32)
    }

    @discardableResult
    func popUpContextMenu(_ menu: NSMenu) -> Bool {
        guard let panel, panel.isVisible, let view = panel.contentView, !isClosing else { return false }
        closeWork?.cancel()
        menuTracking = true
        defer {
            menuTracking = false
            if isPreview && !panel.frame.contains(NSEvent.mouseLocation) {
                scheduleClose(after: 0.32)
            }
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: view)
        return true
    }

    private func scheduleClose(after delay: TimeInterval) {
        closeWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.close() }
        closeWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func close() {
        closeWork?.cancel()
        closeWork = nil
        animate(to: 0)
    }

    private func finishClose() {
        panel?.orderOut(nil)
        let callback = onClose
        onClose = nil
        callback?()
    }

    private func animate(to target: CGFloat) {
        guard let panel, let geometry else { return }
        animation?.invalidate()
        animation = nil
        isClosing = target == 0
        let start = progress
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              abs(start - target) > 0.001 else {
            progress = target
            (panel.contentView as? NotchPreviewView)?.progress = target
            panel.setFrame(geometry.frame(size: size, direction: direction,
                                          progress: direction == .left ? 1 : target), display: true)
            panel.ignoresMouseEvents = target == 0
            if target == 0 { finishClose() }
            return
        }
        let began = CACurrentMediaTime()
        let duration: TimeInterval = direction == .left
            ? max(0.06, (target == 1 ? 0.42 : 0.24) * Double(abs(target - start)))
            : (target == 1 ? 0.42 : 0.22)
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            guard let self, let panel = self.panel, let geometry = self.geometry else {
                timer.invalidate(); return
            }
            let t = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
                ? 1 : min(1, (CACurrentMediaTime() - began) / duration)
            let eased = self.direction == .left ? t : 1 - pow(1 - t, 3)
            self.progress = start + (target - start) * CGFloat(eased)
            (panel.contentView as? NotchPreviewView)?.progress = self.progress
            panel.ignoresMouseEvents = self.progress < 0.98
            var frame = geometry.frame(size: self.size, direction: self.direction,
                                       progress: self.direction == .left ? 1 : self.progress)
            // A small damped overshoot keeps the reveal lively without stretching the artwork.
            if target == 1 && self.direction == .down {
                let bounce = CGFloat(sin(t * .pi) * (1 - t) * 3)
                if self.direction == .down { frame.origin.y -= bounce }
                else { frame.origin.x -= bounce }
            }
            panel.setFrame(frame, display: true)
            if t >= 1 {
                timer.invalidate()
                self.animation = nil
                if target == 0 { self.finishClose() }
            }
        }
        animation = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}
