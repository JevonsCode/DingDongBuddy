# DingDong 1.3.7

DingDong 1.3.7 follows observed Agent work from its real start through
completion, keeps that lifecycle visible on paired phones, and gives Prompt,
Skill, and MCP usage one consistent conversation footer.

## Real-time Agent activity on paired phones

- Agent Bridge now reports each observed task start with its source, task,
  workspace, repository, conversation, and actual start time. A matching
  completion retains the task, full detail, start, end, and duration instead
  of reconstructing them from the notification time.
- Every connected phone receives an authoritative snapshot for its selected
  computer: currently running tasks, bounded completion history, and honest
  unread state. Reconnects restore the snapshot without reviving stale runs
  after the desktop app restarts.
- The mobile Agent view separates running work from completion history, shows
  start/end/duration timelines, and keeps each paired computer isolated.
  Notification taps open the Agent tab in an already-running PWA without a
  reload, and both notification icon surfaces use DingDong artwork.
- A completion remains unread until the Dynamic workspace is actually visible
  and has rendered it; a hidden desktop window no longer acknowledges the item.

## One conversation resource footer

- Agent Bridge exposes active Prompts, candidate Skills, and available MCPs as
  one conversation capsule with stable merge keys and exact replacement
  semantics, preventing duplicate or stale resource labels across turns.
- Rich hosts can render the self-contained MCP Apps footer. ANSI-capable and
  plain Markdown hosts receive equivalent fallbacks from the same canonical
  payload, with bounded and safely escaped text.
- A Skill gets the `*` used marker only after `dingdong_load_skill` returns
  complete loading evidence; candidates can no longer look loaded early.

## Desktop tray polish

- Windows reminder animation now uses dedicated adaptive icon frames that stay
  legible on light and dark taskbars, while normal, resting, and sleeping
  states continue to use their surface-specific artwork.
- Running-task correlation is isolated by known Agent client and conversation
  ID, with compatibility handling for generic Agent sources, so one Agent's
  completion cannot close another Agent's active task.

Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.3.7 会从 Agent 任务被真实观察到开始，一直跟踪到任务完成，并把这段
生命周期同步到已配对手机；同时，Prompt、Skill 与 MCP 在对话里共用一套一致的
资源底栏。

## 手机端实时 Agent 状态

- Agent Bridge 会在任务开始时记录来源、任务、工作区、仓库、会话与真实开始时间；
  匹配到完成事件后，会保留任务、完整详情、开始、结束和总耗时，不再用提醒时间
  反推生命周期。
- 每台已连接手机都会收到当前所选电脑的权威快照，包括正在运行的任务、有限条数的
  完成历史和真实未读状态；重连可以恢复快照，但桌面端重启后不会把旧任务伪装成
  仍在运行。
- 手机 Agent 页面把运行中任务与完成记录分开，并显示开始、结束和总耗时；不同
  已配对电脑的数据彼此隔离。点击系统通知会直接打开已运行 PWA 的 Agent 标签，
  不会刷新页面，通知图标与角标也统一使用 DingDong 品牌图案。
- 完成记录只有在动态页面真实可见且已经渲染后才会标记为已读；隐藏的桌面窗口
  不会再提前清掉未读状态。

## 统一的对话资源底栏

- Agent Bridge 会把生效的 Prompt、候选 Skill 与可用 MCP 放进同一个对话胶囊，
  使用稳定合并键与精确替换语义，避免跨轮次重复或残留旧资源名称。
- 支持富内容的宿主可以渲染自包含 MCP Apps 底栏；支持 ANSI 的终端与普通
  Markdown 宿主则从同一份权威数据获得等价降级展示，文本会限制长度并安全转义。
- 只有 `dingdong_load_skill` 返回完整加载证据后，Skill 才会显示 `*` 已使用标记，
  候选 Skill 不会再被提前显示成已加载。

## 桌面托盘细节

- Windows 提醒动画改用独立的自适应图标帧，在浅色与深色任务栏上都保持清晰；
  普通、休息和睡眠状态继续使用各自针对任务栏表面的资源。
- 运行中任务按已知 Agent 客户端与会话 ID 隔离匹配，同时兼容通用 Agent 来源，
  避免一个 Agent 的完成事件误关闭另一个 Agent 的运行任务。

Intel macOS 与 Windows 安装包继续标记为 beta。
