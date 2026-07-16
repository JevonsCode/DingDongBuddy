# DingDong 0.7.8

This release focuses on a clearer Resource Manager, more capable clipboard
organization, and a more direct MCP onboarding flow.

## Resource Manager

- Prompt, Skill, and MCP resources now use dedicated cards and editing flows.
- Online Skills retain their source URL, parse `name` and `description` from
  `SKILL.md`, keep upstream content read-only, and provide Open and Update
  actions.
- Trigger groups can activate resources by workspace path or repository
  address.
- Resource lists support selection, bulk deletion, and native desktop context
  menus.

## Clipboard

- Clipboard groups can be searched, reused, and deleted from native context
  menus.
- Custom categories can match content type, regular expressions, source
  application, and length.
- Large histories use lazy list construction and expose a return-to-top action.
- Preview controls, switches, selection marks, and action feedback now use a
  consistent compact desktop style.

## Agent and MCP

- The Agent setup prompt is now read-only and written for direct installation,
  reload, verification, and `dingdong_notify` testing.
- First-time users see an MCP entry badge and are guided to MCP Access.
- Prompt, Skill, and MCP cards expose clearer type-specific metadata.

## Desktop and distribution

- macOS notifications no longer bounce the Dock icon; DingDong sounds and unread
  state are preserved.
- macOS packages are published separately for Apple Silicon and Intel.
- Intel macOS and Windows packages remain marked **beta**.
- The minimum supported macOS version is now macOS 13.

---

本版本重点更新了资源管理、剪贴板整理和 MCP 接入体验。

- 提示词、Skill、MCP 使用各自适合的卡片和编辑方式。
- 在线 Skill 支持解析 `SKILL.md`、保留来源、只读查看和手动更新。
- 触发分组可以根据工作区路径或仓库地址决定资源是否启用。
- 资源和剪贴板列表支持多选、批量删除与系统原生右键菜单。
- 剪贴板支持自定义分类、正则规则、来源应用和长度条件。
- MCP 接入提示词改为可直接交给 Agent 执行的只读内容。
- macOS 提示不再让 Dock 图标跳动。
- Apple Silicon 与 Intel 分别提供安装包；Intel 和 Windows 标记为
  **beta**。
