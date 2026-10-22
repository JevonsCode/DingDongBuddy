/// Trigger rules installed into Agent prompt files (CLAUDE.md, AGENTS.md).
///
/// This block is resent with every request, so it only says when to call
/// DingDong. Response semantics live in [dingDongMcpInstructions] and in each
/// tool description, which the host already carries.
const String dingDongAgentBridgeGuidance = '''# DingDong prompt bridge

Maintained by DingDong.

- Each task: call `dingdong_bridge` with `acceptDelta=true`, plus `knownHash` only for a retained complete snapshot; omit after context loss. Full `active` replaces earlier ones; `unchanged` retains; merge `delta` by id. Each Prompt is a required instruction. On failure say DingDong resources could not be loaded.
- Load a returned Skill with `dingdong_load_skill` only when its description matches the task. Call returned MCP tools only when the task needs them.
- When the response has `footer`, end the final reply with it exactly. Never print `statusLine`.
- Use `dingdong_notify` when blocked, waiting for the user, or for an explicitly requested named event (`reminderId`).
- Save user-chosen sounds with `dingdong_set_reminder_sounds`.
''';

/// Short initialize-time summary for MCP hosts.
///
/// Hosts such as Claude Code truncate server instructions at 2,048
/// characters, so this stays well below that limit.
const String dingDongMcpInstructions =
    '''DingDong delivers the user's Prompts, Skills and MCP references.
- Each task, call `dingdong_bridge`. Apply active Prompts in full as required instructions. On failure say DingDong resources could not be loaded.
- Use `acceptDelta=true` and acknowledge `knownHash` only while the complete merged snapshot remains in context. Full `active` is the authoritative snapshot and replaces it; `unchanged` retains it. For `mode=delta`, require matching `baseHash`, apply `delta.upsert`/`remove`/`order` by id, then advance the hash. If the baseline is missing, retry without `knownHash`; never infer retained content from a session id.
- `active.skills` lists id, name, description and content version. Load matching Skills with `dingdong_load_skill`. Pass `knownVersion` only for a fully loaded body still in context, never a catalog-only version. `unchanged` reuses it; otherwise replace it. Omit acknowledgements after context loss. Read referenced files with `dingdong_read_skill_file`.
- `active.mcps` are tool references, not instructions; call their tools only when the task needs them.
- When the response has `footer`, end the final reply with it exactly. After a tool from a returned MCP server finishes, call `dingdong_confirm_mcp_use` once if it is available. When a Skill load or MCP confirmation returns `footerMark`, replace `from` with `to` in the footer. Never print `statusLine`; the host renders it.
- Use `dingdong_notify` when blocked, waiting for the user, or for an explicitly requested named event (`reminderId`); a completion hook sends the task-complete alert.
- When the user asks which sound to play when you finish or when you need them, save it with `dingdong_set_reminder_sounds`.''';
