# DingDong 1.2.7

DingDong 1.2.7 gives the desktop companion a clearer set of visual states and
makes repeated Clipboard content easier to understand and organize.

## Stateful DingDong companion

- The popup mascot and desktop status icon now use the new normal, reminder,
  resting, and sleeping artwork.
- An unseen Agent reminder uses the DingDong bell artwork immediately. After
  five minutes, the status icon nudges horizontally once per minute until the
  reminder is acknowledged.
- Five minutes without Agent activity switches the mascot to resting. Extended
  Clipboard inactivity switches it to sleeping and takes priority when both
  idle conditions apply.
- Every third click on the popup mascot briefly reveals the thinking pose.
- The former idle turn animation and its superseded icon assets have been
  removed. The DEV test panel can preview sleeping and reminder-nudge behavior.

## Clipboard organization

- Copying identical content consolidates it into the newest row, updates its
  timestamp, increments a visible count, and preserves every observed source.
- Resource Manager can sort Clipboard records by copy count.
- Archived Clipboard records can be pinned from their context menu, with the
  pin shown at the upper-right edge of the row.
- Archived records support persistent manual ordering in Resource Manager.
- The title action now says Add title only for untitled records and Edit title
  when a title already exists.

## Agent and resource polish

- Recent Agent summaries skip a leading DingDong or FULI marker and use the
  following content line as their description.
- Resource Manager uses the resting mascot when its issue check finds nothing.
- Website, README, macOS, and Windows packages now use the refreshed DingDong
  artwork consistently.

Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.2.7 为桌面伙伴增加了更清晰的状态表达，也让重复剪贴板内容更容易
识别、排序和整理。

## 有状态的 DingDong 伙伴

- 唤起面板小人和桌面状态图标统一使用新的正常、提醒、休息和睡眠图。
- Agent 出现未读提醒后立即显示铃铛 DingDong；超过五分钟仍未点击时，每分钟
  左右摇动一次，直到提醒被处理。
- 五分钟没有 Agent 动态时切换为休息状态；剪贴板长时间未使用时切换为睡眠
  状态，同时满足两种空闲条件时以睡眠状态优先。
- 点击唤起面板小人时，每第三次会短暂切换为思考状态。
- 已移除原来的空闲转身动画和旧图标资源；DEV 测试面板可直接预览睡眠状态与
  提醒摇动。

## 剪贴板整理

- 重复复制相同内容时会归并到最新一条，更新时间、增加可见次数，并保留所有
  出现过的来源。
- 资源管理中的剪贴板支持按复制次数排序。
- 已归档剪贴板内容可通过右键置顶，置顶标识显示在条目右上边缘。
- 归档内容可在资源管理中持久化手动排序。
- 没有标题时显示“添加标题”，已有标题时自动改为“修改标题”。

## Agent 与资源细节

- 最近 Agent 描述遇到首行 DingDong 或 FULI 标记时，会使用后续正文行。
- 资源管理检测未发现问题时改用休息状态小人。
- 官网、README、macOS 与 Windows 安装包统一更新为新的 DingDong 图标。

Intel macOS 与 Windows 安装包继续标记为 beta。
