import Cocoa
import Carbon.HIToolbox
import ApplicationServices
import FlutterMacOS
import ServiceManagement

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
          let registered = self?.registerClipboardHotKey() ?? false
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

  private func registerClipboardHotKey() -> Bool {
    guard hotKeyRef == nil else { return true }
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
    guard handlerStatus == noErr else { return false }
    let hotKeyID = EventHotKeyID(signature: 0x44444356, id: 1)
    let status = RegisterEventHotKey(
      UInt32(kVK_ANSI_V),
      UInt32(cmdKey | shiftKey),
      hotKeyID,
      GetApplicationEventTarget(),
      0,
      &hotKeyRef
    )
    if status != noErr { unregisterClipboardHotKey() }
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
