# DingDong 1.4.4

DingDong 1.4.4 makes the resource receipt at the end of supported Agent replies
truthful about MCP use and helps existing Agent connections pick up the new
protocol.

## Know when an MCP was actually called

- An MCP now receives `*` only after one of its configured tools reaches a
  terminal result. Availability and tool discovery alone never add the marker.
- The MCP marker means **called**, not necessarily **succeeded**. Error results
  still prove that a real call took place.
- DingDong validates each call receipt against the managed resource ID, server
  identity, Codex tool prefix, enabled state, and current project scope before
  replacing the matching footer item.
- Prompt items stay unmarked. DingDong can observe delivery, but it cannot
  reliably prove whether a model followed a Prompt semantically.

## Refresh existing Agent connections safely

- Existing installations that have already opened Agent access now show a
  revision-aware update badge and setup notice when the connection instructions
  change.
- The Agent setup panel can copy the current instructions and mark that revision
  as updated; brand-new installations start at the latest revision without a
  false warning.
- The built-in DingDong configuration Skill, managed Agent bootstrap, API
  reference, website, and bilingual READMEs now describe the same Skill-load and
  MCP-call evidence rules.

Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.4.4 让支持的 Agent 在回复末尾留下的资源小票可以真实反映 MCP 调用，
并帮助已有 Agent 连接及时拿到新协议。

## MCP 真实调用后才加星号

- MCP 只有在其已配置工具拿到最终结果后才会带 `*`；仅仅可用、列出工具或发现工具
  都不会加星号。
- MCP 的 `*` 表示“调用过”，不表示“调用成功”；错误结果仍然能证明真实调用发生过。
- DingDong 会按托管资源 ID、Server 身份、Codex 工具前缀、启用状态与当前项目作用域
  校验调用回执，再替换资源小票中的对应条目。
- Prompt 继续不加 `*`：系统可以观察到送达，却无法可靠证明模型在语义上真正遵循。

## 安全刷新已有 Agent 接入

- 已经打开过 Agent 接入的旧安装会在接入协议升级时看到版本化更新角标与提示；全新
  安装直接采用最新版，不会产生误提醒。
- Agent 接入面板可复制最新指令并标记该版本已更新。
- 内置 DingDong 配置 Skill、托管 Agent 引导、API 文档、官网与中英文 README 统一
  使用相同的 Skill 加载和 MCP 调用证据规则。

Intel macOS 与 Windows 安装包继续标记为 beta。
