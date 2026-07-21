# DingDong 0.7.20

This release makes Agent resources deterministic, keeps completion state across
restarts, refreshes the desktop management experience, and introduces signed
one-click updates.

## Agent resources and completion activity

- Applies every matching Prompt automatically and in full, while Skills remain
  description-matched packages and MCP servers remain tools that are called
  only when a task needs them.
- Synchronizes enabled global Prompts into DingDong-managed Codex instructions
  without overwriting unrelated user rules.
- Persists unread completion notifications across restarts and acknowledges
  them only after the popup has remained visible for 0.5 seconds.
- Stores up to 200 completion details by default, shows a rolling 24-hour count,
  and lets users configure retention, count window, and restart persistence.
- Adds a read-only Recent Agent list to Resource Manager.

## Clipboard and resource management

- Keeps user-arranged clipboard group order across windows and restarts, and
  fixes deletion of the final clipboard item.
- Replaces legacy confirmation and input dialogs with the shared compact desktop
  treatment.
- Unifies resource import and export actions into one restrained segmented
  toolbar with consistent linear icons.
- Shows the application version beside DingDong; clicking it opens the update
  section, while clicking DingDong previews the configured notification sound.

## One-click updates

- Adds Sparkle 2 on macOS and Velopack on Windows for download, verification,
  transactional replacement, old-file cleanup, and automatic relaunch.
- Publishes signed architecture-specific Sparkle feeds, Apple Silicon and Intel
  macOS packages, and a per-user Windows x64 Setup/update feed.
- Apple Developer signing remains optional; Intel macOS and Windows stay beta.

---

本版本让 Agent 资源的生效逻辑更加确定，支持跨重启保留完成状态，统一桌面管理体验，
并加入带签名校验的一键更新。

## Agent 资源与完成动态

- 所有命中的 Prompt 都会完整、自动应用；Skill 仍先按 description 匹配再加载，
  MCP 仍只在任务确实需要时调用。
- 已启用的全局 Prompt 会写入 DingDong 托管的 Codex 指令区块，不覆盖用户原有规则。
- 未读完成提醒可跨重启保留，并且只有弹窗实际显示满 0.5 秒后才会确认已读。
- 默认保留最近 200 条完成详情并显示近 24 小时滚动计数；用户可以设置保留上限、
  计数时间窗口和是否跨重启记忆。
- 资源管理新增只读的“最近 Agent”列表。

## 剪贴板与资源管理

- 剪贴板分组顺序可跨窗口和重启保存，并修复最后一条剪贴板记录无法删除的问题。
- 确认和输入弹窗统一为新的紧凑桌面样式。
- 资源导入、分享 JSON 导入和导出合并为一组克制的分段工具栏，并使用统一线性图标。
- DingDong 旁显示应用版本；点击版本号直达更新设置，点击 DingDong 可试听当前提示音。

## 一键更新

- macOS 接入 Sparkle 2，Windows 接入 Velopack，一次点击完成下载、校验、事务式替换、
  旧文件清理和自动重启。
- 发布带签名的分架构 Sparkle 更新源、Apple Silicon 与 Intel macOS 安装包，以及
  Windows x64 按用户安装的 Setup 和更新源。
- Apple Developer 签名仍为可选项；Intel macOS 与 Windows 继续标记为 beta。
