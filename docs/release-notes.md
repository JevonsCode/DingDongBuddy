# DingDong 1.3.6

DingDong 1.3.6 gives the popup a softer blue-black dark appearance and lets
macOS render ordinary menu-bar buddy states with native adaptive tinting.

## Softer, coherent dark mode

- The dark interface now uses layered blue-black surfaces instead of near-black
  gray, keeping the popup calm while preserving separation between the shell,
  controls, cards, fields, and footer.
- Dynamic, Resource Library, Clipboard, and Agent API now consistently consume
  the theme-aware palette. Their content cards, tags, status indicators, filter
  counts, and primary actions retain clear contrast in dark mode.
- Populated Dynamic and Resource Library cards no longer clip at the bottom.
  New dark golden coverage keeps those real-content layouts and the Clipboard
  workspace from regressing.

## Native macOS menu-bar appearance

- Normal, resting, and sleeping buddy states now use macOS template images, so
  AppKit applies the correct monochrome tint for the current menu-bar appearance.
- The reminder state stays non-template because its colored capsule and white
  artwork are intentional, including the alternate animation frame.
- Windows continues to select dedicated light- and dark-taskbar artwork.

Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.3.6 为弹窗带来更柔和的蓝黑色暗黑模式，并让 macOS 用系统原生方式
为普通菜单栏伙伴状态自动着色。

## 更柔和、统一的暗黑模式

- 暗黑界面不再使用接近纯黑的灰色，而是采用有层次的蓝黑色；弹窗外壳、控件、
  卡片、输入框与底栏之间仍保持清晰分区。
- 动态、资源库、剪贴板与 Agent API 统一使用可随主题切换的色板；内容卡片、标签、
  状态标记、筛选数量和主操作按钮在暗黑模式下都有清楚的对比度。
- 填充真实内容后，动态和资源库卡片不再出现底部裁切；新增暗黑 golden 截图覆盖
  这两个页面与剪贴板页面，防止布局和配色回退。

## macOS 菜单栏原生适配

- 普通、休息和睡眠状态改用 macOS template image，由 AppKit 根据当前菜单栏外观
  自动应用正确的单色着色。
- 提醒状态刻意保留非 template 的彩色胶囊与白色图案，包括第二帧动画。
- Windows 继续按浅色或深色任务栏选择对应资源。

Intel macOS 与 Windows 安装包继续标记为 beta。
