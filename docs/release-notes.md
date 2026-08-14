# DingDong 1.4.5

DingDong 1.4.5 gives users finer control over Agent notifications, keeps the
installed PWA and browser surfaces from competing for background notifications,
and makes desktop update discovery more reliable.

## Put Agent notifications under user control

- Settings now independently control Agent completion notifications, requests
  for user attention, and subagent activity notifications.
- Agent updates that need confirmation, a choice, or takeover are labeled as
  waiting for input in the activity feed and device notifications.

## Keep the installed PWA and browser H5 separate

- When the PWA is installed, the browser page becomes a focused launcher with
  one action to open the DingDong app; the browser surface no longer receives
  Agent notifications.
- PWA notification permission checks stay in a loading state until the
  asynchronous browser permission result settles, avoiding a transient false
  “not allowed” state during startup.

## Keep desktop release status fresh

- DingDong still checks for updates at startup and now retries in the
  background every seven hours while it is running, keeping the version dot
  synchronized with the published release metadata.

Intel macOS and Windows packages remain marked as beta.

---

# DingDong 1.4.5

DingDong 1.4.5 让 Agent 通知更可控，也让已安装的 PWA 与浏览器页面各司其职，
同时让桌面端的版本更新发现更加可靠。

## Agent 通知交给用户选择

- 设置中可以分别控制 Agent 完成提醒、需要用户处理的提醒，以及子 Agent
  活动提醒。
- 需要确认、选择或接管的 Agent 更新会在活动记录和设备通知中标记为“需要你处理”。

## 已安装 PWA 后保持浏览器页面安静

- 安装 PWA 后，浏览器页面只保留一个唤起 DingDong App 的按钮；浏览器页面不再
  接收 Agent 通知。
- PWA 启动时会先显示“检查中”，等异步权限查询稳定后再显示真实权限状态，
  不会再短暂误显示“没有权限”。

## 让桌面版本状态持续更新

- 启动时仍会立即检查更新，并在运行期间每七小时后台重试一次，让版本号旁的
  更新小圆点及时反映线上发布的版本元数据。

Intel macOS 与 Windows 安装包继续标记为 beta。

---

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
