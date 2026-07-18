# DingDong 0.7.10

This release makes DingDong easier for both people and Agents to configure,
while giving Windows a platform-native interaction and notification pass.

## Agent configuration

- Adds the built-in **DingDong Configure** Skill so an Agent can discover what
  DingDong can configure before changing prompts, Skills, MCP servers, project
  policies, trigger groups, or clipboard organization.
- Adds public trigger-group create, read, update, and delete routes for reusable
  repository, directory, and task scopes.
- Keeps enabled Agent resources synchronized to supported clients and allows the
  built-in Skill to update from its public GitHub source.

## Desktop design

- Redesigns clipboard category management with a clearer title hierarchy,
  semantic category icons, compact edit and delete actions, and a distinct
  primary create action.
- Makes active clipboard filtering visible from the collapsed filter control.
- Standardizes resource transfer controls and refreshes the website product
  model so its icons and layout better match the real application.
- Clips macOS modal overlays to the rounded callout window instead of painting
  square barrier corners.

## Windows platform pass

- Adds Notion-style native-feeling context menus and Control-key shortcut hints.
- Lets the Windows system frame own popup corners while macOS keeps DingDong's
  branded rounded callout surface.
- Selects tray artwork for light or dark taskbars and uses the bundled attention
  frame for persistent unread flashing.
- Moves unread counts into the localized tray tooltip so the 16×16 tray icon
  remains legible.

## Distribution

- Publishes Apple Silicon and Intel macOS packages plus the Windows x64 package.
- Intel macOS and Windows packages remain marked **beta**.

---

本版本让用户和 Agent 都更容易配置 DingDong，同时完成了一轮 Windows 原生交互与
通知体验优化。

## Agent 配置

- 新增内置 **DingDong Configure** Skill。Agent 在修改提示词、Skill、MCP、项目策略、
  触发分组或剪贴板分类前，可以先读取 DingDong 支持的配置能力。
- 新增公开的触发分组增删改查接口，可复用仓库、目录和任务范围。
- 已启用的 Agent 资源会继续同步到受支持客户端；内置 Skill 可从公开 GitHub 地址更新。

## 桌面设计

- 重新设计剪贴板分类管理，统一标题层级、分类语义图标、紧凑编辑与删除操作，并明确
  “新建分类”的主操作状态。
- 收起筛选面板后仍能看出当前存在生效中的剪贴板筛选。
- 统一资源导入导出控件，网站中的产品模型也更贴近真实应用的图标与布局。
- macOS 弹窗蒙层会沿主窗口圆角裁剪，不再出现四个直角。

## Windows 平台优化

- 新增接近 Notion 密度的右键菜单，并使用 Control 键显示和触发快捷操作。
- Windows 外轮廓交给系统窗口绘制，macOS 继续保留 DingDong 的圆角浮层样式。
- 托盘图标会适配浅色或深色任务栏，存在未读内容时使用内置提醒图标持续闪烁。
- 未读数量移到本地化托盘提示中，避免在 16×16 图标里显示模糊数字。

## 分发

- 发布 Apple Silicon、Intel macOS 安装包和 Windows x64 压缩包。
- Intel macOS 与 Windows 版本继续标记为 **beta**。
