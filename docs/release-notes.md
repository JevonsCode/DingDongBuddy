# DingDong 1.0.1

DingDong 1.0.1 is a focused fix release for clipboard history refresh and a
smaller appearance-settings surface.

## Clipboard refresh

- Images copied with ChatGPT's **Copy Image** action now appear in clipboard
  history immediately after DingDong stores them.
- The main Clipboard workspace reloads after every successful durable capture,
  so its list and item count no longer remain stale until the view is reopened.
- An already-open Resource Manager receives the same cross-window refresh and
  keeps its Clipboard list synchronized.
- Existing duplicate promotion and tray copy feedback continue to work as
  before.

## Settings cleanup

- Removes the ineffective List density choice from Settings.
- Retires its saved preference and compact-layout branches; Clipboard and
  Library lists now consistently use the previous Comfortable spacing.

## Reliability

- Adds regression coverage for capture-completion ordering, main-window refresh
  wiring, and Resource Manager cross-window updates.

Intel macOS and Windows packages remain beta.

---

DingDong 1.0.1 是一个修复剪贴板历史刷新问题并精简外观设置的版本。

## 剪贴板刷新

- 使用 ChatGPT 的 **Copy Image** 后，图片在 DingDong 完成存储时会立即出现在
  剪贴板历史中。
- 每次成功持久化捕获后，主窗口的剪贴板列表与数量都会自动重新载入，不再需要离开页面
  再回来才能看到新内容。
- 已打开的独立资源管理器也会收到跨窗口刷新，保持其中的剪贴板列表同步。
- 原有的重复内容提升和托盘复制反馈行为保持不变。

## 设置精简

- 从设置中移除没有实际价值的“列表密度”选项。
- 同步删除对应的持久化状态和紧凑布局分支；剪贴板与资源库列表统一使用原先的舒展间距。

## 稳定性

- 新增捕获完成时序、主窗口刷新接线和资源管理器跨窗口更新的回归测试。

Intel macOS 与 Windows 安装包继续标记为 beta。
