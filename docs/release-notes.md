# DingDong 1.1.0

DingDong 1.1.0 improves Agent activity recovery and makes Codex background
tasks clearer before they are opened.

## Agent activity

- Codex conversations are preflighted before the activity list offers an open
  action, avoiding stale links to unavailable threads.
- Recognized Codex background subagents show a compact `sub` marker and cannot
  be opened as ordinary user conversations.
- Unknown or no-longer-resolvable Agent targets show a non-interactive unknown
  icon instead of a misleading open action.
- Recent activity and the Resource Manager share the same target resolution
  state, including subagent and unknown-target indicators.

## Clipboard groups and recovery

- Empty groups preserved by the order file remain visible, so groups such as
  PageID can be recovered and used for explicit reassignment.
- Group matching is normalized consistently without inferring archive scope
  from text, titles, or tags.

## Agent integration

- Codex preflight and native launch behavior now share cached, batch-resolved
  conversation state.
- The MCP server and completion hook advertise the 1.1.0 application version.

Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.1.0 改进了 Agent 动态恢复，并在打开前明确区分 Codex 后台任务。

## Agent 动态

- 动态列表会在展示打开入口前预检查 Codex 对话，避免进入已经失效的聊天链接。
- 识别出的 Codex 后台 subagent 显示紧凑的 `sub` 标志，不再作为普通用户对话打开。
- 未知或已经无法解析的 Agent 目标显示非交互的未知图标，不再误显示打开入口。
- 最近动态和资源管理器共用目标解析状态，包括 subagent 与未知目标标志。

## 剪贴板分组与恢复

- 顺序文件中保留的空分组会继续展示，PageID 等分组可以恢复并用于显式归档。
- 分组匹配统一规范化，不会根据文本、标题或标签推断归档范围。

## Agent 集成

- Codex 预检查和原生打开逻辑共用缓存的批量会话状态。
- MCP 服务和完成 Hook 对外声明 1.1.0 版本。

Intel macOS 与 Windows 安装包继续标记为 beta。
