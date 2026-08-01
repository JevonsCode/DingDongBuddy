# DingDong 0.9.7

This release adds a visual macOS Accessibility-permission flow, selective local
data cleanup, and calmer desktop interaction feedback.

## Visual Accessibility permission helper

- Opens the macOS Accessibility page with a native helper placed beside System
  Settings and exposes the current DingDong application as a draggable card.
- Explains both stale-entry paths: remove the old entry first when **−** is
  available, or drag once, remove it, and drag again when **−** starts disabled.
- Uses Chinese or English instructions according to the user's system language.
- Detects the real denied-to-granted transition, closes the helper, reveals the
  main panel, switches to Clipboard, waits until the page is visible, and then
  dismisses the yellow permission banner with a one-shot split and amber-particle
  animation.

## Local data visibility and cleanup

- Breaks local storage down into clipboard history, resource library, Agent
  activity, Adapter revision history, application configuration, and other
  files.
- Allows clipboard history, Agent activity, and Adapter revision history to be
  selected and cleared together after an explicit destructive confirmation.
- Keeps resource-library data, current Adapters, configuration, and unrecognized
  files protected from this cleanup flow.
- Compacts the clipboard database and truncates its write-ahead log after a full
  history clear.

## Desktop feedback polish

- Removes Flutter Material's default circular hover, ink, ripple, and overlay
  halos while retaining designed rectangular hover and focus treatments.
- Shakes the complete macOS menu-bar icon briefly when DingDong detects a new
  clipboard copy.
- Keeps destructive clipboard cleanup in Settings instead of the tray menu.

Intel macOS and Windows packages remain beta.

---

本版本新增图形化 macOS 辅助功能授权流程、可选择的本地数据清理，以及更克制的桌面
交互反馈。

## 图形化辅助功能授权助手

- 打开 macOS“辅助功能”页面时，在系统设置旁显示原生授权助手，并把当前 DingDong
  应用显示为可拖拽卡片。
- 同时说明两种旧条目处理方式：**−** 可用时先删除旧条目；**−** 置灰时先拖一次，
  删除旧条目后再拖一次。
- 根据用户系统语言自动显示中文或英文说明。
- 检测真实的“未授权 → 已授权”变化后，关闭助手，先唤出主面板并切到剪贴板；页面
  可见后，黄色权限提示会以一次性的分裂和琥珀色粒子动画消失。

## 本地数据占用与清理

- 按剪贴板历史、资源库、Agent 活动、Adapter 修订历史、应用配置及其他文件展示
  本地存储占用。
- 可组合选择剪贴板历史、Agent 活动和 Adapter 修订历史，并在明确的永久删除确认后
  一次清理。
- 资源库、当前 Adapter、应用配置和未识别文件不会被这个清理入口删除。
- 清空全部剪贴板历史后会压缩数据库并截断预写日志。

## 桌面反馈细节

- 全局移除 Flutter Material 默认圆形 hover、ink、ripple 和 overlay 光晕，同时保留
  经过设计的矩形 hover 与键盘焦点反馈。
- DingDong 检测到新的剪贴板复制时，macOS 菜单栏完整图标会短暂摇动。
- 具有破坏性的剪贴板清理入口统一放在设置中，不再放在托盘菜单里。

Intel macOS 与 Windows 安装包继续标记为 beta。
