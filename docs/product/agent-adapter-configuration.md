# Agent Adapter 配置

Agent Adapter 描述 DingDong 如何识别一个本机 Agent、把 MCP 与固定的 Prompt
Bridge 引导写到哪里，以及到哪些原生 Skill 目录清理旧版 DingDong 镜像并检查独立
Skill 冲突。DingDong 管理的 Skill 已改为通过 Bridge 动态发现和按需加载，不再部署到
这些目录。Adapter 只登记受支持的文件位置和格式，不允许提供任意命令、Hook、Token
或启动脚本。

用户可以在 **资源管理 → Agent 接入** 查看所有内置和自定义 Adapter。页面默认展示
可验证的配置证据：YAML 是否有效、检测目录是否存在，以及 MCP、Prompt、Skill 路径
是否声明。目录存在和路径已声明都不能证明 MCP、Hook、Bridge 或完成回调已连接。
YAML 编辑器及当前版本与前两个版本的比较收在 **高级配置**。外部 AI Agent 修改同一份
用户 YAML 后，页面会自动刷新；如果页面中还有未保存内容，会先提示冲突，不会静默覆盖
编辑器。

对话从 Terminal.app 还是 iTerm 打开属于另一份
[`agent-launchers.json`](agent-launcher-configuration.md) 配置。

## 用户配置目录

| 平台 | 目录 |
|---|---|
| macOS | `~/Library/Application Support/DingDong/Agent Adapters` |
| Windows | `%APPDATA%\DingDong\Agent Adapters` |
| Linux | `~/.local/share/DingDong/Agent Adapters` |

每个 `.yaml` 或 `.yml` 文件定义一个 Adapter，建议文件名与 `id` 一致。DingDong 自带
Codex、Claude Code、Cursor、Gemini CLI 和 Kiro 的内置定义：

- 没有同 ID 用户文件时，使用内置定义。
- 在资源管理里保存内置定义时，会在上述目录创建同 ID 用户覆盖文件。
- 同 ID 用户文件完整替代内置定义，不做字段级合并。
- 没有内置定义的 ID 是自定义 Adapter，可以在资源管理中删除。

机器可读的结构说明位于
[`docs/schemas/agent-adapter.schema.json`](../schemas/agent-adapter.schema.json)。运行时仍
会执行更严格的平台路径和目录穿越校验。

## YAML 结构

```yaml
schemaVersion: 1
id: new-agent
displayName: New Agent

detect:
  directory: ~/.new-agent

skills:
  global: ~/.new-agent/skills
  project: .new-agent/skills

mcp:
  file: ~/.new-agent/mcp.json
  format: mcpServers-json

prompt:
  file: ~/.new-agent/AGENTS.md
  includeBridgeRoutingInstructions: true
```

### 字段

| 字段 | 必填 | 含义 |
|---|---|---|
| `schemaVersion` | 是 | 当前只接受整数 `1` |
| `id` | 是 | 1–64 位小写字母、数字和单连字符 |
| `displayName` | 是 | 资源管理和问题中心显示的客户端名称 |
| `detect.directory` | 是 | 目录存在时，认为该 Agent 已安装并参与同步 |
| `skills.global` | 否 | 用户级原生 Skill 目录，仅用于旧版托管镜像清理和独立 Skill 冲突检查；与 `skills.project` 成对出现 |
| `skills.project` | 否 | 相对于项目根目录的原生 Skill 目录，仅用于旧版托管镜像清理和冲突检查 |
| `mcp.file` | 否 | Agent 的用户级 MCP 配置文件；与 `mcp.format` 成对出现 |
| `mcp.format` | 否 | MCP 配置格式 |
| `prompt.file` | 否 | DingDong 写入固定 Prompt/Skill Bridge 引导的原生指令文件 |
| `prompt.includeBridgeRoutingInstructions` | 否 | 是否在托管区块加入 Bridge 引导，默认 `true` |

支持的 MCP 格式：

- `codex-toml`
- `claude-json`
- `cursor-json`
- `gemini-json`
- `kiro-json`
- `mcpServers-json`：通用 JSON，根对象使用 `mcpServers`

`detect.directory`、`skills.global`、`mcp.file` 和 `prompt.file` 必须使用 `~`、
`~/...` 或用户主目录内的绝对路径；DingDong 会解析已有符号链接，真实目标也不能
越出用户主目录。`skills.project` 必须使用 `/` 分隔的安全相对目录，不能包含
反斜杠、`..` 或指向磁盘根目录。

配置采用严格校验：未知字段、重复 ID、无效 YAML、不支持的格式或不安全路径都会在
资源管理中显示为错误。多个已安装 Adapter 若把同一 MCP 或 Prompt 文件声明成相互
冲突的格式/路由设置，也会阻止同步。无效用户 Adapter 会保留原文供修复，但不会进入
同步器，并会阻止本次 Agent 资源同步，避免部分配置悄悄生效；DingDong 和资源管理
仍可打开供用户修复。

## 版本历史

DingDong 为每个 ID 自动保存最多三个快照：当前版本、上一个版本、上两个版本。快照
来自资源管理保存和外部文件变更；相同内容不会重复记录。

历史目录是应用内部数据：

| 平台 | 目录 |
|---|---|
| macOS | `~/Library/Application Support/DingDong/Agent Adapter History` |
| Windows | `%APPDATA%\DingDong\Agent Adapter History` |
| Linux | `~/.local/share/DingDong/Agent Adapter History` |

不要直接编辑、复制回填或删除历史 JSON 来修改 Adapter。要恢复内置定义，使用资源管理
里的“恢复内置”；要恢复旧内容，在 Diff 中查看后，把需要的 YAML 保存为新的当前版本。

## AI Agent 修改协议

当用户明确要求新增或修改 Agent 接入时，本机 AI Agent 应：

1. 确认会话运行在安装 DingDong 的同一台电脑上。
2. 按操作系统解析用户配置目录，不修改仓库示例或应用包内置资源来冒充完成。
3. 修改已有 Adapter 前，读取完整用户覆盖文件。若不存在同 ID 文件，创建一份完整
   Adapter；不要假设它会和内置定义字段级合并。
4. 保留未被用户要求修改的字段，并保持原 `id`。要换 ID，应新建另一个文件。
5. 遇到未知字段或无效现有配置时停止并报告；只有用户在了解影响后明确要求，才可删除
   未知字段或重建文件。不要自行猜测迁移。
6. 只写本文列出的声明式字段。不要加入命令、Shell、Hook、Token、环境变量、工作区
   绝对路径或会话 ID。解析已有符号链接后再次确认所有用户路径仍在主目录内。
7. 先在同目录写临时文件，验证 YAML 和字段值；替换前重新读取目标，确认检查后没有
   并发变化，并尽量保留原文件权限。再原子替换并重新读取确认。
8. 不要直接编辑 `Agent Adapter History`。DingDong 会在观察到用户文件变更时记录
   快照。
9. 告知用户实际文件、改动字段，以及该 Agent 的 `detect.directory` 当前是否存在。
   保持 **资源管理 → Agent 接入** 打开时，DingDong 会重新校验并同步当前资源；否则
   重新打开资源管理或重启 DingDong 后再验证 Skill、Prompt 和 MCP 的真实目标。

删除自定义 Adapter 或移除内置 Adapter 的用户覆盖属于破坏性操作，应先获得用户明确
同意。外部 Agent 不应声称同步已经成功，除非随后触发并验证了对应资源保存或同步。
