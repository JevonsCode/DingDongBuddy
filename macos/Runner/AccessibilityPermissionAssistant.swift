import Cocoa
import ApplicationServices

private func ddAccessibilityString(_ key: String) -> String {
  NSLocalizedString(
    key,
    tableName: "AccessibilityPermissionAssistant",
    bundle: .main,
    value: key,
    comment: ""
  )
}

/// Opens the macOS Accessibility privacy pane and presents the current app as
/// a Finder-style drag source beside System Settings.
final class AccessibilityPermissionAssistant: NSObject {
  var onPermissionGranted: (() -> Void)?

  private let settingsBundleIdentifier = "com.apple.systempreferences"
  private var panel: AccessibilityPermissionPanel?
  private var trackingTimer: Timer?
  private var hasLocatedSettingsWindow = false
  private var missingSettingsPollCount = 0
  private var permissionWasGranted = false

  func show() {
    close()
    permissionWasGranted = AXIsProcessTrusted()

    let panel = AccessibilityPermissionPanel(
      appURL: Bundle.main.bundleURL
    )
    panel.onClose = { [weak self] in
      self?.close()
    }
    self.panel = panel
    panel.center()
    panel.orderFrontRegardless()

    openAccessibilitySettings()
    startTrackingSettingsWindow()
  }

  func close() {
    trackingTimer?.invalidate()
    trackingTimer = nil
    panel?.close()
    panel = nil
    hasLocatedSettingsWindow = false
    missingSettingsPollCount = 0
  }

  private func openAccessibilitySettings() {
    let settingsApplicationURL = URL(
      fileURLWithPath: "/System/Applications/System Settings.app"
    )
    NSWorkspace.shared.openApplication(
      at: settingsApplicationURL,
      configuration: NSWorkspace.OpenConfiguration()
    ) { _, _ in }

    if let privacyURL = URL(
      string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility"
    ) {
      NSWorkspace.shared.open(privacyURL)
    }

    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
      self?.activateSystemSettings()
    }
  }

  private func activateSystemSettings() {
    NSRunningApplication.runningApplications(
      withBundleIdentifier: settingsBundleIdentifier
    ).first?.activate(options: [.activateIgnoringOtherApps])
    panel?.orderFrontRegardless()
  }

  private func startTrackingSettingsWindow() {
    let timer = Timer(timeInterval: 0.18, repeats: true) {
      [weak self] _ in
      self?.updatePanelPosition()
    }
    trackingTimer = timer
    RunLoop.main.add(timer, forMode: .common)
    updatePanelPosition()
  }

  private func updatePanelPosition() {
    let permissionIsGranted = AXIsProcessTrusted()
    if !permissionWasGranted && permissionIsGranted {
      permissionWasGranted = true
      onPermissionGranted?()
      close()
      return
    }
    permissionWasGranted = permissionIsGranted

    guard
      let settingsApplication = NSRunningApplication.runningApplications(
        withBundleIdentifier: settingsBundleIdentifier
      ).first
    else {
      finishTrackingIfSettingsClosed()
      return
    }

    missingSettingsPollCount = 0
    guard
      let settingsFrame = settingsWindowFrame(
        processIdentifier: settingsApplication.processIdentifier
      )
    else { return }

    hasLocatedSettingsWindow = true
    panel?.snap(adjacentTo: settingsFrame)
    panel?.orderFrontRegardless()
  }

  private func finishTrackingIfSettingsClosed() {
    guard hasLocatedSettingsWindow else { return }
    missingSettingsPollCount += 1
    if missingSettingsPollCount >= 5 {
      close()
    }
  }

  private func settingsWindowFrame(processIdentifier: pid_t) -> CGRect? {
    guard
      let windowInfo = CGWindowListCopyWindowInfo(
        [.optionOnScreenOnly, .excludeDesktopElements],
        kCGNullWindowID
      ) as? [[String: Any]]
    else { return nil }

    let windowFrame = windowInfo
      .filter { window in
        guard
          let owner = window[kCGWindowOwnerPID as String] as? pid_t,
          owner == processIdentifier
        else { return false }
        let layer = window[kCGWindowLayer as String] as? Int ?? 0
        let alpha = window[kCGWindowAlpha as String] as? Double ?? 1
        return layer == 0 && alpha > 0
      }
      .compactMap { window -> CGRect? in
        guard
          let bounds = window[kCGWindowBounds as String] as? NSDictionary,
          let frame = CGRect(dictionaryRepresentation: bounds),
          frame.width > 320,
          frame.height > 240
        else { return nil }
        return frame
      }
      .max { lhs, rhs in
        lhs.width * lhs.height < rhs.width * rhs.height
      }

    return windowFrame.map(appKitFrame(fromGlobalTopLeftFrame:))
  }

  /// CGWindow bounds use a global top-left origin, while AppKit panels use a
  /// bottom-left origin local to each display.
  private func appKitFrame(fromGlobalTopLeftFrame frame: CGRect) -> CGRect {
    let screens = NSScreen.screens.compactMap {
      screen -> (appKitFrame: CGRect, displayFrame: CGRect)? in
      guard
        let number = screen.deviceDescription[
          NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber
      else { return nil }
      let displayID = CGDirectDisplayID(number.uint32Value)
      return (screen.frame, CGDisplayBounds(displayID))
    }

    let matchedScreen = screens
      .filter { $0.displayFrame.intersects(frame) }
      .max { lhs, rhs in
        intersectionArea(lhs.displayFrame, frame) <
          intersectionArea(rhs.displayFrame, frame)
      }

    guard let matchedScreen else { return frame }
    let localX = frame.minX - matchedScreen.displayFrame.minX
    let localY = frame.minY - matchedScreen.displayFrame.minY
    return CGRect(
      x: matchedScreen.appKitFrame.minX + localX,
      y: matchedScreen.appKitFrame.maxY - localY - frame.height,
      width: frame.width,
      height: frame.height
    )
  }
}

private final class AccessibilityPermissionPanel: NSPanel {
  var onClose: (() -> Void)?

  private let panelSize = NSSize(width: 368, height: 212)

  init(appURL: URL) {
    super.init(
      contentRect: NSRect(origin: .zero, size: panelSize),
      styleMask: [.borderless, .nonactivatingPanel],
      backing: .buffered,
      defer: false
    )

    level = .floating
    isReleasedWhenClosed = false
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    hidesOnDeactivate = false
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    animationBehavior = .utilityWindow

    // Keep the visual-effect material inside a separately masked clear root.
    // Using NSVisualEffectView as the window's root leaks rectangular corners
    // on some macOS versions.
    let background = RoundedVisualEffectContainer(cornerRadius: 18)
    contentView = background

    let header = makeHeader()

    let dragSource = AppBundleDragSourceView(
      appURL: appURL
    )
    dragSource.onDragStateChange = { [weak self] isDragging in
      self?.ignoresMouseEvents = isDragging
    }

    let staleEntryGuide = makeGuideRow(
      symbolName: "minus.circle",
      text: ddAccessibilityString("stale_entry_guide")
    )
    let disabledRemoveGuide = makeGuideRow(
      symbolName: "arrow.clockwise.circle",
      text: ddAccessibilityString("disabled_remove_guide")
    )
    let guideStack = NSStackView(views: [
      staleEntryGuide,
      disabledRemoveGuide,
    ])
    guideStack.orientation = .vertical
    guideStack.alignment = .leading
    guideStack.spacing = 5

    let stack = NSStackView(views: [
      header,
      dragSource,
      guideStack,
    ])
    stack.orientation = .vertical
    stack.alignment = .leading
    stack.spacing = 12
    stack.translatesAutoresizingMaskIntoConstraints = false
    background.addSubview(stack)

    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: background.leadingAnchor, constant: 16),
      stack.trailingAnchor.constraint(equalTo: background.trailingAnchor, constant: -16),
      stack.topAnchor.constraint(equalTo: background.topAnchor, constant: 15),
      stack.bottomAnchor.constraint(lessThanOrEqualTo: background.bottomAnchor, constant: -14),
      header.widthAnchor.constraint(equalTo: stack.widthAnchor),
      dragSource.widthAnchor.constraint(equalTo: stack.widthAnchor),
      dragSource.heightAnchor.constraint(equalToConstant: 68),
      guideStack.widthAnchor.constraint(equalTo: stack.widthAnchor),
    ])
  }

  override var canBecomeKey: Bool { false }

  override var canBecomeMain: Bool { false }

  func snap(adjacentTo settingsFrame: CGRect) {
    let matchingScreen = NSScreen.screens.max { lhs, rhs in
      intersectionArea(lhs.frame, settingsFrame) <
        intersectionArea(rhs.frame, settingsFrame)
    } ?? NSScreen.main
    guard let visibleFrame = matchingScreen?.visibleFrame else { return }

    let gap: CGFloat = 10
    let inset: CGFloat = 10
    let width = panelSize.width
    let height = panelSize.height
    let centeredY = clamp(
      settingsFrame.midY - height / 2,
      minimum: visibleFrame.minY + inset,
      maximum: visibleFrame.maxY - height - inset
    )
    let alignedX = clamp(
      settingsFrame.maxX - width,
      minimum: visibleFrame.minX + inset,
      maximum: visibleFrame.maxX - width - inset
    )

    let candidates = [
      NSRect(
        x: settingsFrame.maxX + gap,
        y: centeredY,
        width: width,
        height: height
      ),
      NSRect(
        x: settingsFrame.minX - width - gap,
        y: centeredY,
        width: width,
        height: height
      ),
      NSRect(
        x: alignedX,
        y: settingsFrame.minY - height - gap,
        width: width,
        height: height
      ),
      NSRect(
        x: alignedX,
        y: settingsFrame.maxY + gap,
        width: width,
        height: height
      ),
    ]

    let insetVisibleFrame = visibleFrame.insetBy(dx: inset, dy: inset)
    let targetFrame = candidates.first {
      insetVisibleFrame.contains($0)
    } ?? NSRect(
      x: clamp(
        settingsFrame.maxX - width - 14,
        minimum: insetVisibleFrame.minX,
        maximum: insetVisibleFrame.maxX - width
      ),
      y: clamp(
        settingsFrame.minY + 14,
        minimum: insetVisibleFrame.minY,
        maximum: insetVisibleFrame.maxY - height
      ),
      width: width,
      height: height
    )
    setFrame(targetFrame, display: true)
  }

  private func makeHeader() -> NSView {
    let title = NSTextField(
      labelWithString: ddAccessibilityString("title")
    )
    title.font = .systemFont(ofSize: 14.5, weight: .semibold)

    let subtitle = NSTextField(
      wrappingLabelWithString: ddAccessibilityString("subtitle")
    )
    subtitle.font = .systemFont(ofSize: 11.5)
    subtitle.textColor = .secondaryLabelColor
    subtitle.maximumNumberOfLines = 2

    let labels = NSStackView(views: [title, subtitle])
    labels.orientation = .vertical
    labels.alignment = .leading
    labels.spacing = 2
    labels.translatesAutoresizingMaskIntoConstraints = false

    let closeButton = NSButton(
      image: NSImage(
        systemSymbolName: "xmark.circle.fill",
        accessibilityDescription: ddAccessibilityString("close")
      ) ?? NSImage(),
      target: self,
      action: #selector(closePressed)
    )
    closeButton.isBordered = false
    closeButton.contentTintColor = .secondaryLabelColor
    closeButton.imageScaling = .scaleProportionallyDown
    closeButton.translatesAutoresizingMaskIntoConstraints = false

    let row = NSView()
    row.addSubview(labels)
    row.addSubview(closeButton)
    NSLayoutConstraint.activate([
      labels.leadingAnchor.constraint(equalTo: row.leadingAnchor),
      labels.topAnchor.constraint(equalTo: row.topAnchor),
      labels.bottomAnchor.constraint(equalTo: row.bottomAnchor),
      labels.trailingAnchor.constraint(
        lessThanOrEqualTo: closeButton.leadingAnchor,
        constant: -12
      ),
      closeButton.trailingAnchor.constraint(equalTo: row.trailingAnchor),
      closeButton.centerYAnchor.constraint(equalTo: row.centerYAnchor),
      closeButton.widthAnchor.constraint(equalToConstant: 26),
      closeButton.heightAnchor.constraint(equalToConstant: 26),
    ])
    return row
  }

  private func makeGuideRow(symbolName: String, text: String) -> NSView {
    let symbol = NSImageView()
    symbol.image = NSImage(
      systemSymbolName: symbolName,
      accessibilityDescription: nil
    )
    symbol.contentTintColor = .tertiaryLabelColor
    symbol.translatesAutoresizingMaskIntoConstraints = false

    let label = NSTextField(wrappingLabelWithString: text)
    label.font = .systemFont(ofSize: 10.5)
    label.textColor = .secondaryLabelColor
    label.maximumNumberOfLines = 2

    let row = NSStackView(views: [symbol, label])
    row.orientation = .horizontal
    row.alignment = .firstBaseline
    row.spacing = 7
    label.setContentHuggingPriority(.defaultLow, for: .horizontal)
    NSLayoutConstraint.activate([
      symbol.widthAnchor.constraint(equalToConstant: 13),
      symbol.heightAnchor.constraint(equalToConstant: 13),
    ])
    return row
  }

  @objc private func closePressed() {
    onClose?()
  }
}

/// A clear root plus an explicit shape mask keeps the vibrancy material from
/// painting into the panel's transparent corners.
private final class RoundedVisualEffectContainer: NSView {
  private let cornerRadius: CGFloat
  private let effectView = NSVisualEffectView()
  private let effectMask = CAShapeLayer()
  private let borderLayer = CAShapeLayer()

  init(cornerRadius: CGFloat) {
    self.cornerRadius = cornerRadius
    super.init(frame: .zero)

    wantsLayer = true
    layer?.backgroundColor = NSColor.clear.cgColor

    effectView.material = .popover
    effectView.blendingMode = .behindWindow
    effectView.state = .active
    effectView.wantsLayer = true
    effectView.layer?.mask = effectMask
    effectView.translatesAutoresizingMaskIntoConstraints = false
    addSubview(effectView)

    borderLayer.fillColor = NSColor.clear.cgColor
    borderLayer.lineWidth = 1
    layer?.addSublayer(borderLayer)

    NSLayoutConstraint.activate([
      effectView.leadingAnchor.constraint(equalTo: leadingAnchor),
      effectView.trailingAnchor.constraint(equalTo: trailingAnchor),
      effectView.topAnchor.constraint(equalTo: topAnchor),
      effectView.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    updateBorderColor()
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layout() {
    super.layout()
    let maskPath = CGPath(
      roundedRect: bounds,
      cornerWidth: cornerRadius,
      cornerHeight: cornerRadius,
      transform: nil
    )
    effectMask.frame = bounds
    effectMask.path = maskPath

    let borderBounds = bounds.insetBy(dx: 0.5, dy: 0.5)
    borderLayer.frame = bounds
    borderLayer.path = CGPath(
      roundedRect: borderBounds,
      cornerWidth: cornerRadius - 0.5,
      cornerHeight: cornerRadius - 0.5,
      transform: nil
    )
  }

  override func viewDidChangeEffectiveAppearance() {
    super.viewDidChangeEffectiveAppearance()
    updateBorderColor()
  }

  private func updateBorderColor() {
    borderLayer.strokeColor = NSColor.separatorColor
      .withAlphaComponent(0.55).cgColor
  }
}

private final class AppBundleDragSourceView: NSView, NSDraggingSource {
  var onDragStateChange: ((Bool) -> Void)?

  private let appURL: URL
  private var mouseDownPoint: NSPoint?
  private var hasBegunDragging = false

  init(appURL: URL) {
    self.appURL = appURL
    super.init(frame: .zero)

    wantsLayer = true
    layer?.backgroundColor = NSColor.controlAccentColor
      .withAlphaComponent(0.09).cgColor
    layer?.cornerRadius = 13
    layer?.cornerCurve = .continuous
    layer?.borderWidth = 1
    layer?.borderColor = NSColor.controlAccentColor
      .withAlphaComponent(0.3).cgColor

    let icon = NSImageView(image: NSWorkspace.shared.icon(forFile: appURL.path))
    icon.imageScaling = .scaleProportionallyUpOrDown
    icon.translatesAutoresizingMaskIntoConstraints = false

    let name = NSTextField(labelWithString:
      FileManager.default.displayName(atPath: appURL.path))
    name.font = .systemFont(ofSize: 14, weight: .semibold)
    name.lineBreakMode = .byTruncatingTail

    let hint = NSTextField(
      labelWithString: ddAccessibilityString("drag_hint")
    )
    hint.font = .systemFont(ofSize: 10.5)
    hint.textColor = .secondaryLabelColor

    let labels = NSStackView(views: [name, hint])
    labels.orientation = .vertical
    labels.alignment = .leading
    labels.spacing = 3

    let hand = NSImageView()
    hand.image = NSImage(
      systemSymbolName: "hand.draw",
      accessibilityDescription: nil
    )
    hand.contentTintColor = .controlAccentColor
    hand.translatesAutoresizingMaskIntoConstraints = false

    let row = NSStackView(views: [icon, labels, hand])
    row.orientation = .horizontal
    row.alignment = .centerY
    row.spacing = 11
    row.translatesAutoresizingMaskIntoConstraints = false
    addSubview(row)

    labels.setContentHuggingPriority(.defaultLow, for: .horizontal)
    hand.setContentHuggingPriority(.required, for: .horizontal)
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
      row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
      row.topAnchor.constraint(equalTo: topAnchor, constant: 9),
      row.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -9),
      icon.widthAnchor.constraint(equalToConstant: 46),
      icon.heightAnchor.constraint(equalToConstant: 46),
      hand.widthAnchor.constraint(equalToConstant: 22),
      hand.heightAnchor.constraint(equalToConstant: 22),
    ])

    setAccessibilityElement(true)
    setAccessibilityRole(.button)
    setAccessibilityLabel(ddAccessibilityString("drag_accessibility_label"))
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func resetCursorRects() {
    addCursorRect(bounds, cursor: .openHand)
  }

  override func mouseDown(with event: NSEvent) {
    mouseDownPoint = convert(event.locationInWindow, from: nil)
    hasBegunDragging = false
  }

  override func mouseDragged(with event: NSEvent) {
    guard !hasBegunDragging, let mouseDownPoint else { return }
    let currentPoint = convert(event.locationInWindow, from: nil)
    guard hypot(
      currentPoint.x - mouseDownPoint.x,
      currentPoint.y - mouseDownPoint.y
    ) > 4 else { return }

    hasBegunDragging = true
    let writer = AppBundlePasteboardWriter(url: appURL)
    let draggingItem = NSDraggingItem(pasteboardWriter: writer)
    let icon = NSWorkspace.shared.icon(forFile: appURL.path)
    icon.size = NSSize(width: 56, height: 56)
    let dragPoint = convert(event.locationInWindow, from: nil)
    draggingItem.setDraggingFrame(
      NSRect(
        x: dragPoint.x - 28,
        y: dragPoint.y - 28,
        width: 56,
        height: 56
      ),
      contents: icon
    )

    let session = beginDraggingSession(
      with: [draggingItem],
      event: event,
      source: self
    )
    session.animatesToStartingPositionsOnCancelOrFail = true
    session.draggingFormation = .none
  }

  override func mouseUp(with event: NSEvent) {
    mouseDownPoint = nil
    hasBegunDragging = false
  }

  func draggingSession(
    _ session: NSDraggingSession,
    sourceOperationMaskFor context: NSDraggingContext
  ) -> NSDragOperation {
    .copy
  }

  func ignoreModifierKeys(for session: NSDraggingSession) -> Bool {
    true
  }

  func draggingSession(
    _ session: NSDraggingSession,
    willBeginAt screenPoint: NSPoint
  ) {
    onDragStateChange?(true)
  }

  func draggingSession(
    _ session: NSDraggingSession,
    endedAt screenPoint: NSPoint,
    operation: NSDragOperation
  ) {
    onDragStateChange?(false)
    mouseDownPoint = nil
    hasBegunDragging = false
  }
}

private final class AppBundlePasteboardWriter: NSObject, NSPasteboardWriting {
  private let url: URL

  init(url: URL) {
    self.url = url
  }

  func writableTypes(
    for pasteboard: NSPasteboard
  ) -> [NSPasteboard.PasteboardType] {
    [
      .fileURL,
      .URL,
      NSPasteboard.PasteboardType("NSFilenamesPboardType"),
      NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url"),
      .string,
    ]
  }

  func pasteboardPropertyList(
    forType type: NSPasteboard.PasteboardType
  ) -> Any? {
    switch type {
    case .fileURL,
         .URL,
         NSPasteboard.PasteboardType("com.apple.pasteboard.promised-file-url"):
      return url.absoluteString
    case NSPasteboard.PasteboardType("NSFilenamesPboardType"):
      return [url.path]
    case .string:
      return url.path
    default:
      return nil
    }
  }
}

private func intersectionArea(_ lhs: CGRect, _ rhs: CGRect) -> CGFloat {
  let intersection = lhs.intersection(rhs)
  guard !intersection.isNull else { return 0 }
  return intersection.width * intersection.height
}

private func clamp(
  _ value: CGFloat,
  minimum: CGFloat,
  maximum: CGFloat
) -> CGFloat {
  guard minimum <= maximum else { return minimum }
  return min(max(value, minimum), maximum)
}
