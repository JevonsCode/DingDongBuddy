import Cocoa
import FlutterMacOS

public class WindowManagerPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "window_manager", binaryMessenger: registrar.messenger)
        let instance = WindowManagerPlugin(registrar, channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    private var registrar: FlutterPluginRegistrar!;
    private var channel: FlutterMethodChannel!

    private var mainWindow: NSWindow {
        get {
            return (self.registrar.view?.window)!;
        }
    }

    private var _inited: Bool = false
    private var windowManager: WindowManager = WindowManager()

    public init(_ registrar: FlutterPluginRegistrar, _ channel: FlutterMethodChannel) {
        super.init()
        self.registrar = registrar
        self.channel = channel
    }

    private func ensureInitialized() {
        if (!_inited) {
            windowManager.mainWindow = mainWindow
            windowManager.onEvent = {
                (eventName: String) in
                self._emitEvent(eventName)
            }
            _inited = true
        }
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let methodName: String = call.method
        let args: [String: Any] = call.arguments as? [String: Any] ?? [:]

        // Some application settings (for example a saved opacity) can be
        // restored before the shell's explicit ensureInitialized call. Make
        // every native operation safe regardless of Dart call ordering.
        ensureInitialized()

        switch (methodName) {
        case "ensureInitialized":
            result(true)
        case "waitUntilReadyToShow":
            windowManager.waitUntilReadyToShow()
            result(true)
        case "getId":
            result(windowManager.getId())
        case "setAsFrameless":
            windowManager.setAsFrameless()
            result(true)
        case "destroy":
            windowManager.destroy()
            result(true)
        case "close":
            windowManager.close()
            result(true)
        case "isPreventClose":
            result(windowManager.isPreventClose())
        case "setPreventClose":
            windowManager.setPreventClose(args)
            result(true)
        case "focus":
            windowManager.focus()
            result(true)
        case "blur":
            windowManager.blur()
            result(true)
        case "isFocused":
            result(windowManager.isFocused())
        case "show":
            windowManager.show()
            result(true)
        case "hide":
            windowManager.hide()
            result(true)
        case "isVisible":
            result(windowManager.isVisible())
        case "isMaximized":
            result(windowManager.isMaximized())
        case "maximize":
            windowManager.maximize()
            result(true)
        case "unmaximize":
            windowManager.unmaximize()
            result(true)
        case "isMinimized":
            result(windowManager.isMinimized())
        case "isMaximizable":
            result(windowManager.isMaximizable())
        case "setMaximizable":
            windowManager.setIsMaximizable(args)
            result(true)
        case "minimize":
            windowManager.minimize()
            result(true)
        case "restore":
            windowManager.restore()
            result(true)
        case "isDockable":
            result(windowManager.isDockable())
        case "isDocked":
            result(windowManager.isDocked())
        case "dock":
            windowManager.dock(args)
            result(true)
        case "undock":
            windowManager.undock()
            result(true)
        case "isFullScreen":
            result(windowManager.isFullScreen())
        case "setFullScreen":
            windowManager.setFullScreen(args)
            result(true)
        case "setAspectRatio":
            windowManager.setAspectRatio(args)
            result(true)
        case "setBackgroundColor":
            windowManager.setBackgroundColor(args)
            result(true)
        case "getBounds":
            result(windowManager.getBounds())
        case "setBounds":
            windowManager.setBounds(args)
            result(true)
        case "setMinimumSize":
            windowManager.setMinimumSize(args)
            result(true)
        case "setMaximumSize":
            windowManager.setMaximumSize(args)
            result(true)
        case "isResizable":
            result(windowManager.isResizable())
        case "setResizable":
            windowManager.setResizable(args)
            result(true)
        case "isMovable":
            result(windowManager.isMovable())
        case "setMovable":
            windowManager.setMovable(args)
            result(true)
        case "isMinimizable":
            result(windowManager.isMinimizable())
        case "setMinimizable":
            windowManager.setMinimizable(args)
            result(true)
        case "isClosable":
            result(windowManager.isClosable())
        case "setClosable":
            windowManager.setClosable(args)
            result(true)
        case "isAlwaysOnTop":
            result(windowManager.isAlwaysOnTop())
        case "setAlwaysOnTop":
            windowManager.setAlwaysOnTop(args)
            result(true)
        case "getTitle":
            result(windowManager.getTitle())
        case "setTitle":
            windowManager.setTitle(args)
            result(true)
        case "setTitleBarStyle":
            windowManager.setTitleBarStyle(args)
            result(true)
        case "getTitleBarHeight":
            result(windowManager.getTitleBarHeight())
        case "isSkipTaskbar":
            result(windowManager.isSkipTaskbar())
        case "setSkipTaskbar":
            windowManager.setSkipTaskbar(args)
            result(true)
        case "setBadgeLabel":
            windowManager.setBadgeLabel(args)
            result(true)
        case "setProgressBar":
            windowManager.setProgressBar(args)
            result(true)
        case "isVisibleOnAllWorkspaces":
            result(windowManager.isVisibleOnAllWorkspaces())
        case "setVisibleOnAllWorkspaces":
            windowManager.setVisibleOnAllWorkspaces(args)
            result(true)
        case "hasShadow":
            result(windowManager.hasShadow())
        case "setHasShadow":
            windowManager.setHasShadow(args)
            result(true)
        case "getOpacity":
            result(windowManager.getOpacity())
        case "setOpacity":
            windowManager.setOpacity(args)
            result(true)
        case "setBrightness":
            windowManager.setBrightness(args)
            result(true)
        case "setIgnoreMouseEvents":
            windowManager.setIgnoreMouseEvents(args)
            result(true)
        case "startDragging":
            windowManager.startDragging()
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    public func _emitEvent(_ eventName: String) {
        let args: NSDictionary = [
            "eventName": eventName,
        ]
        channel.invokeMethod("onEvent", arguments: args, result: nil)
    }
}
