# DingDong 1.0.2

DingDong 1.0.2 is a focused fix release for Agent activity reliability and a
consistent Clipboard experience across the desktop app and release website.

## Agent activity

- Unavailable background Codex tasks are identified before opening, so a stale
  task does not lead to a broken conversation view.
- Newly surfaced Agent activity is acknowledged after it has remained visible
  long enough to read, keeping the unread indicator useful without requiring a
  second navigation.

## Clipboard and website preview

- The compact Clipboard toolbar now stays focused on search and filters;
  monitoring remains available from the tray menu and Settings.
- The website Clipboard preview uses the same toolbar shape and category data
  model as the desktop app, including the corrected `links`, `images`, `files`,
  and `text` categories.
- Popup branding and version metadata remain visible across release and
  development builds.

Intel macOS and Windows packages remain beta.

---

DingDong 1.0.2 是一个修复 Agent 动态可靠性，并统一桌面端与官网剪贴板体验的版本。

## Agent 动态

- 打开前会先识别已经不可用的后台 Codex 任务，避免进入失败的聊天页面。
- 新出现的 Agent 动态在保持可见一段时间后自动标记为已读，让未读提醒更准确，
  不需要再次切换页面。

## 剪贴板与官网预览

- 紧凑剪贴板工具栏只保留搜索和筛选；监听入口保留在托盘菜单和设置中。
- 官网剪贴板预览与桌面端使用相同的工具栏形状和分类数据模型，修正
  `links`、`images`、`files`、`text` 分类。
- 发布版和开发版都保持品牌名称与版本信息完整展示。

Intel macOS 与 Windows 安装包继续标记为 beta。
