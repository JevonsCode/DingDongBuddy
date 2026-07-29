# DingDong 0.9.2

This release makes DingDong's system-wide Clipboard shortcut configurable and
publishes a complete reference for the keyboard shortcuts and settings shipped
with the app.

## Configurable global Clipboard shortcut

- Adds **Settings → Keyboard shortcuts → Open or hide Clipboard**.
- Keeps `Command-Shift-V` on macOS and `Control-Shift-V` on Windows as the
  defaults while allowing a different combination to be recorded.
- Supports letters, numbers, F1–F12, arrow keys, Space, and Return with at
  least one modifier.
- Applies the new shortcut immediately, persists it across restarts, and offers
  a one-click reset to the platform default.
- Updates the Clipboard popup footer to show the configured shortcut.

## Conflict-safe desktop registration

- Registers custom combinations through the native macOS and Windows runners.
- Keeps the previous working shortcut when another application already owns the
  requested combination.
- Falls back safely when a saved shortcut is malformed or is no longer
  available during startup.
- Uses one portable preference representation while preserving platform-native
  Command, Control, Option, Alt, and Windows-key labels.

## Public defaults reference

- Adds bilingual shortcut and settings-default tables to the DingDong website.
- Adds the same reference to the English and Chinese READMEs.
- Documents supported shortcut keys, configuration limits, restart
  requirements, and platform-specific defaults.

Intel macOS and Windows packages remain beta.

---

本版本让 DingDong 的系统级剪贴板快捷键支持自定义，并在官网及中英文 README 中
补齐应用内默认快捷键和设置项参考。

## 可自定义的全局剪贴板快捷键

- 新增 **设置 → 键盘快捷键 → 打开或隐藏剪贴板**。
- macOS 默认仍为 `Command-Shift-V`，Windows 默认仍为
  `Control-Shift-V`，用户可直接录入其他组合。
- 主键支持字母、数字、F1–F12、方向键、空格和回车，且必须至少包含一个修饰键。
- 新组合录入后立即生效并跨重启保存，可一键恢复平台默认值。
- 剪贴板弹窗底部会显示当前已配置的快捷键。

## 安全的双平台注册与冲突回退

- 通过 macOS 与 Windows 原生 Runner 动态注册自定义组合。
- 如果新组合已被其他应用占用，继续保留此前可用的快捷键。
- 已保存的组合格式异常或启动时失效时，会安全回退并显示提示。
- 使用统一的可移植配置格式，同时保留 Command、Control、Option、Alt 和 Windows
  键的平台原生显示。

## 公开默认值参考

- 官网新增中英文快捷键与设置默认值表格。
- English README 与中文 README 同步加入相同参考。
- 明确记录可用主键、配置范围、需要重启的设置以及平台差异。

Intel macOS 与 Windows 安装包继续标记为 beta。
