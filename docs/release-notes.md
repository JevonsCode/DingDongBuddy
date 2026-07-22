# DingDong 0.7.26

This release keeps DingDong's resource views consistent, makes scoped Skills
visible, improves macOS access, and fixes several Windows desktop behaviors.

## Resource synchronization and scope clarity

- Refreshes the popup library after resources are created, edited, enabled,
  disabled, or deleted in Resource Manager.
- Reloads the latest on-disk library whenever the popup is reopened or the
  Library workspace is entered, recovering safely from a missed window signal.
- Shows the complete Enabled resource list instead of limiting it to three.
- Marks scoped Skills in Resource Manager, the popup Library, and Dynamic with
  a clear `Scoped` label while keeping trigger groups as the source of truth.
- Keeps Agent API mutations compatible with stores that return unmodifiable
  resource lists.

## Skill import and Agent verification

- Accepts GitHub Skill repositories, folders, `blob` `SKILL.md` links, and raw
  `SKILL.md` links.
- Adds working `user-taste` and `grilling` examples when a Skill URL is invalid.
- Separates implemented Agent integrations from real-client verification in the
  README; Codex and Claude Code are verified end to end on macOS.

## Desktop fixes

- Reveals and focuses the panel when DingDong is opened from Applications,
  Launchpad, or Spotlight, including when the app is already running.
- Restores the user's Command-dragged macOS menu bar icon position after
  relaunching DingDong.
- Warns macOS users that an application update may require granting permissions
  again.
- Refreshes replacement tray icons immediately on Windows.
- Dismisses Flutter-owned context menus before the Windows panel is hidden so
  stale routes cannot reappear later.
- Hides Share actions on Windows, where the native share bridge is unavailable.

## Website

- Updates the interactive DingDong model to match the current popup header,
  compact status and metric cards, Recent Agent rows, Enabled cards, version,
  and scoped-Skill treatment.

Intel macOS and Windows packages remain beta.

---

本版本让 DingDong 的资源视图保持一致，明确展示 Skill 的触发范围，同时改善 macOS
入口并修复多项 Windows 桌面行为。

## 资源同步与触发范围

- 在资源管理器中创建、编辑、启用、停用或删除资源后，唤出面板的资源库会立即刷新。
- 每次重新唤出面板或进入资源库时都会重新读取磁盘状态，跨窗口通知遗漏后也能恢复。
- “已启用”不再只展示前三项，而是展示完整资源列表。
- 在资源管理器、唤出面板资源库和 Dynamic 中为限定范围的 Skill 显示“有触发范围”，
  并继续以触发组关系作为判断依据。
- Agent API 现在兼容返回只读资源列表的存储实现。

## Skill 导入与 Agent 实测状态

- 支持从 GitHub Skill 仓库、目录、`blob` `SKILL.md` 和 raw `SKILL.md` 地址导入。
- Skill 地址无效时展示可直接参考的 `user-taste` 与 `grilling` 示例。
- README 将“已实现”和“真实客户端端到端验证”分开记录；Codex 与 Claude Code
  已在 macOS 端到端验证。

## 桌面端修复

- 从“应用程序”、Launchpad 或 Spotlight 打开 DingDong 时会显示并聚焦面板；应用
  已在运行时再次点击也同样生效。
- macOS 菜单栏图标经 Command 拖拽后，会在下次启动恢复用户排列的位置。
- macOS 检测到更新时，会提前提示更新后可能需要重新授予系统权限。
- Windows 更换托盘图标后立即刷新显示。
- Windows 隐藏面板前会关闭 Flutter 菜单，避免旧菜单路由在再次打开时出现。
- Windows 未提供原生分享桥接时，不再展示无法使用的“分享”操作。

## 官网

- 官网交互模型已同步当前唤出面板的页头、紧凑状态和指标卡、最近 Agent、已启用
  资源、版本号以及“有触发范围”样式。

Intel macOS 和 Windows 安装包继续标记为 beta。
