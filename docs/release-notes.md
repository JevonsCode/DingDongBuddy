# DingDong 0.7.21

This release lets Agents install and configure project-scoped Skills through
DingDong, and polishes clipboard navigation and resource editing.

## Agent-managed Skills

- Adds DingDong MCP tools for installing or updating a Skill, upserting a
  reusable trigger group, and binding the Skill to an exact project scope.
- Synchronizes a scoped Skill only into the selected project's native Codex,
  Claude Code, Cursor, Gemini, and OpenCode skill directories instead of making
  it global.
- Rejects ambiguous Skill matches and unsafe or non-existent project paths.
- Updates the built-in DingDong Configure Skill and Agent installation guide so
  an Agent can complete the entire setup from a GitHub link.
- Clarifies that matching Prompts are injected automatically, Skills are loaded
  by task matching, and MCP tools are invoked only when required.

## Desktop refinements

- Keeps clipboard number shortcuts aligned with the currently visible record
  range after scrolling.
- Refines the Resource Manager editor breadcrumb and back control.
- Retains signed one-click update support for macOS and per-user updates for
  Windows; Intel macOS and Windows packages remain beta.

---

本版本支持 Agent 直接通过 DingDong 安装 Skill，并为它配置严格的项目触发范围，
同时优化剪贴板快捷键和资源编辑体验。

## Agent 管理 Skill

- 新增 DingDong MCP 工具，可安装或更新 Skill、创建或更新复用触发组，并将 Skill
  绑定到精确的项目范围。
- 有项目范围的 Skill 只会同步到对应项目里的 Codex、Claude Code、Cursor、Gemini
  和 OpenCode 原生 Skill 目录，不会变成全局 Skill。
- 对重名 Skill、歧义匹配、不安全路径和不存在的项目路径进行拒绝处理。
- 更新内置 DingDong Configure Skill 与 Agent 安装指南，Agent 拿到 GitHub 链接后
  可以完成安装与项目范围配置。
- 明确 Prompt 会在命中时自动完整注入，Skill 按任务匹配加载，MCP 工具仅在需要时调用。

## 桌面体验优化

- 滚动剪贴板列表后，数字快捷键会跟随当前可见记录范围。
- 优化资源管理编辑页的面包屑和返回按钮。
- 保留 macOS 签名一键更新与 Windows 按用户更新能力；Intel macOS 和 Windows
  安装包继续标记为 beta。
