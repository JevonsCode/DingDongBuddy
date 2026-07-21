# DingDong 0.7.24

This release makes Recent Agents actionable: the compact Dynamic view keeps the
latest six items, the full history is one click away, and supported Agent items
can reopen their source conversation.

## Recent Agent navigation

- Shows at most six Recent Agent items in Dynamic and adds a compact `More`
  action only when additional history exists.
- Opens Resource Manager directly at Recent Agents from `More`.
- Makes resumable items clickable in both Dynamic and Resource Manager.
- Reopens exact Codex threads and Claude Code, Gemini, and Kiro CLI sessions.
- Opens exact Cursor background-agent conversations; local Cursor sessions fall
  back to reopening their recorded workspace.
- Uses an allow-listed native launcher and structured arguments so notification
  content cannot execute arbitrary commands.

## Kiro support

- Adds Kiro to the default Agent integrations.
- Synchronizes MCP configuration to `~/.kiro/settings/mcp.json` and Skills to
  Kiro's global and project Skill directories.
- Extends the setup instructions with a Kiro Stop hook that records the session
  id and workspace required for resume.

## Release reliability

- Isolates the packaged MCP Stop-hook smoke test from the user's live DingDong
  data so local builds do not create non-resumable Recent Agent entries.
- Uses platform-native path construction in Kiro discovery tests so the Windows
  release pipeline validates the same locations without separator mismatches.

Intel macOS and Windows packages remain beta.

---

本版本让“最近 Agent”真正可操作：Dynamic 首页默认只保留最近六项，完整历史可以
一键进入，受支持的 Agent 记录还能直接回到来源会话。

## 最近 Agent 跳转

- Dynamic 最多展示六条最近 Agent；仅在还有更多记录时显示紧凑的“更多”入口。
- 点击“更多”后，资源管理器会直接打开“最近 Agent”。
- Dynamic 和资源管理器中的可恢复记录都可以点击。
- 支持精确打开 Codex 对话，以及恢复 Claude Code、Gemini、Kiro CLI 会话。
- Cursor 后台 Agent 可精确打开对应会话；本地 Cursor 会话无法精确定位时，会回退到
  打开记录的工作区。
- 使用白名单原生启动器和结构化参数，通知内容不能被当作任意命令执行。

## Kiro 支持

- 将 Kiro 加入默认 Agent 集成。
- 支持同步 MCP 配置到 `~/.kiro/settings/mcp.json`，并同步全局与项目 Skill。
- 安装说明新增 Kiro Stop Hook，用于记录恢复会话需要的 session id 和工作区。

## 发布可靠性

- 隔离内置 MCP 的 Stop Hook 冒烟测试与用户真实 DingDong 数据，避免本地构建生成
  无法恢复的“最近 Agent”记录。
- Kiro 发现测试改用平台原生路径拼接，Windows 发布流水线不会再因路径分隔符误报。

Intel macOS 和 Windows 安装包继续标记为 beta。
