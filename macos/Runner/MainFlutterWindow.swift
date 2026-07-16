import Cocoa
import FlutterMacOS
import desktop_multi_window

private final class DesktopContextMenuTarget: NSObject {
  var selectedAction: String?

  @objc func selectAction(_ sender: NSMenuItem) {
    selectedAction = sender.representedObject as? String
  }
}

class MainFlutterWindow: NSWindow {
  private var systemActionChannels: [FlutterMethodChannel] = []
  private var sharingPicker: NSSharingServicePicker?

  override var canBecomeKey: Bool { true }
  override var canBecomeMain: Bool { true }

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    flutterViewController.backgroundColor = .clear
    self.contentViewController = flutterViewController
    self.styleMask = [.borderless, .resizable]
    self.setContentSize(NSSize(width: 390, height: 760))
    self.minSize = NSSize(width: 390, height: 540)
    self.maxSize = NSSize(width: 390, height: 940)
    self.isOpaque = false
    self.backgroundColor = .clear
    self.hasShadow = true
    self.isMovable = true
    self.isMovableByWindowBackground = true
    self.level = .statusBar
    self.collectionBehavior = [.canJoinAllSpaces, .transient]

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerSystemActions(for: flutterViewController)
    FlutterMultiWindowPlugin.setOnWindowCreatedCallback { [weak self] controller in
      RegisterGeneratedPlugins(registry: controller)
      controller.backgroundColor = .clear
      self?.registerSystemActions(for: controller)
    }

    super.awakeFromNib()
  }

  override func keyDown(with event: NSEvent) {
    if event.keyCode == 53 {
      orderOut(nil)
      return
    }
    super.keyDown(with: event)
  }

  private func registerSystemActions(for controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: "dingdong/system_actions",
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self, weak controller] call, result in
      guard let self, let view = controller?.view else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "shareText":
        guard let arguments = call.arguments as? [String: Any],
              let content = arguments["content"] as? String
        else {
          result(FlutterError(
            code: "invalid_arguments",
            message: "content must be a string.",
            details: nil
          ))
          return
        }
        let picker = NSSharingServicePicker(items: [content])
        self.sharingPicker = picker
        picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
        result(nil)
      case "showContextMenu":
        guard let arguments = call.arguments as? [String: Any],
              let entries = arguments["items"] as? [[String: Any]]
        else {
          result(FlutterError(
            code: "invalid_arguments",
            message: "items must be a context menu entry list.",
            details: nil
          ))
          return
        }
        result(self.showContextMenu(
          in: view,
          useChinese: arguments["useChinese"] as? Bool ?? false,
          entries: entries
        ))
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    systemActionChannels.append(channel)
  }

  private func showContextMenu(
    in view: NSView,
    useChinese: Bool,
    entries: [[String: Any]]
  ) -> String? {
    let menu = NSMenu()
    menu.autoenablesItems = false
    let target = DesktopContextMenuTarget()

    for entry in entries {
      if entry["separator"] as? Bool == true {
        menu.addItem(.separator())
        continue
      }
      guard let action = entry["id"] as? String,
            let english = entry["englishLabel"] as? String,
            let chinese = entry["chineseLabel"] as? String
      else {
        continue
      }
      let item = NSMenuItem(
        title: useChinese ? chinese : english,
        action: #selector(DesktopContextMenuTarget.selectAction(_:)),
        keyEquivalent: ""
      )
      item.target = target
      item.representedObject = action
      item.isEnabled = entry["enabled"] as? Bool ?? true
      menu.addItem(item)
    }

    let screenPoint = NSEvent.mouseLocation
    let windowPoint = view.window?.convertPoint(fromScreen: screenPoint) ?? .zero
    let viewPoint = view.convert(windowPoint, from: nil)
    menu.popUp(positioning: nil, at: viewPoint, in: view)
    return target.selectedAction
  }
}
