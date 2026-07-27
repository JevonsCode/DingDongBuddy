# DingDong 0.7.27

This release adds configurable Agent integrations, protects archived clipboard
history, and tightens completion notifications and development-build isolation.

## Agent access and conversation launchers

- Adds **Resource Manager → Agent access** for viewing and editing declarative
  Agent Adapter YAML.
- Bundles validated adapters for Codex, Claude Code, Cursor, Gemini CLI, and
  Kiro, while allowing complete user overrides and custom clients.
- Keeps the current Adapter plus two earlier revisions, detects external YAML
  edits, and shows invalid documents without silently applying them.
- Synchronizes current resources immediately after an Adapter change and
  removes DingDong-managed Skill, Prompt, and MCP content from old targets when
  paths change or an Adapter is removed.
- Restricts user paths to the home directory after resolving symbolic links and
  rejects unsafe cross-platform project paths.
- Adds `agent-launchers.json` preferences for opening supported CLI Agent
  conversations in Terminal.app or an iTerm window or tab.

## Clipboard and Recent Agents

- Excludes pinned and archived records from automatic item and age limits,
  including legacy archives and user-created archive groups.
- Keeps protected history visible even when more than 5,000 newer ordinary
  records exist.
- Raises new-install clipboard defaults to 5,000 ordinary items and 120 days.
- Keeps Clipboard search text synchronized when the view is remounted and makes
  programmatic clearing visible in the field.
- Raises the default remembered Recent Agent detail capacity to 500 while
  retaining the 24-hour count window.

## Notifications and desktop development

- Deduplicates a completion-hook fallback only against the matching Agent's
  recent primary notification, including mixed source casing and interleaved
  Agent events.
- Leaves fallback-only notifications independent so separate tasks are not
  accidentally suppressed.
- Clarifies that the normal completion hook owns the final alert, while
  `dingdong_notify` remains available for blocked or waiting states.
- Isolates macOS Debug builds as **DingDong DEV** with a separate bundle ID,
  application-data directory, tray identity, visible badge, and disabled
  release updater.
- Expands the community-install documentation for macOS Gatekeeper,
  Accessibility permission, and safe app replacement.

Intel macOS and Windows packages remain beta.

---

本版本新增可配置的 Agent 接入，保护归档剪贴板历史，并收紧完成提醒与开发版隔离。

## Agent 接入与对话启动器

- 新增 **资源管理 → Agent 接入**，可查看和编辑声明式 Agent Adapter YAML。
- 内置 Codex、Claude Code、Cursor、Gemini CLI 和 Kiro 的严格校验定义，同时支持完整
  用户覆盖和自定义客户端。
- 保留当前版及前两个 Adapter 修订版本；可观察外部 YAML 修改，无效原文会显示出来，
  但不会被静默应用。
- Adapter 修改后立即同步当前资源；路径变化或 Adapter 删除时，会清理旧目标中由
  DingDong 托管的 Skill、Prompt 和 MCP 内容。
- 解析符号链接后仍要求用户路径位于主目录内，并拒绝跨平台不安全的项目相对路径。
- 新增 `agent-launchers.json`，可让受支持的 CLI Agent 对话通过 Terminal.app、
  iTerm 新窗口或新标签页恢复。

## 剪贴板与最近 Agent

- 置顶和归档记录不计入自动条数与时间限制，兼容旧版归档标记和用户创建的归档分组。
- 即使存在超过 5000 条更新的普通记录，受保护历史仍然可见。
- 新安装的剪贴板默认保留 5000 条普通记录、120 天。
- 剪贴板视图重新挂载或程序清空搜索时，输入框与实际筛选条件保持一致。
- 最近 Agent 完成详情默认容量提升到 500 条，计数窗口仍为 24 小时。

## 提醒与桌面开发

- 完成 Hook 的兜底提醒只与同一 Agent 最近的主提醒去重，支持来源大小写差异和多个
  Agent 交错到达。
- 纯兜底提醒彼此独立，避免不同任务被误抑制。
- 明确正常的最终完成提醒由 Hook 负责；`dingdong_notify` 继续用于阻塞或等待关注。
- macOS Debug 构建独立为 **DingDong DEV**，使用单独 Bundle ID、数据目录、托盘身份
  和可见标记，并关闭正式版更新器。
- 补充 macOS Gatekeeper、辅助功能授权和安全替换应用的社区安装说明。

Intel macOS 与 Windows 安装包继续标记为 beta。
