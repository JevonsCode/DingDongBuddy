# DingDong 0.9.8

This release makes repeated Agent reminders easier to scan while keeping the
choice in the user's hands.

## Repeated session reminders

- Groups reminders with the same conversation ID into one Dynamic item by
  default.
- Plays the notification sound for each reminder, shows a `×N` repeat badge,
  and does not increase the recent-Agent count.
- Adds **Settings → Recent Agents → Group repeated sessions** so users can
  disable grouping and keep each reminder as a separate item.
- Persists the choice across restarts and keeps old activity records compatible.

## Dynamic panel readability

- Truncates long Agent source and message text with ellipsis in Dynamic and
  Recent Agents management views.
- Keeps the repeat badge and actions visible without overflowing the panel.

Intel macOS and Windows packages remain beta.

---

本版本让重复的 Agent 提醒更容易浏览，同时把是否合并交给用户选择。

## 重复会话提醒

- 默认将相同会话 ID 的提醒合并到同一个动态项。
- 每次提醒仍会触发声音，动态项显示 `×N`，且不会增加最近 Agent 数量。
- 新增 **设置 → 最近 Agent → 合并同会话提醒**，关闭后每次提醒会独立显示并计数。
- 设置会在重启后保留，旧的活动记录仍可正常读取。

## 唤起面板可读性

- Dynamic 和最近 Agent 管理页面会对过长的 Agent 来源和消息使用省略号。
- 重复次数徽标和操作按钮保持可见，不会撑破面板布局。

Intel macOS 与 Windows 安装包继续标记为 beta。
