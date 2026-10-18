/// Trigger rules installed into Agent prompt files (CLAUDE.md, AGENTS.md).
///
/// This block is resent with every request, so it only says when to call
/// DingDong. Response semantics live in [dingDongMcpInstructions] and in each
/// tool description, which the host already carries.
const String dingDongAgentBridgeGuidance = '''# DingDong prompt bridge

This section is maintained by DingDong.

- At the start of each user task, call `dingdong_bridge` and apply every returned Prompt in full as a required instruction. The latest response replaces earlier ones; if the call fails, say DingDong resources could not be loaded.
- Load a returned Skill with `dingdong_load_skill` only when its description matches the task. Call returned MCP tools only when the task needs them.
- When the response has `footer`, end the final reply with it exactly. Never print `statusLine`.
- Use `dingdong_notify` only when blocked or waiting for the user.
''';

/// Short initialize-time summary for MCP hosts.
///
/// Hosts such as Claude Code truncate server instructions at 2,048
/// characters, so this stays well below that limit.
const String dingDongMcpInstructions =
    '''DingDong delivers the user's Prompts, Skills and MCP references.
- At the start of each user task, call `dingdong_bridge`. Apply every `active.prompts` entry in full as a required instruction; the latest response is the authoritative snapshot and replaces earlier ones. If the call fails, say DingDong resources could not be loaded.
- `active.skills` lists id, name and description only. When a description matches the task, call `dingdong_load_skill`, apply the returned SKILL.md, and read referenced files with `dingdong_read_skill_file`.
- `active.mcps` are tool references, not instructions; call their tools only when the task needs them.
- When the response has `footer`, end the final reply with it exactly. After a tool from a returned MCP server finishes, call `dingdong_confirm_mcp_use` once if it is available. When a Skill load or MCP confirmation returns `footerMark`, replace `from` with `to` in the footer. Never print `statusLine`; the host renders it.
- Use `dingdong_notify` only when blocked or waiting for the user; a completion hook sends the task-complete alert.''';
