# DingDong 0.9.4

This release restores Codex completion alerts with an explicit, verifiable
one-click trust action and adds a small clipboard-feedback animation.

## Verifiable Codex completion-Hook trust

- Adds a **Codex completion Hook** card under **Resource Manager → Agent
  access → Codex**.
- Reads the current Hook inventory through Codex App Server and shows the
  command, current hash, enabled state, and trust state.
- Adds **Trust & enable** only for the exact user-level DingDong `Stop` command
  installed by the current application.
- Re-checks the Hook key and hash immediately before writing, refusing a
  command mismatch, duplicate Hook, changed hash, managed Hook, or unknown
  trust state.
- Uses Codex's user-config `hooks.state` write path and reports success only
  after Codex reads the Hook back as trusted and enabled.
- Falls back to `/hooks` when the installed Codex build does not expose the
  required App Server methods.

## Temporary recovery and setup guidance

- Adds a read-only-by-default diagnostic script for source checkouts; `--apply`
  performs the same exact-hash write and post-write verification as the UI.
- Updates English and Chinese setup instructions to prefer the DingDong action
  while retaining `/hooks` as the compatibility fallback.
- Keeps MCP availability and completion-Hook trust as separate, independently
  verified states.

## Clipboard feedback

- Makes the DingDong mascot shake briefly when a new clipboard-copy event is
  detected.
- Keeps manual mascot clicks and clipboard capture behavior unchanged.

Intel macOS and Windows packages remain beta.

---

本版本为 Codex 完成提醒新增可验证的一键信任操作，并加入轻量的剪贴板复制反馈动画。

## 可验证的 Codex 完成 Hook 信任

- 在 **资源管理 → Agent 接入 → Codex** 新增 **Codex 完成 Hook** 状态卡片。
- 通过 Codex App Server 读取当前 Hook，展示命令、当前哈希、启用状态和信任状态。
- 只有精确匹配当前正式版 DingDong 所安装的用户级 `Stop` 命令时，才显示
  **信任并启用**。
- 写入前立即重新检查 Hook key 和哈希；命令不匹配、Hook 重复、哈希已变化、Hook
  受托管或信任状态未知时都会拒绝写入。
- 使用 Codex 用户配置中的 `hooks.state` 写入通道，并且只有 Codex 回读为已信任且
  已启用时才报告成功。
- 当前 Codex 版本未提供所需 App Server 接口时，回退到 `/hooks` 手动审核。

## 临时恢复与接入说明

- 为源码工作区新增默认只读的诊断脚本；只有显式传入 `--apply` 才会执行与按钮相同的
  精确哈希写入和写后验证。
- 更新中英文接入说明，优先使用 DingDong 按钮，同时保留 `/hooks` 兼容入口。
- 继续把 MCP 可用性和完成 Hook 信任视为两条独立、分别验证的链路。

## 剪贴板反馈

- 检测到新的剪贴板复制事件时，DingDong 吉祥物会短暂摇动。
- 手动点击吉祥物和原有剪贴板采集行为保持不变。

Intel macOS 与 Windows 安装包继续标记为 beta。
