# DingDong 1.3.2

DingDong 1.3.2 lets one phone stay paired with multiple computers while keeping
each computer's content and connection state separate.

## Multiple computers on one phone

- Scan another computer without replacing the existing pairing. The PWA keeps
  every saved computer connected when available and restores them after a
  refresh.
- The online status now includes a green indicator and the number of connected
  computers. Open it to see every paired computer and switch the active one.
- Clipboard items, Agent reminders, files, unsent text, transfer progress, and
  notification diagnostics stay inside their source computer. Switching never
  mixes or moves records between devices.
- Scanning a new QR code while the PWA is already open starts the add-device
  flow without reloading or interrupting existing connections.

## Clearer connection and interface controls

- DingDong prefers a direct WebRTC connection, which is normally available on
  the same local network, and falls back to its end-to-end encrypted relay when
  direct connectivity is unavailable. The relay stores no Clipboard or file
  content.
- Phone settings can switch the in-app DingDong icon between a soft-blue and a
  white background. Because the operating system owns the installed Home Screen
  icon, changing that icon may require removing and re-adding the PWA.
- Completion-notification clicks remain bound to the correct computer and open
  Agent reminders directly without creating a competing connection.
- Reconnect attempts now back off after repeated network failures instead of
  rapidly cycling between connected and disconnected states.

Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.3.2 让一部手机可以同时保存并连接多台电脑，同时确保每台电脑的内容与
连接状态彼此独立。

## 一部手机连接多台电脑

- 扫描另一台电脑时会新增配对，不再替换已有电脑。PWA 会在条件允许时保持所有已
  保存电脑在线，并在刷新后恢复连接。
- 顶部在线状态增加绿色指示灯与在线电脑数量；点击即可查看所有已配对电脑并切换
  当前电脑。
- 剪贴板、Agent 提醒、文件、未发送文字、传输进度和通知诊断都跟随来源电脑独立
  保存；切换设备不会混合或搬动这些记录。
- PWA 已经打开时继续扫描新二维码，会直接进入添加设备流程，不重载页面，也不会
  中断已有连接。

## 更清楚的连接与界面控制

- DingDong 优先尝试 WebRTC 直连，通常在同一局域网内建立；无法直连时使用端到端
  加密中继兜底。中继不会保存剪贴板或文件正文。
- 手机设置可以在浅蓝和白色背景之间切换应用内 DingDong 图标。主屏幕图标由操作
  系统安装时生成，若要更新它，可能需要移除后重新添加 PWA。
- 点击完成通知时会严格绑定对应电脑，并直接打开 Agent 提醒，不会新建一个抢占连接
  的页面。
- 网络连续失败时，重连间隔会逐步延长，不再快速反复显示连接与断开。

Intel macOS 与 Windows 安装包继续标记为 beta。
