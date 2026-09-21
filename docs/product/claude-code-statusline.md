# Claude Code 的 DingDong 状态栏

Claude Code 的 MCP Bridge 响应会包含 `conversation` 页脚，但 MCP 工具返回并不保证模型会把页脚写进最终回答。用户已有的 HUD 也不会自动显示 DingDong 资源。

DingDong MCP 可执行文件支持 `--claude-statusline`。它接收 Claude Code 状态栏 stdin JSON，根据 `session_id` 和 `transcript_path` 读取本机会话记录，不调用模型、不访问网络、不触发 Bridge、不增加资源使用计数。

- 只接受当前会话中匹配 `mcp__dingdong__dingdong_bridge` 调用的成功回执。
- 每个新用户任务清空旧资源；尚未加载时显示“本轮未加载”，Bridge 失败也不会沿用旧资源。
- 使用回执中的可配置符号和 `lineToken`；仅成功 Skill 加载/MCP 确认回执可替换同一 `mergeKey`。不会凭工具可见性生成 `*`。
- Prompt、Skill、MCP 分别使用暖橙、蓝、绿 ANSI 色。显示文本会移除外来终端控制字符。
- Token 是当前主会话记录中模型返回的累计输入、输出与缓存用量，相同响应的分段更新只取最新值；不是上下文窗口占用，也不是费用。此状态栏暂不合计子 Agent 的独立会话或 Jev 的独立调用。
- 仅在 Bridge 回执携带 Token 用量时显示用量；不以字符长度估算。

用户可以把 `settings.json` 的 `statusLine.command` 指向安装包内 MCP：

```sh
'/Applications/DingDong DEV.app/Contents/MacOS/dingdong-mcp' --claude-statusline
```

若已有状态栏，把原 `statusLine` JSON 对象原样保存在用户自己的文件，再加 `--previous-statusline-file '/absolute/path/previous.json'`。DingDong 会把同一 stdin 传给原命令，保留输出，并追加自己的行。原命令最多等待 3 秒；失败时仍显示 DingDong。不要把整个 Claude 设置文件当作 previous 文件，也不要把本命令递归写入该文件。

本地配置时应先备份原 `settings.json`，只替换 `statusLine.command`，保留其余字段和 Hook；写入前复核文件没有并发变化。恢复时只还原原 `statusLine` 对象，不覆盖此后修改的其他设置。

Claude Code 支持多行与 ANSI 状态栏，配置变化会自动重载，参见[官方状态栏文档](https://code.claude.com/docs/en/statusline)。
