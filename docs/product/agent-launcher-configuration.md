# Agent 对话启动器配置

这份文档同时面向用户和代为配置的 AI Agent。它说明 DingDong 在用户点击完成提醒或
“最近 Agent”记录时，如何选择终端并恢复 CLI Agent 对话。

## 配置文件

DingDong 读取用户级 `agent-launchers.json`：

| 平台 | 路径 |
|---|---|
| macOS | `~/Library/Application Support/DingDong/agent-launchers.json` |
| Windows | `%APPDATA%\DingDong\agent-launchers.json` |
| Linux | `~/.local/share/DingDong/agent-launchers.json` |

文件不存在时，DingDong 保持兼容行为：macOS 使用 Terminal.app 并打开新窗口。
DingDong 每次打开对话前都会重新读取文件，因此修改后不需要重启应用。

当前版本只使用这份配置选择 macOS CLI Agent 的终端。Windows 仍使用 Windows
Terminal (`wt.exe`)；Codex 使用 `codex://` 深链接，Cursor 使用自身深链接或桌面
应用，这两者不会读取终端字段。

JSON Schema 位于
[`docs/schemas/agent-launchers.schema.json`](../schemas/agent-launchers.schema.json)。

DingDong 自带的 `dingdong-configure` Skill 也内嵌了路径、字段和值域及安全修改流程。
因此用户可以直接让已安装该 Skill 的本机 AI Agent 修改配置；Agent 不需要访问本仓库
才能完成操作。

## 给 Claude Code 使用 iTerm

下面是最小有效配置：

```json
{
  "schemaVersion": 1,
  "agents": {
    "claude-code": {
      "macosTerminal": "iterm",
      "itermOpenMode": "new-tab"
    }
  }
}
```

保存后，从 DingDong 点击一条带对话目标的 Claude Code 提醒。DingDong 会在当前
iTerm 窗口中新建标签页；如果 iTerm 还没有窗口，则创建新窗口。启动命令仍由
DingDong 的受信任适配器生成：

```text
cd -- <workspace> && exec claude --resume <conversation-id>
```

配置不能提供或覆盖任意 Shell 命令。

## 完整结构

```json
{
  "schemaVersion": 1,
  "defaults": {
    "macosTerminal": "terminal",
    "itermOpenMode": "new-window"
  },
  "agents": {
    "claude-code": {
      "macosTerminal": "iterm",
      "itermOpenMode": "new-tab"
    },
    "gemini-cli": {
      "macosTerminal": "iterm"
    },
    "kiro": {
      "macosTerminal": "terminal"
    }
  }
}
```

`defaults` 是全局默认值，`agents` 中的同名字段覆盖默认值。所有字段都是可选的，
但根对象必须包含 `"schemaVersion": 1`。

### 字段

| 字段 | 合法值 | 含义 |
|---|---|---|
| `schemaVersion` | `1` | 配置格式版本 |
| `defaults.macosTerminal` | `terminal`, `iterm` | macOS CLI Agent 的默认终端 |
| `defaults.itermOpenMode` | `new-window`, `new-tab` | 使用 iTerm 时的默认打开方式 |
| `agents.<client>` | 对象 | 某个 Agent 的覆盖设置 |
| `macosTerminal` | `terminal`, `iterm` | 覆盖该 Agent 使用的终端 |
| `itermOpenMode` | `new-window`, `new-tab` | 覆盖该 Agent 的 iTerm 打开方式 |

支持的 Agent 键为：

- `codex`
- `claude-code`
- `cursor`
- `gemini-cli`
- `kiro`

其中终端配置当前只对 `claude-code`、`gemini-cli` 和 CLI 模式的 `kiro` 生效。

## AI Agent 修改协议

收到“让 DingDong 用 iTerm 打开 Claude Code 对话”等请求时，AI Agent 应按下面的
顺序操作：

1. 确认当前会话运行在安装 DingDong 的本机。远程或云端 Agent 不应修改本机路径。
2. 根据操作系统解析上面的用户级配置路径，不要修改仓库中的 Schema 或文档示例来
   冒充完成配置。
3. 如果文件存在，先读取完整 JSON；如果不存在，从 `{"schemaVersion": 1}` 开始。
4. 如果现有文件不是合法 JSON、不是 schema v1，或含有不支持的字段和值，停止并说明
   冲突，不要擅自覆盖、删除未知字段或迁移。只有用户在了解将丢失哪些内容后明确授权，
   才能重建或移除字段。
5. 保留所有无关字段和其他 Agent 设置，只修改用户明确要求的最小字段。
6. 仅使用本文列出的 Agent 键、字段和枚举值。不要写入命令、脚本、Token、环境变量
   或从 Hook 输入取得的任意可执行内容。
7. 把新内容写入同目录临时文件，确认是合法 JSON；替换前重新读取目标，若检查后已发生
   并发变化则停止。尽量保留原文件权限，再原子替换目标文件。不要用不完整内容覆盖现有
   配置。
8. 重新读取目标文件，确认改动已经落盘。
9. 告知用户实际修改的文件、最终终端选择和 iTerm 打开方式。请用户从 DingDong 点击
   一条对应 Agent 提醒完成真实验证。

修改 Claude Code 的示例目标状态：

```json
{
  "schemaVersion": 1,
  "agents": {
    "claude-code": {
      "macosTerminal": "iterm",
      "itermOpenMode": "new-tab"
    }
  }
}
```

AI Agent 不应：

- 覆盖或删除其他 Agent 的配置。
- 把 `macosTerminal` 写成应用路径、Bundle ID 或任意命令。
- 修改 Claude Code 的会话 ID、工作区或恢复命令。
- 因为 iTerm 不存在就静默改回 Terminal.app。
- 声称已经验证，除非实际从 DingDong 打开过对应提醒。

## 错误与回退

- 文件不存在：使用内置默认值。
- JSON 无效、包含未知字段、未知 Agent 键或非法枚举值：本次打开失败，不静默忽略
  配置错误。
- 选择 `iterm` 但本机没有安装 iTerm：本次打开失败，不自动改用其他终端。
- `itermOpenMode` 只在 `macosTerminal` 为 `iterm` 时使用。

当前配置负责“在哪个终端中恢复对话”，不会定位并聚焦原来已经存在的 iTerm 标签页。
后续若要支持“回到原标签页”，需要完成 Hook 额外记录受信任的终端会话标识。
