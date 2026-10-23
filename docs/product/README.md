# DingDong user guides · 使用文档

These guides describe the published DingDong 1.9.1 features. Start with
[first-run onboarding](onboarding.md) or the [中文项目介绍](../../README.zh.md).

| Feature / 功能 | Guide / 说明 |
| --- | --- |
| Install and connect / 安装与接入 | [Install with an Agent](../../INSTALL_WITH_AGENT.md), [Agent adapters](agent-adapter-configuration.md) |
| AI+ / 按任务筛选资源 | [Model setup, selection rules and data boundaries](ai-companion.md) |
| Skill versions / Skill 版本历史 | [Compare and restore complete packages](skill-version-history.md) |
| Reminders / 自定义提醒 | [Completion, needs-input, named reminders and sounds](agent-reminders.md) |
| Devices / 在线设备与传输历史 | [Pairing, sharing, routes and file records](connected-devices.md) |
| Token usage / 用量热力图与导出 | [Agent history](../../README.md#local-daily-token-history), [DingDong internal usage](ai-companion.md#internal-token-accounting) |
| Bridge / 资源交付与去重 | [Acknowledged snapshots and Skill versions](bridge-context-delivery.md) |
| Claude Code status line / 状态栏 | [Setup alongside an existing HUD](claude-code-statusline.md) |
| Jev plugin / Jev 插件 | [Install, API key and separate usage](jev-plugin.md) |
| macOS selection / 系统划词 | [Copy, translate and explain](system-selection-plugin.md) |
| Shortcuts / 快捷键与默认设置 | [English reference](../../README.md#default-shortcuts-and-settings), [中文参考](../../README.zh.md#默认快捷键和设置) |

AI+ now selects resources only when an Agent calls Bridge with automatic
selection enabled. Insight reports, clipboard analysis and proactive check-ins
are no longer available. Old analysis receipts may remain in Token history.

AI+ 目前只在开启自动资源筛选、且 Agent 调用 Bridge 时按任务选择资源；不再提供
洞察报告、剪贴板分析和主动关怀。旧的分析用量仍可能保留在历史中。

Public changes for this release are in the [release notes](../release-notes.md).
Design proposals, development previews and regression reports in this directory
are engineering records; use the guides above for current product behavior.

Development preview: [Windows screenshot plugin and plugin details](screenshot-plugin.md).
This extension is not part of the published 1.9.1 release.
