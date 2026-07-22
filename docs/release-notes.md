# DingDong 0.7.25

This release turns DingDong into a safer system-wide resource hub for coding
Agents. Prompts, Skills, and MCP servers stay centrally managed while native
copies are distributed to Codex, Claude Code, Cursor, Gemini CLI, and Kiro.

## Central Agent resource management

- Synchronizes global always-on Prompts into DingDong-managed blocks in both
  Codex `AGENTS.md` and Claude Code `CLAUDE.md`, preserving user instructions.
- Centralizes supported client paths and capabilities in one Agent adapter
  registry, making future Agent integrations easier to add consistently.
- Treats the DingDong library and Package Store as the logical source for each
  Skill while native Agent directories remain deployment mirrors.
- Refreshes every active managed Skill mirror after editing or renaming and
  removes stale managed directory names from previous synchronizations.

## Problems and conflict protection

- Adds a persistent, first-level Issues workspace in Resource Manager with a
  manual detection action and links back to affected resources.
- Replaces the old simulated refresh control with a red issue indicator that
  opens the full Issues workspace when attention is needed.
- Detects user-owned Skill name conflicts, duplicate DingDong destinations,
  missing or invalid Skill packages, invalid project paths, malformed MCP
  resources, and invalid Agent MCP files before writing.
- Rolls back failed resource saves and preserves existing Agent files when a
  blocking synchronization problem is found.
- Reports same-name Skills from enabled Claude Code plugins as non-blocking
  warnings because plugin and native Skill namespaces can coexist.

## Update visibility

- Checks release metadata without blocking startup and shows a small orange-red
  dot beside the header version when a newer DingDong release is available.
- Keeps the existing version click target, which opens Settings directly at the
  version and update section.

Intel macOS and Windows packages remain beta.

---

本版本把 DingDong 完善为更安全的全局 Agent 资源管理中心。Prompt、Skill 和 MCP
Server 在一个地方集中维护，再分发到 Codex、Claude Code、Cursor、Gemini CLI 与
Kiro 的原生位置。

## 集中管理 Agent 资源

- 将全局、始终生效的 Prompt 同步到 Codex `AGENTS.md` 与 Claude Code
  `CLAUDE.md` 的 DingDong 托管区块，同时保留用户原有规则。
- 把各 Agent 的路径和能力集中到统一适配器表，后续新增 Agent 时可以一致扩展。
- 以 DingDong 资源库和内部 Package Store 作为 Skill 的逻辑来源，各 Agent 原生
  Skill 目录只保存部署镜像。
- 编辑或重命名 Skill 后刷新所有已启用的托管镜像，并清理以前同步留下的旧目录名。

## 问题中心与冲突保护

- 在资源管理中新增常驻的“问题”一级入口，支持手动检测，并可跳转到受影响资源。
- 用红色问题提示替代原先的模拟刷新按钮；需要处理时点击即可打开完整问题页面。
- 写入前检测用户自有 Skill 同名、DingDong 资源目标重复、Skill Package 缺失或
  无效、项目路径无效、MCP 资源无效以及 Agent MCP 配置文件损坏等问题。
- 遇到阻断问题时回滚本次资源保存，保留已有 Agent 文件不变。
- 已启用的 Claude Code 插件提供同名 Skill 时显示非阻断警告，因为插件与原生
  Skill 的命名空间可以共存。

## 新版本提示

- 启动时非阻塞检查发布信息；检测到更高版本后，在页头版本号右侧显示一个橘红色
  小圆点。
- 保留原有版本号点击行为，点击后直接打开设置中的版本与更新区域。

Intel macOS 和 Windows 安装包继续标记为 beta。
