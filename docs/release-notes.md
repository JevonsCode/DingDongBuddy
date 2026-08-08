# DingDong 1.2.8

DingDong 1.2.8 makes the desktop companion's idle states predictable and gives
the new mascot artwork a small two-frame animation on both macOS and Windows.

## Companion state timing

- DingDong now opens in the normal state with `AgentToolIcon` instead of
  inheriting an old idle timestamp from the previous session.
- After three minutes without Agent or Clipboard activity, the companion moves
  to the resting state. After five minutes without either activity, it moves to
  sleeping.
- A new Agent reminder shows `ding` immediately. A Clipboard capture or an
  acknowledged reminder wakes the companion and restarts both idle thresholds.
- An Agent reminder left unopened for five minutes still nudges horizontally
  once per minute until it is acknowledged.

## Animated desktop artwork

- Reminder artwork alternates between `ding` and `ding2` every 0.7 seconds.
- Resting and sleeping artwork alternates between its two frames every 1.2
  seconds.
- Windows now follows the same normal, reminder, resting, and sleeping states,
  with light and dark taskbar artwork.
- The macOS resting mascot renders two pixels smaller in each dimension, and
  the unread count is lowered by two points for visual centering.

## Website polish

- Menu-bar notification previews now use the animated white `ding` artwork.
- The "everything close at hand" note uses the resting mascot, the custom sound
  card uses sleeping, and the local API heading now includes thinking.
- The Clipboard demo opens with All, Images, Text, Links, and Files visible in
  their default order.

Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.2.8 重新梳理了桌面伙伴的空闲状态，并让 macOS 与 Windows 都能
使用新的双帧小人动画。

## 伙伴状态计时

- DingDong 每次启动都从正常状态开始，显示 `AgentToolIcon`，不会沿用上次会话
  的旧空闲时间。
- 连续三分钟没有 Agent 或剪贴板活动时进入休息状态；连续五分钟两种活动都
  没有时进入睡眠状态。
- 新的 Agent 提醒会立即显示 `ding`；发生复制粘贴，或用户查看并处理提醒后，
  都会恢复正常状态并重新计算两段空闲时间。
- Agent 提醒五分钟仍未处理时，继续每分钟左右摇动一次，直到提醒被处理。

## 桌面双帧动画

- 提醒状态每 0.7 秒在 `ding` 与 `ding2` 之间切换。
- 休息与睡眠状态每 1.2 秒切换一次对应的第二帧。
- Windows 现在也支持正常、提醒、休息、睡眠四种状态，并分别适配深浅任务栏。
- macOS 状态栏的休息小人宽高各缩小 2px，未读数字下移 2pt 后更居中。

## 官网细节

- 状态栏提醒预览改为白色 `ding` 双帧动画。
- “东西随手能找到”使用休息小人，“提示声由你决定”使用睡眠小人，“喜欢写
  脚本”标题左侧增加思考小人。
- 官网剪贴板预览默认展示“全部、图片、文本、链接、文件”分类。

Intel macOS 与 Windows 安装包继续标记为 beta。
