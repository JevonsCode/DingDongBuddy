# DingDong 0.9.9

This release makes the resource manager aware of the Agent client that started
the task, so shared resources can be targeted without leaking to other clients.

## Source-scoped resources

- Trigger groups can match the current workspace path, repository URL, or Agent
  source, including Codex, Claude Code, and Cursor.
- Multiple source rules in one group use OR semantics, so a resource can be
  shared by several Agent clients.
- Prompt and Skill delivery is filtered by the current source, and full Skill
  loads re-check the same scope before returning content.
- Source-scoped MCP servers are written only to matching native client
  configurations; unscoped MCP servers retain their existing global behavior.

## Compatibility and administration

- Existing workspace- and repository-scoped trigger groups continue to work.
- Changing trigger groups immediately re-synchronizes native MCP configuration.
- Resource Manager and the Agent API expose the same source-scope rules.

Intel macOS and Windows packages remain beta.

---

本版本让资源管理器知道发起任务的 Agent 客户端，从而可以按来源分配资源，避免
资源误发给其他客户端。

## 按来源管理资源

- 触发组可以按当前工作区目录、仓库地址或 Agent 来源匹配，包括 Codex、Claude Code
  和 Cursor。
- 同一个触发组中的多条来源规则按“任一命中”处理，因此一个资源可以共享给多个
  Agent 客户端。
- Prompt 和 Skill 会按当前来源过滤，完整 Skill 加载返回正文前会再次校验相同作用域。
- 设置了来源作用域的 MCP 只写入匹配的原生客户端配置；未设置作用域的 MCP 保持原有
  的全局行为。

## 兼容性与管理

- 既有的工作区和仓库作用域触发组继续有效。
- 触发组变化后会立即重新同步原生 MCP 配置。
- 资源管理器和 Agent API 使用同一套来源作用域规则。

Intel macOS 与 Windows 安装包继续标记为 beta。
