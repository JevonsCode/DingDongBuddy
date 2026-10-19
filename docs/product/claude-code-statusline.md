# Claude Code 的 DingDong 状态栏

Claude Code 的 MCP Bridge 响应不再让模型在回答末尾写页脚，而是返回一个紧凑的 `statusLine` 回执（Prompt 列表、按 Skill id 和 MCP serverName 索引的徽标，以及是否显示 Token），由状态栏渲染。用户已有的 HUD 也不会自动显示 DingDong 资源。

DingDong MCP 可执行文件支持 `--claude-statusline`。它接收 Claude Code 状态栏 stdin JSON，根据 `session_id` 和 `transcript_path` 读取本机会话记录，不调用模型、不访问网络、不触发 Bridge、不增加资源使用计数。

- 只接受当前会话中匹配 `mcp__dingdong__dingdong_bridge` 调用的成功回执。
- 每个新用户任务清空旧资源；尚未加载时显示“本轮未加载”，Bridge 失败也不会沿用旧资源。
- 使用回执中的可配置符号；Skill 在当前会话里成功 `dingdong_load_skill` 后加 `*`，托管 MCP 在其任一工具返回结果（含错误结果）后加 `*`，均从记录中的 `tool_use` 被动识别，模型不再调用 `dingdong_confirm_mcp_use`。不会凭工具可见性生成 `*`。Bridge 返回 `{unchanged: true}` 且 `hash` 与上次回执一致时沿用上次回执。
- Prompt、Skill、MCP 分别使用暖橙、蓝、绿 ANSI 色。显示文本会移除外来终端控制字符。
- Token 是当前主会话记录中模型返回的累计输入、输出与缓存用量，相同响应的分段更新只取最新值；按输入、输出、命中缓存分别展示；输入包含缓存读写，缓存命中不重复相加。不是上下文窗口占用。此状态栏暂不合计子 Agent 的独立会话或 Jev 的独立调用。
- 仅在 Bridge 回执的 `statusLine.tokens` 为 true（用户开启了 Token 显示）时显示用量；不以字符长度估算。
- 明细缺失时回退原来的累计总 Token，不展示虚构的 0 或一排「—」。同一响应补齐明细后可恢复四项展示。
- 第四项「非缓存」= 输入 − 缓存命中 + 输出，包含缓存写入；只显示 Token 数量，忽略 stdin 的金额字段。缓存命中也可能折扣计费，因此此项不等于完整计费量。

用户可以把 `settings.json` 的 `statusLine.command` 指向安装包内 MCP：

```sh
'/Applications/DingDong DEV.app/Contents/MacOS/dingdong-mcp' --claude-statusline
```

若已有状态栏，把原 `statusLine` JSON 对象原样保存在用户自己的文件，再加 `--previous-statusline-file '/absolute/path/previous.json'`。DingDong 会把同一 stdin 传给原命令，保留输出，并追加自己的行。原命令最多等待 3 秒；失败时仍显示 DingDong。不要把整个 Claude 设置文件当作 previous 文件，也不要把本命令递归写入该文件。

本地配置时应先备份原 `settings.json`，只替换 `statusLine.command`，保留其余字段和 Hook；写入前复核文件没有并发变化。恢复时只还原原 `statusLine` 对象，不覆盖此后修改的其他设置。

Claude Code 支持多行与 ANSI 状态栏，配置变化会自动重载，参见[官方状态栏文档](https://code.claude.com/docs/en/statusline)。

托管 MCP 的调用次数同样被动记账：Claude Code 的 Stop Hook（`--notify-stop --source "Claude Code"`）把 `transcript_path` 交给 DingDong，DingDong 只读取 `~/.claude/projects` 下该记录最近一个用户回合里的 `mcp__dingdong-…__*` 调用，按调用 id 去重后累加对应 MCP 资源的调用计数。没有配置 Stop Hook 时不记录。
