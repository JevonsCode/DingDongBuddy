import Cocoa
import FlutterMacOS

let kEventOnTrayIconMouseDown = "onTrayIconMouseDown"
let kEventOnTrayIconMouseUp = "onTrayIconMouseUp"
let kEventOnTrayIconRightMouseDown = "onTrayIconRightMouseDown"
let kEventOnTrayIconRightMouseUp = "onTrayIconRightMouseUp"
let kEventOnTrayMenuItemClick = "onTrayMenuItemClick"
let kEventOnTaskbarAppearanceChanged = "onTaskbarAppearanceChanged"

extension NSRect {
    var topLeft: CGPoint {
        set {
            let screenFrameRect = NSScreen.screens[0].frame
            origin.x = newValue.x
            origin.y = screenFrameRect.height - newValue.y - size.height
        }
        get {
            let screenFrameRect = NSScreen.screens[0].frame
            return CGPoint(x: origin.x, y: screenFrameRect.height - origin.y - size.height)
        }
    }
}

public class TrayManagerPlugin: NSObject, FlutterPlugin, NSMenuDelegate {
    var channel: FlutterMethodChannel!
    
    var trayIcon: TrayIcon?
    var trayMenu: TrayMenu?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "tray_manager", binaryMessenger: registrar.messenger)
        let instance = TrayManagerPlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "destroy":
            destroy(call, result: result)
        case "getBounds":
            getBounds(call, result: result)
        case "getTaskbarSurfaceIsLight":
            getTaskbarSurfaceIsLight(call, result: result)
        case "setIcon":
            setIcon(call, result: result)
        case "setIconPosition":
            setIconPosition(call, result: result)
        case "shakeIcon":
            shakeIcon(call, result: result)
        case "nudgeIcon":
            nudgeIcon(call, result: result)
        case "setToolTip":
            setToolTip(call, result: result)
        case "setTitle":
            setTitle(call, result: result)
        case "setContextMenu":
            setContextMenu(call, result: result)
        case "popUpContextMenu":
            popUpContextMenu(call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func destroy(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if (trayIcon?.statusItem != nil) {
            NSStatusBar.system.removeStatusItem((trayIcon?.statusItem)!)
        }
        if (trayIcon != nil) {
            trayIcon?.removeImage()
            trayIcon = nil
        }
        result(true)
    }
    
    public func getBounds(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let frame = trayIcon?.statusItem?.button?.window?.frame;
        
        if (frame != nil) {
            let resultData: NSDictionary = [
                "x": frame!.topLeft.x,
                "y": frame!.topLeft.y,
                "width": frame!.size.width,
                "height": frame!.size.height,
            ]
            result(resultData)
        } else {
            result(nil)
        }
    }

    public func getTaskbarSurfaceIsLight(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if let trayIcon {
            result(trayIcon.surfaceIsLight)
            return
        }
        let match = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua])
        result(match != .darkAqua)
    }
    
    public func setIcon(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        let base64Icon: String =  args["base64Icon"] as! String;
        let isTemplate: Bool =  args["isTemplate"] as! Bool;
        let iconPosition: String =  args["iconPosition"] as! String;
        let iconSize: Int = args["iconSize"] as! Int;
        
        let imageData = Data(base64Encoded: base64Icon, options: .ignoreUnknownCharacters)
        let image = NSImage(data: imageData!)
        image!.size = NSSize(width: iconSize, height: iconSize)
        image!.isTemplate = isTemplate
        
        if (trayIcon == nil) {
            trayIcon = TrayIcon()
            trayIcon?.onTrayIconMouseDown = { () in
                self.channel.invokeMethod(kEventOnTrayIconMouseDown, arguments: nil, result: nil)
            }
            trayIcon?.onTrayIconMouseUp = { () in
                self.channel.invokeMethod(kEventOnTrayIconMouseUp, arguments: nil, result: nil)
            }
            trayIcon?.onTrayIconRightMouseDown = { () in
                self.channel.invokeMethod(kEventOnTrayIconRightMouseDown, arguments: nil, result: nil)
            }
            trayIcon?.onTrayIconRightMouseUp = { () in
                self.channel.invokeMethod(kEventOnTrayIconRightMouseUp, arguments: nil, result: nil)
            }
            trayIcon?.onAppearanceChanged = { [weak self] isLight in
                self?.channel.invokeMethod(
                    kEventOnTaskbarAppearanceChanged,
                    arguments: isLight,
                    result: nil
                )
            }
        }
        
        trayIcon?.setImage(image!, iconPosition)
        
        result(true)
    }
    
    public func setIconPosition(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        let iconPosition: String =  args["iconPosition"] as! String;
        
        trayIcon?.setImagePosition(iconPosition)
        
        result(true)
    }

    public func shakeIcon(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        trayIcon?.shake()
        result(true)
    }

    public func nudgeIcon(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        trayIcon?.nudge()
        result(true)
    }

    public func setToolTip(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        let toolTip: String =  args["toolTip"] as! String;
        
        trayIcon?.setToolTip(toolTip)
        
        result(true)
    }
    
    public func setTitle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        let title: String =  args["title"] as! String;
        let style: String = args["style"] as? String ?? "plain";
        let badgeColorRgb = (args["badgeColorRgb"] as? NSNumber)?.uint32Value
        
        trayIcon?.setTitle(title, style, badgeColorRgb)
        
        result(true)
    }
    
    public func setContextMenu(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args:[String: Any] = call.arguments as! [String: Any]
        
        trayMenu = TrayMenu(args["menu"] as! [String: Any])
        trayMenu?.onMenuItemClick = { [weak self] (menuItem: NSMenuItem) in
            guard let strongSelf = self else { return }
            let args: NSDictionary = [
                "id": menuItem.tag,
            ]
            strongSelf.channel.invokeMethod(kEventOnTrayMenuItemClick, arguments: args, result: nil)
        }
        trayMenu?.delegate = self

        result(true)
    }
    
    public func popUpContextMenu(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if (trayMenu != nil) {
            trayIcon?.statusItem?.menu = trayMenu
            trayIcon?.statusItem?.button?.performClick(trayIcon)
        }
        result(true)
    }
    public func menuDidClose(_ menu: NSMenu) {
        trayIcon?.statusItem?.menu = nil
    }
}
