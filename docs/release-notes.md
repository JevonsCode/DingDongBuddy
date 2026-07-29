# DingDong 0.9.1

This release moves managed Agent resources to a dynamic, scope-checked delivery
model, preserves clipboard formatting, and adds more control over the macOS
menu-bar experience.

## Dynamic Prompt and Skill delivery

- Keeps only a persistent DingDong Bridge bootstrap in supported native Agent
  instruction files instead of copying Prompt bodies into them.
- Treats every successful Bridge call as the authoritative Prompt snapshot for
  the current task and returns the complete catalog of every valid, enabled,
  scope-matched Skill as ID, name, and description.
- Adds dedicated Skill loading and supporting-file APIs. Full `SKILL.md`
  content is fetched only after an Agent matches a returned description, and
  referenced package files are read on demand.
- Re-checks enabled state and project scope on every full Skill, package-file,
  and full resource read so an old ID or name cannot bypass current policy.
- Rejects ambiguous Skill names unless the Agent supplies a catalog ID, blocks
  package paths that leave the Skill root, and limits individual file reads to
  5 MiB.

## Strict project scope and Skill migration

- Requires strict project Skills to use exact, existing absolute project paths,
  resolves symbolic links, and keeps a canonical persisted path guard.
- Updates trigger groups and their affected Skills as one coordinated change,
  rolls both stores back after a failure, and disables resources that lose
  their final valid scope.
- Stops deploying DingDong-managed Skills into native Agent Skill directories.
  Synchronization now removes only legacy copies carrying DingDong's ownership
  marker and preserves independently installed native Skills.
- Reports independent native Skill and duplicate managed-name collisions as
  warnings; Agents can use catalog IDs to select duplicate names safely.
- Stages local Skill packages inside the MCP process before loopback import,
  improving access to macOS protected folders, and recognizes Windows drive
  paths before URI parsing.

## Clipboard fidelity and paste controls

- Captures and persists original text plus HTML and RTF representations, with a
  compatible SQLite migration for existing clipboard history.
- Restores formatted text by default and adds **Paste as Plain Text** to
  textual clipboard-row context menus.
- Adds `Option-Command-1…9` plain-text quick paste on macOS, including matching
  shortcut hints, while preserving the existing original-format shortcuts.
- Restores a single image with bitmap and source-file representations together
  so image editors and Finder-style file paste both remain compatible.

## macOS Dock and menu-bar notifications

- Adds a persistent **Hide Dock icon** setting and the same action to DingDong's
  Dock menu; main and auxiliary windows follow the resulting taskbar policy.
- Adds orange, pink, blue, green, and purple menu-bar unread colors with live
  refresh. Release builds default to orange and development builds to pink.
- Shows the colored capsule only while notifications are unread, avoiding a
  permanent development label or stale background.

Intel macOS and Windows packages remain beta.

---

本版本将托管的 Agent 资源改为动态、按作用域校验的交付方式，同时保留剪贴板格式，并
增强 macOS 菜单栏体验的可配置性。

## Prompt 与 Skill 动态交付

- 支持的 Agent 原生指令文件只保留固定 DingDong Bridge 引导，不再写入 Prompt 正文。
- 每次 Bridge 成功响应都是当前任务的权威 Prompt 快照，并返回所有有效、已启用且
  作用域匹配 Skill 的完整目录；每项只包含 ID、名称与描述。
- 新增专用 Skill 加载和引用文件读取接口。Agent 只有在已返回描述匹配任务后才获取
  完整 `SKILL.md`，并按需读取它引用的 Package 文件。
- 每次读取完整 Skill、Package 文件或完整资源时都会重新校验启用状态和项目作用域，
  旧 ID 或名称不能绕过当前策略。
- 同名 Skill 必须提供目录 ID 才能消歧；Package 文件不能逃出 Skill 根目录，单个
  文件读取上限为 5 MiB。

## 严格项目范围与 Skill 迁移

- 严格项目 Skill 只接受真实存在的绝对项目路径；路径会解析符号链接，并保存规范化
  结果作为额外的闭锁校验。
- Trigger Group 与受影响 Skill 会作为一组协调更新；失败时两边都会回滚，失去最后
  一个有效范围的资源会自动停用。
- DingDong 不再把托管 Skill 部署到 Agent 原生 Skill 目录；同步只清理由 DingDong
  所有权标记识别的旧版镜像，并保留用户独立安装的原生 Skill。
- 独立原生 Skill 和托管 Skill 重名会作为警告展示；Agent 可以用目录 ID 安全选择
  同名资源。
- MCP 进程会先暂存本地 Skill Package 再交给回环服务导入，改善 macOS 受保护目录
  访问；Windows 盘符路径也会在 URI 解析前正确识别。

## 剪贴板格式与粘贴控制

- 采集并持久保存原始文本、HTML 和 RTF，并为现有剪贴板数据库提供兼容迁移。
- 默认恢复原格式；文本类记录的右键菜单新增“粘贴为纯文本”。
- macOS 新增 `Option-Command-1…9` 纯文本快速粘贴及对应提示，原格式快捷键保持不变。
- 单张图片会同时写入位图和源文件表示，兼容图片编辑器与 Finder 风格文件粘贴。

## macOS Dock 与菜单栏提醒

- 新增持久化“隐藏 Dock 图标”设置，Dock 菜单也提供同一操作；主窗口和辅助窗口统一
  遵循对应的任务栏策略。
- 菜单栏未读提示新增橙、粉、蓝、绿、紫五种颜色并即时刷新；正式版默认橙色，开发版
  默认粉色。
- 只有存在未读提醒时才显示彩色胶囊，避免开发标记常驻或背景残留。

Intel macOS 与 Windows 安装包继续标记为 beta。
