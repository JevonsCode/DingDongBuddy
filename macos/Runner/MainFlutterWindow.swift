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
  private var settingsSearchControllers: [AnyObject] = []

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
    self.collectionBehavior = [.moveToActiveSpace, .transient]

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
    if #available(macOS 11.0, *) {
      settingsSearchControllers.append(SettingsSearchToolbar(controller: controller))
    }
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
          isDark: arguments["isDark"] as? Bool ?? false,
          entries: entries
        ))
      case "showMenuBarRecovery":
        (NSApp.delegate as? AppDelegate)?.showMenuBarRecoveryAssistant()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    systemActionChannels.append(channel)
  }

  private func showContextMenu(
    in view: NSView,
    isDark: Bool,
    entries: [[String: Any]]
  ) -> String? {
    let menu = NSMenu()
    menu.appearance = NSAppearance(
      named: isDark ? .darkAqua : .aqua
    )
    menu.autoenablesItems = false
    let target = DesktopContextMenuTarget()

    for entry in entries {
      if entry["separator"] as? Bool == true {
        menu.addItem(.separator())
        continue
      }
      guard let action = entry["id"] as? String,
            let label = entry["label"] as? String
      else {
        continue
      }
      let item = NSMenuItem(
        title: label,
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


/// Per-engine toolbar: only the dedicated settings engine requests configure.
@available(macOS 11.0, *)
private final class SettingsSearchToolbar: NSObject, NSToolbarDelegate, NSSearchFieldDelegate {
  private let channel: FlutterMethodChannel
  private weak var controller: FlutterViewController?
  private let toolbar = NSToolbar(identifier: "dingdong.settings")
  private let searchItem = NSSearchToolbarItem(itemIdentifier: NSToolbarItem.Identifier("settingsSearch"))

  init(controller: FlutterViewController) {
    self.controller = controller
    channel = FlutterMethodChannel(name: "dingdong/settings_search", binaryMessenger: controller.engine.binaryMessenger)
    super.init()
    toolbar.delegate = self
    toolbar.allowsUserCustomization = false
    toolbar.displayMode = .iconOnly
    searchItem.searchField.delegate = self
    searchItem.searchField.sendsSearchStringImmediately = true
    searchItem.searchField.sendsWholeSearchString = false
    searchItem.preferredWidthForSearchField = 240
    searchItem.searchField.widthAnchor.constraint(equalToConstant: 240).isActive = true
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else { result(false); return }
      switch call.method {
      case "configure":
        guard let window = self.controller?.view.window else { result(false); return }
        let placeholder = (call.arguments as? [String: Any])?["placeholder"] as? String ?? ""
        self.searchItem.searchField.placeholderString = placeholder
        self.searchItem.searchField.setAccessibilityLabel(placeholder)
        self.searchItem.label = placeholder
        window.toolbarStyle = .unified
        window.toolbar = self.toolbar
        result(true)
      case "setQuery":
        self.searchItem.searchField.stringValue = call.arguments as? String ?? ""
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [.flexibleSpace, searchItem.itemIdentifier]
  }

  func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    toolbarDefaultItemIdentifiers(toolbar)
  }

  func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
               willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
    itemIdentifier == searchItem.itemIdentifier ? searchItem : nil
  }

  func controlTextDidChange(_ notification: Notification) {
    channel.invokeMethod("queryChanged", arguments: searchItem.searchField.stringValue)
  }
}
