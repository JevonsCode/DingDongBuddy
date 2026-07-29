import Cocoa
import Carbon.HIToolbox
import ApplicationServices
import FlutterMacOS
import ServiceManagement

private struct GlobalHotKeyConfiguration: Equatable {
  let keyCode: UInt32
  let modifiers: UInt32

  static let defaultValue = GlobalHotKeyConfiguration(
    keyCode: UInt32(kVK_ANSI_V),
    modifiers: UInt32(cmdKey | shiftKey)
  )

  init(keyCode: UInt32, modifiers: UInt32) {
    self.keyCode = keyCode
    self.modifiers = modifiers
  }

  init?(arguments: Any?) {
    guard let arguments else {
      self = .defaultValue
      return
    }
    guard let values = arguments as? [String: Any],
          let key = values["key"] as? String,
          let keyCode = Self.keyCode(for: key)
    else {
      return nil
    }
    var modifiers: UInt32 = 0
    if values["primary"] as? Bool == true { modifiers |= UInt32(cmdKey) }
    if values["secondary"] as? Bool == true { modifiers |= UInt32(controlKey) }
    if values["alt"] as? Bool == true { modifiers |= UInt32(optionKey) }
    if values["shift"] as? Bool == true { modifiers |= UInt32(shiftKey) }
    guard modifiers != 0 else { return nil }
    self.init(keyCode: keyCode, modifiers: modifiers)
  }

  private static func keyCode(for name: String) -> UInt32? {
    switch name {
    case "A": return UInt32(kVK_ANSI_A)
    case "B": return UInt32(kVK_ANSI_B)
    case "C": return UInt32(kVK_ANSI_C)
    case "D": return UInt32(kVK_ANSI_D)
    case "E": return UInt32(kVK_ANSI_E)
    case "F": return UInt32(kVK_ANSI_F)
    case "G": return UInt32(kVK_ANSI_G)
    case "H": return UInt32(kVK_ANSI_H)
    case "I": return UInt32(kVK_ANSI_I)
    case "J": return UInt32(kVK_ANSI_J)
    case "K": return UInt32(kVK_ANSI_K)
    case "L": return UInt32(kVK_ANSI_L)
    case "M": return UInt32(kVK_ANSI_M)
    case "N": return UInt32(kVK_ANSI_N)
    case "O": return UInt32(kVK_ANSI_O)
    case "P": return UInt32(kVK_ANSI_P)
    case "Q": return UInt32(kVK_ANSI_Q)
    case "R": return UInt32(kVK_ANSI_R)
    case "S": return UInt32(kVK_ANSI_S)
    case "T": return UInt32(kVK_ANSI_T)
    case "U": return UInt32(kVK_ANSI_U)
    case "V": return UInt32(kVK_ANSI_V)
    case "W": return UInt32(kVK_ANSI_W)
    case "X": return UInt32(kVK_ANSI_X)
    case "Y": return UInt32(kVK_ANSI_Y)
    case "Z": return UInt32(kVK_ANSI_Z)
    case "0": return UInt32(kVK_ANSI_0)
    case "1": return UInt32(kVK_ANSI_1)
    case "2": return UInt32(kVK_ANSI_2)
    case "3": return UInt32(kVK_ANSI_3)
    case "4": return UInt32(kVK_ANSI_4)
    case "5": return UInt32(kVK_ANSI_5)
    case "6": return UInt32(kVK_ANSI_6)
    case "7": return UInt32(kVK_ANSI_7)
    case "8": return UInt32(kVK_ANSI_8)
    case "9": return UInt32(kVK_ANSI_9)
    case "F1": return UInt32(kVK_F1)
    case "F2": return UInt32(kVK_F2)
    case "F3": return UInt32(kVK_F3)
    case "F4": return UInt32(kVK_F4)
    case "F5": return UInt32(kVK_F5)
    case "F6": return UInt32(kVK_F6)
    case "F7": return UInt32(kVK_F7)
    case "F8": return UInt32(kVK_F8)
    case "F9": return UInt32(kVK_F9)
    case "F10": return UInt32(kVK_F10)
    case "F11": return UInt32(kVK_F11)
    case "F12": return UInt32(kVK_F12)
    case "SPACE": return UInt32(kVK_Space)
    case "RETURN": return UInt32(kVK_Return)
    case "LEFT": return UInt32(kVK_LeftArrow)
    case "RIGHT": return UInt32(kVK_RightArrow)
    case "UP": return UInt32(kVK_UpArrow)
    case "DOWN": return UInt32(kVK_DownArrow)
    default: return nil
    }
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  private var clipboardMonitorChannel: FlutterMethodChannel?
  private var hotKeyChannel: FlutterMethodChannel?
  private var notificationChannel: FlutterMethodChannel?
  private var launchAtStartupChannel: FlutterMethodChannel?
  private var modifierChannel: FlutterMethodChannel?
  private var modifierMonitor: Any?
  private var hotKeyRef: EventHotKeyRef?
  private var hotKeyHandlerRef: EventHandlerRef?
  private var registeredHotKeyConfiguration: GlobalHotKeyConfiguration?
  private var previousApplication: NSRunningApplication?
  private var activeNotificationSound: NSSound?
  private var updaterChannel: FlutterMethodChannel?
  private var applicationUpdater: DingDongUpdater?
  private var desktopShellReady = false
  private var pendingApplicationOpen = false

  override func applicationDidFinishLaunching(_ notification: Notification) {
    let openedInteractively = NSApp.isActive ||
      NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "dingdong/clipboard_monitor",
        binaryMessenger: controller.engine.binaryMessenger
      )
      channel.setMethodCallHandler { call, result in
        switch call.method {
        case "changeCount":
          result(NSPasteboard.general.changeCount)
        case "sourceApplication":
          guard let application = NSWorkspace.shared.frontmostApplication else {
            result(nil)
            return
          }
          let name = application.localizedName ?? "Unknown"
          if let identifier = application.bundleIdentifier, !identifier.isEmpty {
            result("\(name) · \(identifier)")
          } else {
            result(name)
          }
        case "readTextFormats":
          var formats: [String: Any] = [:]
          if let htmlData = NSPasteboard.general.data(forType: .html),
             !htmlData.isEmpty
          {
            formats["htmlData"] = FlutterStandardTypedData(bytes: htmlData)
          }
          if let rtfData = NSPasteboard.general.data(forType: .rtf),
             !rtfData.isEmpty
          {
            formats["rtfData"] = FlutterStandardTypedData(bytes: rtfData)
          }
          result(formats)
        case "writeTextFormats":
          guard let arguments = call.arguments as? [String: Any],
                let plainText = arguments["plainText"] as? String
          else {
            result(
              FlutterError(
                code: "invalid_arguments",
                message: "plainText must be a string.",
                details: nil
              )
            )
            return
          }
          let item = NSPasteboardItem()
          item.setString(plainText, forType: .string)
          if let html = arguments["htmlData"] as? FlutterStandardTypedData,
             !html.data.isEmpty
          {
            item.setData(html.data, forType: .html)
          }
          if let rtf = arguments["rtfData"] as? FlutterStandardTypedData,
             !rtf.data.isEmpty
          {
            item.setData(rtf.data, forType: .rtf)
          }
          NSPasteboard.general.clearContents()
          _ = NSPasteboard.general.writeObjects([item])
          result(nil)
        case "writeImageFile":
          guard let arguments = call.arguments as? [String: Any],
                let path = arguments["path"] as? String,
                let imageData = arguments["imageData"] as? FlutterStandardTypedData,
                let image = NSImage(data: imageData.data),
                let tiffData = image.tiffRepresentation
          else {
            result(
              FlutterError(
                code: "invalid_image",
                message: "path and valid imageData are required.",
                details: nil
              )
            )
            return
          }
          let item = NSPasteboardItem()
          item.setString(URL(fileURLWithPath: path).absoluteString, forType: .fileURL)
          item.setData(tiffData, forType: .tiff)
          if let bitmap = NSBitmapImageRep(data: tiffData),
             let pngData = bitmap.representation(using: .png, properties: [:])
          {
            item.setData(pngData, forType: .png)
          }
          NSPasteboard.general.clearContents()
          result(NSPasteboard.general.writeObjects([item]))
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      clipboardMonitorChannel = channel

      let applicationUpdater = DingDongUpdater()
      self.applicationUpdater = applicationUpdater
      let updaterChannel = FlutterMethodChannel(
        name: "dingdong/updater",
        binaryMessenger: controller.engine.binaryMessenger
      )
      updaterChannel.setMethodCallHandler { call, result in
        switch call.method {
        case "isSupported":
          result(applicationUpdater.isSupported)
        case "state":
          result(applicationUpdater.state())
        case "installLatest":
          do {
            try applicationUpdater.installLatest()
            result(nil)
          } catch {
            result(
              FlutterError(
                code: "update_unavailable",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      self.updaterChannel = updaterChannel

      let hotKeyChannel = FlutterMethodChannel(
        name: "dingdong/global_hotkey",
        binaryMessenger: controller.engine.binaryMessenger
      )
      hotKeyChannel.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "register":
          guard let configuration = GlobalHotKeyConfiguration(
            arguments: call.arguments
          ) else {
            result(false)
            return
          }
          let registered =
            self?.registerClipboardHotKey(configuration: configuration) ?? false
          self?.desktopShellReady = true
          result(registered)
          self?.flushPendingApplicationOpen()
        case "unregister":
          self?.desktopShellReady = false
          self?.unregisterClipboardHotKey()
          result(nil)
        case "pasteToPrevious":
          result(self?.pasteIntoPreviousApplication() ?? false)
        case "isPastePermissionGranted":
          result(AXIsProcessTrusted())
        case "isApplicationActive":
          result(NSApp.isActive)
        case "openPastePermissionSettings":
          if let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
          ) {
            NSWorkspace.shared.open(url)
          }
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      self.hotKeyChannel = hotKeyChannel

      let modifierChannel = FlutterMethodChannel(
        name: "dingdong/modifier_keys",
        binaryMessenger: controller.engine.binaryMessenger
      )
      self.modifierChannel = modifierChannel
      modifierMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) {
        [weak self] event in
        guard let self else { return event }
        if event.type == .flagsChanged {
          self.modifierChannel?.invokeMethod(
            "commandChanged",
            arguments: event.modifierFlags.contains(.command)
          )
          return event
        }
        let shortcutFlags = event.modifierFlags.intersection([
          .command, .shift, .option, .control
        ])
        if event.type == .keyDown,
           self.mainFlutterWindow?.isKeyWindow == true,
           shortcutFlags == .command
        {
          switch event.charactersIgnoringModifiers?.lowercased() {
          case "q":
            self.hotKeyChannel?.invokeMethod("workspaceShortcut", arguments: "today")
            return nil
          case "r":
            self.hotKeyChannel?.invokeMethod("workspaceShortcut", arguments: "filters")
            return nil
          case "f":
            self.hotKeyChannel?.invokeMethod("workspaceShortcut", arguments: "search")
            return nil
          default:
            break
          }
        }
        return event
      }

      let notificationChannel = FlutterMethodChannel(
        name: "dingdong/notification",
        binaryMessenger: controller.engine.binaryMessenger
      )
      notificationChannel.setMethodCallHandler { [weak self] call, result in
        guard (call.method == "notify" || call.method == "preview"),
              let arguments = call.arguments as? [String: Any]
        else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.playNotificationSound(arguments)
        result(nil)
      }
      self.notificationChannel = notificationChannel

      let launchAtStartupChannel = FlutterMethodChannel(
        name: "dingdong/launch_at_startup",
        binaryMessenger: controller.engine.binaryMessenger
      )
      launchAtStartupChannel.setMethodCallHandler { call, result in
        guard #available(macOS 13.0, *) else {
          if call.method == "isEnabled" {
            result(false)
          } else {
            result(FlutterError(
              code: "unsupported",
              message: "Launch at startup requires macOS 13 or later.",
              details: nil
            ))
          }
          return
        }
        let service = SMAppService.mainApp
        switch call.method {
        case "isEnabled":
          result(service.status == .enabled)
        case "setEnabled":
          guard let arguments = call.arguments as? [String: Any],
                let enabled = arguments["enabled"] as? Bool
          else {
            result(FlutterError(
              code: "invalid_arguments",
              message: "enabled must be a boolean.",
              details: nil
            ))
            return
          }
          do {
            if enabled {
              try service.register()
            } else if service.status == .enabled || service.status == .requiresApproval {
              try service.unregister()
            }
            result(nil)
          } catch {
            result(FlutterError(
              code: "launch_at_startup_failed",
              message: error.localizedDescription,
              details: nil
            ))
          }
        default:
          result(FlutterMethodNotImplemented)
        }
      }
      self.launchAtStartupChannel = launchAtStartupChannel
    }
    super.applicationDidFinishLaunching(notification)
    if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
       let icon = NSImage(contentsOf: iconURL)
    {
      NSApp.applicationIconImage = icon
    }
    NSApp.setActivationPolicy(.accessory)
    mainFlutterWindow?.orderOut(nil)
    if openedInteractively {
      requestApplicationOpen()
    }
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    requestApplicationOpen()
    return false
  }

  override func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
    let menu = NSMenu()
    let usesChinese = Locale.preferredLanguages.first?
      .lowercased()
      .hasPrefix("zh") == true
    let item = NSMenuItem(
      title: usesChinese ? "隐藏 Dock 图标" : "Hide Dock Icon",
      action: #selector(hideDockIconFromDockMenu(_:)),
      keyEquivalent: ""
    )
    item.target = self
    menu.addItem(item)
    return menu
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationWillTerminate(_ notification: Notification) {
    if let modifierMonitor {
      NSEvent.removeMonitor(modifierMonitor)
    }
    unregisterClipboardHotKey()
    super.applicationWillTerminate(notification)
  }

  @objc private func hideDockIconFromDockMenu(_ sender: NSMenuItem) {
    NSApp.setActivationPolicy(.accessory)
    hotKeyChannel?.invokeMethod("hideDockIcon", arguments: nil)
  }

  private func playNotificationSound(_ arguments: [String: Any]) {
    let requested = (arguments["sound"] as? String) ?? "default"
    guard requested != "muted" else { return }

    let sound: NSSound?
    if requested == "custom",
       let path = arguments["customSoundPath"] as? String,
       !path.isEmpty
    {
      sound = NSSound(contentsOfFile: path, byReference: true)
    } else if let path = bundledDingSoundPath(requested) {
      sound = NSSound(contentsOfFile: path, byReference: false)
    } else {
      let systemName = requested == "system" ? "Glass" : "Ping"
      sound = NSSound(named: NSSound.Name(systemName))
    }

    activeNotificationSound?.stop()
    activeNotificationSound = sound
    sound?.play()
  }

  private func bundledDingSoundPath(_ requested: String) -> String? {
    let resolved = requested == "random"
      ? ["default", "dingSoft", "dingBright", "dingCrisp", "dingWood", "dingDeep"]
          .randomElement() ?? "default"
      : requested
    let fileName: String
    switch resolved {
    case "default": fileName = "ding-wood"
    case "dingSoft": fileName = "ding-soft"
    case "dingBright": fileName = "ding-bright"
    case "dingCrisp": fileName = "ding-crisp"
    case "dingWood": fileName = "ding-wood"
    case "dingDeep": fileName = "ding-deep"
    default: return nil
    }
    let relativePath = "App.framework/Resources/flutter_assets/Assets/Sounds/\(fileName).wav"
    guard let frameworks = Bundle.main.privateFrameworksURL else { return nil }
    let candidate = frameworks.appendingPathComponent(relativePath).path
    return FileManager.default.fileExists(atPath: candidate) ? candidate : nil
  }

  private func registerClipboardHotKey(
    configuration: GlobalHotKeyConfiguration
  ) -> Bool {
    if hotKeyRef != nil, registeredHotKeyConfiguration == configuration {
      return true
    }
    let previousConfiguration =
      registeredHotKeyConfiguration ?? GlobalHotKeyConfiguration.defaultValue
    let hadRegisteredHotKey = hotKeyRef != nil
    if let hotKeyRef {
      UnregisterEventHotKey(hotKeyRef)
      self.hotKeyRef = nil
    }
    guard installHotKeyHandlerIfNeeded() else { return false }
    if registerHotKeyOnly(configuration) {
      return true
    }
    if hadRegisteredHotKey || configuration != .defaultValue {
      _ = registerHotKeyOnly(previousConfiguration)
    }
    return false
  }

  private func installHotKeyHandlerIfNeeded() -> Bool {
    guard hotKeyHandlerRef == nil else { return true }
    var eventSpec = EventTypeSpec(
      eventClass: OSType(kEventClassKeyboard),
      eventKind: UInt32(kEventHotKeyPressed)
    )
    let handlerStatus = InstallEventHandler(
      GetApplicationEventTarget(),
      { _, _, userData in
        guard let userData else { return noErr }
        let app = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
        let foreground = NSWorkspace.shared.frontmostApplication
        if foreground?.bundleIdentifier != Bundle.main.bundleIdentifier {
          app.previousApplication = foreground
        }
        app.hotKeyChannel?.invokeMethod("pressed", arguments: nil)
        return noErr
      },
      1,
      &eventSpec,
      Unmanaged.passUnretained(self).toOpaque(),
      &hotKeyHandlerRef
    )
    return handlerStatus == noErr
  }

  private func registerHotKeyOnly(
    _ configuration: GlobalHotKeyConfiguration
  ) -> Bool {
    let hotKeyID = EventHotKeyID(signature: 0x44444356, id: 1)
    let status = RegisterEventHotKey(
      configuration.keyCode,
      configuration.modifiers,
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
    if status == noErr {
      registeredHotKeyConfiguration = configuration
    } else {
      hotKeyRef = nil
    }
    return status == noErr
  }

  private func requestApplicationOpen() {
    guard desktopShellReady else {
      pendingApplicationOpen = true
      return
    }
    hotKeyChannel?.invokeMethod("openApplication", arguments: nil)
  }

  private func flushPendingApplicationOpen() {
    guard desktopShellReady, pendingApplicationOpen else { return }
    pendingApplicationOpen = false
    DispatchQueue.main.async { [weak self] in
      self?.hotKeyChannel?.invokeMethod("openApplication", arguments: nil)
    }
  }

  private func unregisterClipboardHotKey() {
    if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
    if let hotKeyHandlerRef { RemoveEventHandler(hotKeyHandlerRef) }
    hotKeyRef = nil
    hotKeyHandlerRef = nil
    registeredHotKeyConfiguration = nil
  }

  @IBAction func openWebsite(_ sender: Any?) {
    guard let url = URL(
      string: "https://xn--8ovp9s.xn--m8txu.com/DingDongBuddy/"
    ) else { return }
    NSWorkspace.shared.open(url)
  }

  private func pasteIntoPreviousApplication() -> Bool {
    guard let previousApplication else { return false }
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    guard AXIsProcessTrustedWithOptions(options) else { return false }
    mainFlutterWindow?.orderOut(nil)
    previousApplication.activate(options: [.activateIgnoringOtherApps])
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
      guard let keyDown = CGEvent(
        keyboardEventSource: nil,
        virtualKey: CGKeyCode(kVK_ANSI_V),
        keyDown: true
      ), let keyUp = CGEvent(
        keyboardEventSource: nil,
        virtualKey: CGKeyCode(kVK_ANSI_V),
        keyDown: false
      ) else { return }
      keyDown.flags = .maskCommand
      keyUp.flags = .maskCommand
      keyDown.post(tap: .cghidEventTap)
      keyUp.post(tap: .cghidEventTap)
    }
    self.previousApplication = nil
    return true
  }
}
