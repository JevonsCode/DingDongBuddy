# DingDong 0.7.9

This release turns DingDong's Agent connection into two concrete native paths:
an MCP bridge for reusable resources and a completion hook for dependable task
notifications.

## Agent connection

- The copy-only setup prompt now configures MCP and the client's native
  completion hook separately, then tests both paths.
- Codex, Claude Code, Cursor, and Gemini CLI use their own supported user-level
  MCP and hook configuration formats.
- Completion hooks extract one useful sentence from the final response or local
  transcript without making another model call.
- Duplicate completion notifications from the same source are suppressed within
  a short window.

## Skill and MCP resources

- Online Skills are installed as complete packages, including `SKILL.md`,
  `scripts/`, `references/`, `assets/`, and sibling files.
- Enabled Skills are mirrored atomically into supported clients' native Skill
  directories with DingDong ownership markers.
- Enabled MCP resources are written as real client MCP entries while preserving
  unrelated user configuration.
- Resource saves are transactional: invalid Skill metadata, MCP transport, or
  client configuration causes the change to roll back.
- `dingdong_bridge` routes summary-first candidates using task text, workspace
  path, repository URL, activation mode, and reusable project rules.

## Documentation and distribution

- English and Chinese READMEs now document automatic setup, manual setup, exact
  client locations, verification, and the complete runtime architecture.
- macOS packages are published separately for Apple Silicon and Intel.
- Intel macOS and Windows packages remain marked **beta**.

---

本版本把 DingDong 的 Agent 接入拆成两条真实的原生链路：MCP 桥接负责复用资源，
完成 Hook 负责稳定的任务结束提醒。

- 只读接入提示词会分别配置并测试 MCP 与完成 Hook，不再只检查工具是否出现。
- 支持 Codex、Claude Code、Cursor 和 Gemini CLI 各自的用户级配置格式。
- 完成提醒会从最终回复或本地会话记录中提取一句有效结果，不额外调用模型。
- 在线 Skill 会下载整个 Package，包括 `scripts/`、`references/`、`assets/` 等文件。
- 已启用的 Skill 会原子同步到原生 Skill 目录；已启用的 MCP 会写入真实客户端配置，
  并保留用户的其他设置。
- 资源保存带预检和回滚，错误配置不会留下半完成状态。
- `dingdong_bridge` 会结合任务、工作区、仓库地址和项目规则先返回简要候选，确定
  需要后再读取完整内容。
- 中英文 README 增加完整接入说明与详细架构图。
- Apple Silicon 与 Intel 分别提供安装包；Intel 和 Windows 继续标记为 **beta**。
