# DingDong 1.4.1

DingDong 1.4.1 fixes the linked-phone Agent view so one running chat appears
once. When an Agent cannot provide a stable conversation ID, DingDong no
longer keeps every earlier turn as a separate running task.

## Correct running-chat state

- Repeated task starts from the same Agent client and normalized workspace now
  replace the previous running turn when no stable conversation ID is
  available.
- Known conversation IDs remain authoritative, so distinct chats in the same
  workspace stay separate. Different Agent clients also remain isolated.
- The authoritative phone snapshot now contains one current running item for
  one chat instead of an inflated count made from stale turns.
- Regression coverage exercises eight consecutive Codex turns at both the
  activity-controller boundary and the linked-phone snapshot boundary.

Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.4.1 修复了关联手机上的 Agent 运行状态：一个正在运行的 chat 现在只会
显示一次。当 Agent 无法提供稳定的会话 ID 时，DingDong 不会再把此前每一轮对话都
保留为独立的“正在运行”任务。

## 正确聚合运行中的 chat

- 当稳定会话 ID 缺失时，同一 Agent 客户端、同一规范化 workspace 的连续任务启动
  会替换上一轮运行记录。
- 已知会话 ID 仍是最高优先级，因此同一 workspace 中的不同 chat 继续分别显示；
  不同 Agent 客户端也不会被合并。
- 手机收到的权威状态快照现在会为一个 chat 保留一个最新运行项，不再用陈旧轮次
  放大“正在运行”数量。
- 活动控制器和手机状态快照都新增了连续八轮 Codex 对话的回归覆盖。

Intel macOS 与 Windows 安装包继续标记为 beta。
