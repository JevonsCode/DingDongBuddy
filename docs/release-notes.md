# DingDong 1.4.2

DingDong 1.4.2 keeps the Windows background process alive when auxiliary
windows are closed and adds a safe update path for the linked-phone PWA.

## Close Windows windows without quitting DingDong

- Closing Settings, Resource Manager, Device Link, or the development panel now
  hides that window instead of terminating the DingDong process.
- Title-bar close controls and close actions inside Settings and Resource
  Manager follow the same hide-on-close policy.
- Process termination remains reserved for the explicit Quit command, so tray
  reminders and background connections continue running after a window closes.
- Shared platform behavior and regression coverage keep all auxiliary windows
  consistent without changing macOS behavior.

## Update the PWA without scanning again

- The PWA checks for a newer application shell after launch, when returning to
  the foreground, and through a new manual upgrade button in Device Settings.
- A no-cache version descriptor and service-worker update check make a newly
  deployed shell discoverable without waiting for stale cached metadata.
- Before applying an update, DingDong preserves all saved computer pairings;
  the refreshed PWA reconnects without requiring another QR-code scan.
- The settings dialog reports update progress, current version, offline retry,
  and failure states while leaving pairing data untouched.

Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.4.2 修复了 Windows 辅助窗口被关闭时误退出整个后台进程的问题，并为
关联手机 PWA 增加了安全的升级入口。

## 关闭 Windows 窗口但不退出 DingDong

- 关闭设置、资源管理、设备连接或开发测试面板时，现在只会隐藏对应窗口，不再终止
  DingDong 进程。
- 标题栏关闭按钮，以及设置和资源管理中的关闭操作，统一遵循“关闭即隐藏”策略。
- 只有显式选择“退出”才会终止进程，因此窗口关闭后，托盘提醒与后台连接仍会继续
  运行。
- 共用的平台策略与回归测试保证所有辅助窗口行为一致，同时不改变 macOS 行为。

## PWA 升级后无需重新扫码

- PWA 会在启动后、重新回到前台时检查新应用壳，也可以在设备设置中点击“手动升级”。
- 无缓存版本描述文件与 Service Worker 更新检查可以及时发现新部署版本，不受旧缓存
  元数据影响。
- 应用更新前会保存所有已连接电脑；刷新后的 PWA 会自动恢复连接，不需要重新扫描
  二维码。
- 设置界面会显示当前版本、升级进度、离线重试与失败状态，且不会改动配对数据。

Intel macOS 与 Windows 安装包继续标记为 beta。
