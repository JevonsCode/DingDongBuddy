# DingDong 1.4.3

DingDong 1.4.3 makes connected Agent alerts calmer by default and makes the
resource trail at the end of supported Agent replies easier to understand and
personalize.

## Keep background workers quiet by default

- A new **Subagent notifications** switch is off by default. Positively
  identified Codex subagents no longer create a desktop alert, DingDong sound,
  activity entry, unread state, or linked-device update unless you opt in.
- Subagent task starts are filtered through the same preference, and a filtered
  completion cleans up only its exact running conversation without touching a
  main-thread task.
- Main Agent conversations continue normally. If Codex metadata is unavailable,
  DingDong fails open instead of risking a missed main-thread reminder.
- Exact `thread/read` classification finds background workers that Codex omits
  from the default thread list and caches stable thread identity after a
  successful read.

## See the resource receipt after a reply

- Supported Agents can append a compact DingDong line showing the Prompts
  active for the task, matching Skills, and MCP connections that were available.
- A `*` appears only after the full Skill was loaded in that task. An MCP name
  means the connection was available, not that a tool was necessarily called.
- Prompt, Skill, and MCP symbols can now be customized independently in
  **Settings → Agent reply footer**, with a live preview, persistent values, and
  one-click reset.
- The website and bilingual READMEs now describe DingDong as one place for
  connected Agent alerts, with a desktop sound chosen by the user and a clear
  resource receipt at the end of supported replies.

Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.4.3 默认让接入 Agent 的提醒更安静，也让支持的 Agent 在回复末尾留下的
资源轨迹更容易看懂和自定义。

## 子智能体默认安静工作

- 新增“**子智能体提醒**”开关，默认关闭。只有明确识别为 Codex 子智能体的事件才会
  被过滤；开启前，它们不会产生桌面提醒、叮咚声、动态记录、未读状态或关联设备同步。
- 子智能体任务开始也遵循同一设置；完成事件被过滤时，只会清理精确匹配的运行会话，
  不会误伤主智能体任务。
- 主智能体对话继续正常提醒。Codex 元数据不可用时，DingDong 会放行事件，避免漏掉
  主线程的重要结果。
- 使用精确的 `thread/read` 识别默认线程列表里看不到的后台 worker；成功读取后会缓存
  稳定的线程身份。

## 回复末尾看懂这轮用了什么资源

- 支持的 Agent 可以在完整回复末尾附上一行 DingDong，展示本轮生效的 Prompt、匹配到
  的 Skill 和当时可用的 MCP 连接。
- 只有本轮完整加载过的 Skill 才带 `*`；MCP 名称表示连接可用，不代表工具一定实际
  调用过。
- 可在“**设置 → Agent 回复尾部**”中分别自定义 Prompt、Skill 和 MCP 符号，支持实时
  预览、持久保存和一键恢复默认值。
- 官网与中英文 README 也更新为“接入的 Agent 提醒一处收好，桌面叮咚声由你挑”，并
  补充回复末尾资源小票的真实语义。

Intel macOS 与 Windows 安装包继续标记为 beta。
