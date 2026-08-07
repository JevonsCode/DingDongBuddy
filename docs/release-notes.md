# DingDong 1.2.0

DingDong 1.2.0 expands resource import and durability, adds clearer Agent
loading labels, and improves desktop storage and macOS recovery workflows.

## Resource library

- Resources can define an optional Agent conversation loading name, limited to
  seven Unicode characters.
- The built-in reply-marker Prompt uses `🌟`; the built-in DingDong Configure
  Skill remains loaded but is hidden from the Agent conversation summary.
- JSON files and links can be imported with conflict review, source-link
  resolution, and import history.
- Online resources preserve their source links, while history keeps the latest
  import records available for review.

## Clipboard archive and storage

- Custom Clipboard groups are promoted into independent permanent archive
  entries instead of depending on expiring history rows.
- Retention and cleanup protect archived entries and their managed images.
- Storage usage now separates Clipboard images, text, files, and archives, with
  per-category cleanup counts.

## Desktop recovery

- macOS adds a menu-bar recovery assistant from Settings and the Dock menu.
- Status-item Command-drag recovery and native menu-bar diagnostics are more
  explicit and easier to verify.

## Agent API

- Resource JSON and Agent routes persist the new loading-name and hidden-summary
  fields consistently.
- Bridge summaries omit resources marked as hidden while still delivering their
  Prompt, Skill, or MCP behavior.

Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.2.0 扩展了资源导入与持久归档能力，新增更清晰的 Agent 加载名称，
并改进桌面存储统计和 macOS 恢复流程。

## 资源库

- 资源支持可选的 Agent 会话加载名称，最多 7 个 Unicode 字符。
- 内置回复标记 Prompt 使用 `🌟`；内置 DingDong Configure Skill 继续加载，
  但默认不显示在 Agent 会话摘要中。
- 支持导入 JSON 文件和链接，并提供冲突复核、来源链接解析和导入历史。
- 在线资源保留来源链接，最近的导入记录可在历史中查看。

## 剪贴板归档与存储

- 自定义剪贴板分组会提升为独立的永久归档项，不再依赖会过期的历史记录。
- 保留策略和清理操作会保护归档项及其托管图片。
- 存储用量现在分别统计剪贴板图片、文本、文件和归档，并显示分类清理数量。

## 桌面恢复

- macOS 在设置和 Dock 菜单中提供菜单栏恢复助手。
- 状态栏图标的 Command-拖动恢复和原生菜单栏诊断更加明确、易于验证。

## Agent API

- 资源 JSON 和 Agent 路由统一持久化新的加载名称与会话隐藏字段。
- Bridge 摘要会省略标记为隐藏的资源，但仍会正常提供其 Prompt、Skill 或 MCP 能力。

Intel macOS 与 Windows 安装包继续标记为 beta。
