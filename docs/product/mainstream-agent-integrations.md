# 其他 Agent 的提醒和会话

Agent Adapter 负责资源路径，完成提醒还需要相应客户端的 Hook 或扩展。下面的文件
由用户选择接入，DingDong 不会在检测到目录后自动修改现有客户端配置。接入后应在
该客户端完成一轮实际对话，检查提醒来源和返回目标。

## Pi 和 OpenCode

应用包含两个可选扩展：

- `Assets/Agent Integrations/pi.js`：安装到 Pi 的 `~/.pi/agent/extensions/`。
  适用于支持 `agent_settled` 的 Pi；如果使用只支持 `agent_end` 的上游版本，
  启动 Pi 前设置 `DINGDONG_PI_END_EVENT=agent_end`。扩展在结束后发送 Pi
  会话 ID 和工作目录，启动或恢复时核销该会话的提醒。临时会话不提供跳转。
- `Assets/Agent Integrations/opencode.js`：安装到 OpenCode 的
  `~/.config/opencode/plugins/`。扩展忽略能确认的子会话，使用 `session.idle`
  发送完成提醒。这个事件不区分桌面和命令行来源，因此提醒显示 `OpenCode`，
  不提供猜测性的终端跳转。

macOS 应用包内的扩展文件位于
`DingDong.app/Contents/Frameworks/App.framework/Versions/A/Resources/flutter_assets/Assets/Agent%20Integrations/`；
这里的 `%20` 是包内目录名的一部分。也可以从仓库的 `Assets/Agent Integrations/`
取得对应文件。

macOS 默认调用 `/Applications/DingDong.app/Contents/MacOS/dingdong-mcp`；
安装在其他位置或其他平台时，在启动客户端的环境中设置
`DINGDONG_MCP_EXECUTABLE` 为本机 DingDong MCP 可执行文件的绝对路径。
不要覆盖同名的已有扩展。客户端需要重新加载扩展后才会产生提醒。

Pi 原生不提供 MCP，因此扩展只处理提醒，不代表 DingDong Bridge 已接入 Pi。
OpenCode 的 Adapter 可以同步 MCP，但首次接入 DingDong 本身仍需要在 OpenCode
中配置名为 `dingdong` 的 MCP 并验证 Bridge。

## GitHub Copilot CLI

在用户级 Hook 目录中新建独立 JSON 文件，例如 `~/.copilot/hooks/dingdong.json`；
如果同名文件已存在，应先读取并保留其中内容。macOS 的例子如下：

```json
{
  "version": 1,
  "hooks": {
    "agentStop": [
      {
        "type": "command",
        "exec": "/Applications/DingDong.app/Contents/MacOS/dingdong-mcp",
        "args": ["--notify-stop", "--source", "GitHub Copilot CLI"],
        "timeoutSec": 5
      }
    ]
  }
}
```

其他平台应替换 `exec` 为实际可执行文件的绝对路径。Copilot 的 Hook 可能受工作区
信任、权限和沙箱限制；这些条件及 Hook 本身需要在实际客户端中验收。

## Antigravity

Antigravity App、IDE 与 CLI 共享 `~/.gemini/config/hooks.json`。将以下独立条目
合并到已有根对象，可在 `fullyIdle` 时发送提醒；不要覆盖其他 Hook：

```json
{
  "dingdong": {
    "Stop": [
      {
        "type": "command",
        "command": "'/Applications/DingDong.app/Contents/MacOS/dingdong-mcp' --notify-stop --source Antigravity --antigravity-hook",
        "timeout": 5
      }
    ]
  }
}
```

命令应按安装平台和实际路径调整。DingDong 只有在 Hook 提供的 transcript 路径与
当前用户目录、客户端类型和会话 UUID 的官方位置完全匹配时，才区分 App、IDE 和
CLI；否则保留通用 `Antigravity` 来源。只有 CLI 且工作目录唯一时提供 CLI 会话
恢复；App、IDE 的原会话跳转尚未接入。支持多工作区时不会猜测工作目录。

三个客户端也共用 MCP 配置，因此只有允许通用 Antigravity、App、IDE 和 CLI
所有来源的 MCP 才会同步到该文件；仅允许部分来源的 MCP 不会写入共享配置。

参考：[Pi 扩展](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/docs/extensions.md)、
[OpenCode 插件](https://opencode.ai/docs/plugins/)、
[Copilot Hook](https://docs.github.com/en/copilot/reference/hooks-reference)、
[Antigravity Hook](https://antigravity.google/docs/hooks)。
