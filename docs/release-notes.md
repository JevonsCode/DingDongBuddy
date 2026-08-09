# DingDong 1.3.0

DingDong 1.3.0 introduces Connected Devices: a separate desktop manager and a
mobile PWA for deliberately moving clipboard items, files, and Agent completion
reminders between devices you trust.

## Connected Devices

- Open the dedicated Connected Devices window from the DingDong header or tray
  menu, then pair a phone by scanning the computer's QR code.
- Pairings survive page refreshes. Each device can be disconnected, reconnected,
  deleted, and configured independently.
- DingDong attempts a direct WebRTC connection and uses its encrypted relay as
  a fallback. The relay stores no clipboard or file content.
- A superseded browser tab stops reconnecting, avoiding the repeated
  connect/disconnect loop caused by two pages competing for the same pairing.
- Computer Clipboard and Agent reminders form a native swipe pager on mobile;
  users can switch them with either the tabs or a horizontal gesture.

## Deliberate Clipboard and file delivery

- Automatic computer-to-device delivery is off by default and can be enabled
  per device. It sends only new Clipboard captures created after pairing.
- Existing Clipboard history moves only through the new **Send to Device**
  action; the old operating-system share action is no longer used.
- The phone PWA never reads or watches the phone's system clipboard. It sends
  only text the user enters or pastes, or a selected file, after **Send** is
  pressed.
- Files up to 25 MB can be transferred. Computer-hosted content is available
  only while the source computer and receiving device remain connected.

## Agent completion reminders on mobile

- Completion reminders are enabled by default when notification permission and
  the Web Push subscription are ready.
- Mobile cards show a longer task description, source, and completion time, and
  the PWA can receive them while it is in the background.
- Tapping a completion notification opens Agent reminders directly. A running
  PWA is reused without reloading, while cold starts and older pages use a
  one-time, pairing-safe fallback.
- Vibration is optional per device. The notification diagnostics now distinguish
  browser subscription, provider acceptance, and notification creation, and
  include a direct user-initiated vibration test. Android and iOS can still
  override vibration through their system notification settings.
- Mobile resting and sleeping mascots alternate frames, matching the companion's
  animated desktop states.

## Development and reliability

- The DEV test panel now covers richer Agent reminders, reminder bursts,
  simulated phone text and files, automatic Clipboard delivery, manual device
  sharing, and the Connected Devices window.
- Web Push now uses RFC-standard `aes128gcm`, high urgency, a 24-hour TTL,
  bounded payloads, authenticated subscription updates, delivery-stage receipts,
  and safer stale-pairing handling.
- The public relay limits request sizes, provider hosts, and request rates, and
  keeps registration authority when a provider expires a subscription.
- Recent Agent summaries skip current DingDong and FULI marker lines, including
  the `🌠 FULI · 知识增强` form, and use the next meaningful line.
- Optional lifecycle statistics send only one install or upgrade event after
  explicit consent; no clipboard, file, Agent, activity, session, heartbeat, or
  feature-use data is collected.

Intel macOS and Windows packages remain marked as beta. PWA installation is
optional on Android; iPhone and iPad require a Home Screen web app for Web Push.
The iOS flow is implemented but still awaits a recorded real-device release pass.

---

DingDong 1.3.0 新增“连接设备”：通过独立的桌面管理窗口与手机 PWA，在自己信任
的设备之间主动传递剪贴板内容、文件和 Agent 完成提醒。

## 连接设备

- 从 DingDong 顶部或托盘菜单打开独立的“连接设备”窗口，展示二维码后用手机扫码
  配对。
- 配对会在页面刷新后保留；每台设备都可以独立断开、重新连接、删除和配置。
- DingDong 会先尝试 WebRTC 直连，必要时使用加密中继；中继不会保存剪贴板或文件
  正文。
- 被新页面替代的旧浏览器标签不会继续抢占连接，避免两个页面互相踢下线造成反复
  连接、断开。
- 手机端的“电脑剪贴板”和“Agent 提醒”组成原生横向分页，可以点击标签，也可以
  左右滑动切换。

## 主动传递剪贴板与文件

- 电脑向设备自动发送默认关闭，可按设备单独开启，并且只发送配对后新产生的剪贴板
  内容。
- 连接前的历史只有通过新的“**发送到设备**”操作才会传递，不再调用操作系统原生
  分享。
- 手机 PWA 不读取或监听手机系统剪贴板。只有用户主动输入或粘贴文字、选择文件，
  并点击“**发送**”后，内容才会进入电脑剪贴板列表。
- 单个文件上限为 25 MB；由电脑托管的内容只有在来源电脑与接收设备保持连接时才可
  获取。

## 手机 Agent 完成提醒

- 在通知权限和 Web Push 订阅准备好后，完成提醒会默认开启。
- 手机卡片展示更完整的任务说明、来源和完成时间；PWA 在后台时也可以收到系统通知。
- 点击完成通知会直接进入“Agent 提醒”。已经运行的 PWA 不会因此重载；冷启动与
  旧页面通过一次性、严格绑定当前配对的回退路径进入对应页面。
- 每台设备可单独开关震动。通知诊断会区分浏览器订阅、推送服务接受和浏览器创建
  通知，并提供一次由用户点击触发的直接震动测试。Android 与 iOS 的系统通知设置
  仍可能覆盖震动效果。
- 手机端休息与睡眠小人也会切换双帧，与桌面伙伴的动画状态保持一致。

## 开发与可靠性

- DEV 测试面板新增长说明 Agent 提醒、连续提醒、模拟手机文字与文件、自动发送
  剪贴板、主动发送到设备和打开连接设备窗口等测试。
- Web Push 改用标准 `aes128gcm`，并加入高优先级、24 小时 TTL、载荷边界、订阅
  鉴权、分阶段回执和旧配对隔离。
- 公网中继限制请求体、推送服务域名和请求频率；推送服务清理过期订阅后，房间鉴权
  仍会保留。
- 最近 Agent 摘要会跳过当前 DingDong 与 FULI 标识行，包括
  `🌠 FULI · 知识增强`，并从下一条有效文本开始展示。
- 匿名生命周期统计只有在用户明确同意后才会发送一次安装或升级事件；不会收集
  剪贴板、文件、Agent、动态、会话、心跳或功能使用数据。

Intel macOS 与 Windows 安装包继续标记为 beta。Android 不安装 PWA 也可使用；
iPhone 与 iPad 需要先添加到主屏幕，才能使用 Web Push；iOS 流程已经实现，
但仍待补一轮有记录的真实设备发布验收。
