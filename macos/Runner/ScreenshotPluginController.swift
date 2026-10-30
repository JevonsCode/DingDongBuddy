import Cocoa
import Carbon.HIToolbox
import FlutterMacOS

/// The primary engine maps a configurable shortcut to the system Screenshot tool.
final class ScreenshotPluginController {
  private static let signature: OSType = 0x44445343
  private let channel: FlutterMethodChannel
  private var hotKey: EventHotKeyRef?
  private var handler: EventHandlerRef?
  private var hotKeyID: UInt32 = 1
  private var shortcut: GlobalHotKeyConfiguration?
  private var labels: [String: String] = [:]
  private var pending: Timer?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "dingdong/screenshot_plugin", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { return result(FlutterMethodNotImplemented) }
      switch call.method {
      case "status": result(self.status)
      case "configure":
        guard let values = call.arguments as? [String: Any] else {
          return result(self.error("invalid_shortcut"))
        }
        if let failure = self.configure(values) { result(self.error(failure)) }
        else { result(self.status) }
      case "capture":
        if let failure = self.capture() { result(self.error(failure)) }
        else { result(nil) }
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private var capturing: Bool { pending != nil }
  private var status: [String: Bool] {
    ["supported": true, "running": hotKey != nil, "capturing": capturing]
  }
  private func error(_ code: String) -> FlutterError {
    FlutterError(code: code, message: code, details: nil)
  }

  private func configure(_ values: [String: Any]) -> String? {
    let enabled = values["enabled"] as? Bool == true
    if enabled {
      guard !capturing else { return "capture_busy" }
      guard let next = GlobalHotKeyConfiguration(arguments: values["shortcut"]) else {
        return "invalid_shortcut"
      }
      if hotKey == nil || next != shortcut {
        guard installHandler() else { return "unavailable" }
        let nextID: UInt32 = hotKeyID == 1 ? 2 : 1
        var replacement: EventHotKeyRef?
        let result = RegisterEventHotKey(next.keyCode, next.modifiers,
          EventHotKeyID(signature: Self.signature, id: nextID),
          GetApplicationEventTarget(), 0, &replacement)
        guard result == noErr, let replacement else { return "shortcut_conflict" }
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = replacement
        hotKeyID = nextID
        shortcut = next
      }
    } else {
      stopCapture()
      if let hotKey { UnregisterEventHotKey(hotKey) }
      hotKey = nil
      shortcut = nil
    }
    if let nextLabels = values["labels"] as? [String: String] { labels = nextLabels }
    return nil
  }

  private func installHandler() -> Bool {
    if handler != nil { return true }
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
      guard let event, let userData else { return OSStatus(eventNotHandledErr) }
      var id = EventHotKeyID()
      guard GetEventParameter(event, EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size,
        nil, &id) == noErr, id.signature == ScreenshotPluginController.signature else {
        return OSStatus(eventNotHandledErr)
      }
      let controller = Unmanaged<ScreenshotPluginController>.fromOpaque(userData).takeUnretainedValue()
      guard controller.hotKey != nil, id.id == controller.hotKeyID else { return noErr }
      if let failure = controller.capture(), failure != "capture_busy" { controller.showFailure() }
      return noErr
    }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), &handler)
    return result == noErr
  }

  private func capture() -> String? {
    guard hotKey != nil else { return "disabled" }
    guard !capturing else { return "capture_busy" }
    // Release the custom chord before handing keyboard control to Screenshot.
    let modifiers: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
    if NSEvent.modifierFlags.intersection(modifiers).isEmpty { return launch() }
    let deadline = Date().addingTimeInterval(5)
    pending = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
      guard let self else { return }
      if Date() >= deadline {
        self.pending?.invalidate(); self.pending = nil
      } else if NSEvent.modifierFlags.intersection(modifiers).isEmpty {
        self.pending?.invalidate(); self.pending = nil
        if self.launch() != nil { self.showFailure() }
      }
    }
    return nil
  }

  private func launch() -> String? {
    guard hotKey != nil else { return "disabled" }
    guard let application = NSWorkspace.shared.urlForApplication(
      withBundleIdentifier: "com.apple.screenshot.launcher"
    ), NSWorkspace.shared.open(application) else { return "capture_failed" }
    return nil
  }

  private func showFailure() {
    let alert = NSAlert()
    alert.messageText = labels["captureError"] ?? "Could not open system screenshot."
    alert.addButton(withTitle: labels["cancel"] ?? "OK")
    alert.runModal()
  }

  private func stopCapture() {
    pending?.invalidate(); pending = nil
  }

  func shutdown() {
    stopCapture()
    if let hotKey { UnregisterEventHotKey(hotKey) }
    hotKey = nil
    if let handler { RemoveEventHandler(handler) }
    handler = nil
    channel.setMethodCallHandler(nil)
  }

  deinit { shutdown() }
}
