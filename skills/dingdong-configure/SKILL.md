---
name: dingdong-configure
description: Use when a user asks an Agent to configure DingDong resources, project or repository scopes, policies, prompts, Skills, MCP servers, Agent client integration paths, clipboard organization, or how reminder actions reopen Agent conversations.
---

# Configure DingDong

## Overview

Configure DingDong through its loopback Agent API. Translate the user's intent into reusable resources and context-aware trigger groups, then verify the result through the same bridge Agents use at task start.

Canonical source: <https://github.com/JevonsCode/DingDongBuddy/tree/main/skills/dingdong-configure>

## Runtime Semantics

Keep the three resource types distinct:

| Type | How it reaches the Agent | What the Agent does |
|---|---|---|
| Prompt | Native instruction files contain only a persistent Bridge bootstrap. Every active Prompt is returned in full by `dingdong_bridge`. | Treat each successful response as the current authoritative Prompt snapshot and apply every active Prompt automatically as a required instruction. |
| Skill | Each successful Bridge response contains the authoritative complete catalog of every valid, enabled, scope-matched Skill as `id`, `name`, and `description` only. Full content stays in DingDong until requested. | Match a returned description first, then call `dingdong_load_skill` with the candidate ID or name and current workspace. Apply the returned full `SKILL.md`; read only referenced package files with `dingdong_read_skill_file`. A Skill absent from the current catalog is unavailable, disabled, invalid, or out of scope. |
| MCP | Enabled MCP servers are written into the client's native MCP configuration. The bridge returns only candidate metadata. | Call a configured MCP tool only when the task needs it. MCP availability is not an instruction and does not require a call every turn. |

Enabled state and trigger groups filter the Skill catalog, and every Skill and supporting-file load re-checks them so an old name or ID cannot bypass a disabled or out-of-scope resource. Every active, scope-matched MCP and Knowledge candidate is returned as summary metadata. Unscoped MCP servers are synchronized to every configured client; source-scoped MCP servers are synchronized only to matching native client configurations. DingDong no longer mirrors managed Skills into native Agent Skill directories; Adapter Skill paths remain useful for removing legacy DingDong mirrors and warning about independently installed native Skills with the same name.

The bridge also returns a compact canonical `conversation.capsule` plus capability-specific presentations when Prompt, Skill, or MCP resources are exposed. When `conversation.capsule.visible` is true, keep that state until the final user-visible response so later usage evidence can be merged. A successful visible `dingdong_load_skill` response returns a replacement `conversation.item` with the same opaque `mergeKey` as its candidate, `confirmedUse: true`, and `marker: "*"`; replace only that matching item. The merge key is merge-only metadata and must never be displayed. Only direct full-Skill-load evidence earns the marker, and it does not claim the Agent followed every instruction. Select presentation by capability rather than product name: an MCP Apps host calls `dingdong_render_conversation_footer` exactly once with the final merged capsule; an explicitly ANSI-capable terminal uses `conversation.presentations.ansi.line`; every other host includes the Markdown `conversation.line` exactly once. The MCP App is a self-contained `ui://` HTML resource, not HTML to paste into a normal reply. Prompt, Skill, and MCP use warm orange, blue, and green respectively. Show only truncated titles and the truthful marker; never display resource content, descriptions, IDs, or merge keys.

## Workflow

1. Prefer the native DingDong MCP tools. If the write tools are unavailable, locate the active loopback port, call `GET /health`, then inspect `GET /agent/capabilities` and use the equivalent HTTP endpoints.
2. Read before writing. Call `dingdong_search_assets` and inspect existing scopes before creating anything; update or reuse a matching object instead of duplicating it.
3. Model the request:
   - Store behavioral policy as a `prompt`.
   - Store reusable procedures as a `skill` with valid `SKILL.md` content and an optional complete package.
   - Store connection settings as an `mcp` resource.
   - Model a SKU, service, environment, or team as tags/group metadata; DingDong has no first-class SKU type.
   - Model where a resource applies with a trigger group, then attach its ID through `triggerGroupIds`.
4. Create or patch the trigger group before attaching it to a resource. Never invent an unknown trigger-group ID.
5. Verify with `dingdong_bridge` using representative task text, `workspacePath`, `repositoryUrl`, and `source` when relevant. Check both a matching and non-matching context.

## Install a Skill for One Project

When the user asks to install “this Skill through DingDong for project X”:

1. Resolve the Skill source to either an official GitHub repository/folder/`SKILL.md` URL or an absolute local Skill directory/`SKILL.md` path. Resolve project X to its existing exact absolute project path. Do not guess either value. If a separate native Skill with the same name already exists in an Agent's global directory, warn that DingDong's switch cannot disable that independent copy.
2. Search for the Skill first. If it is not already managed by DingDong, call `dingdong_install_skill`. Keep the returned resource `id`.
3. Call `dingdong_upsert_trigger_group` with a stable name dedicated to this Skill/project pair and only the exact absolute `projectPath`. Keep the returned group `id`; do not add another OR-ed rule to a strict project Skill group or reuse a shared group's name when its rules would change.
4. Call `dingdong_bind_resource_scope` with the resource ID, that group ID, and `strictProjectSkill: true`.
5. Call `dingdong_bridge` once with the matching workspace and once with an unrelated workspace. The Skill must be a candidate only in the matching context. Call `dingdong_load_skill` in both contexts as well: the matching load must succeed and the unrelated load must fail.

These writes are idempotent: installation updates the same source/name, trigger-group upsert reuses its name, and scope binding replaces the resource's group IDs. A newly installed Skill stays disabled until it is successfully bound, so the multi-step workflow does not create a transient globally available candidate. Strict binding rejects `contains`, repository rules, relative, root, missing, or unknown project scopes. Never treat Bridge filtering alone as sufficient: the full-content load must enforce the same scope.

## Configure Agent Adapters

Agent Adapters are user-level declarative YAML files for Agent detection, MCP and Prompt targets, and native Skill locations retained for legacy DingDong mirror cleanup and independent-Skill collision warnings. Use them when the user asks to add a client or change those Agent integration paths. DingDong-managed Skills are delivered dynamically and are not deployed to the Adapter's Skill paths. Do not use Adapters for conversation terminal selection; that is `agent-launchers.json`.

Resolve the user directory by operating system:

| Platform | Directory |
|---|---|
| macOS | `~/Library/Application Support/DingDong/Agent Adapters` |
| Windows | `%APPDATA%\DingDong\Agent Adapters` |
| Linux | `~/.local/share/DingDong/Agent Adapters` |

One `.yaml` or `.yml` file defines one complete Adapter. A user file with the same `id` fully replaces the bundled definition; fields are not merged. A custom client can use:

```yaml
schemaVersion: 1
id: new-agent
displayName: New Agent
detect:
  directory: ~/.new-agent
skills:
  global: ~/.new-agent/skills
  project: .new-agent/skills
mcp:
  file: ~/.new-agent/mcp.json
  format: mcpServers-json
prompt:
  file: ~/.new-agent/AGENTS.md
  includeBridgeRoutingInstructions: true
```

The complete allowed structure is: root fields `schemaVersion`, `id`, `displayName`, `detect`, `skills`, `mcp`, and `prompt`; `detect.directory`; paired `skills.global` and `skills.project`; paired `mcp.file` and `mcp.format`; and `prompt.file` plus optional `prompt.includeBridgeRoutingInstructions`. No other fields are supported. Allowed MCP formats are `codex-toml`, `claude-json`, `cursor-json`, `gemini-json`, `kiro-json`, and `mcpServers-json`.

User paths must use `~`, `~/...`, or an absolute path inside the user's home. Resolve the real home and every existing path ancestor, then use component-aware containment rather than string-prefix comparison; reject broken links or any real target outside the home. `skills.project` must use `/` separators and be a safe relative directory without `..` or backslashes. `skills.global` and `skills.project` must appear together.

When modifying an Adapter:

1. Confirm the Agent runs on the same machine as DingDong.
2. Read the complete existing user YAML. If no user override exists, create a complete document; do not assume field-level merging with the built-in definition.
3. Preserve the `id` and unrelated fields. Reject invalid YAML, duplicate YAML keys, unknown fields, unsafe paths, duplicate IDs, and unsupported MCP formats instead of guessing. Stop on an unknown field; remove it only after the user explicitly authorizes that exact removal with the loss explained.
4. Never add arbitrary commands, scripts, Hooks, tokens, environment variables, workspace paths, or conversation IDs.
5. Require the target to be absent or a regular non-symlink file and require its real parent directory to remain inside the expected DingDong directory. Write through a uniquely named regular temporary file in that same directory. Immediately before replacement, re-read the target and stop if it changed since inspection. Preserve its permissions where supported, atomically replace it, read it back, and clean up or restore the original after a failed replacement.
6. Report the exact file and requested fields. Keep **Resource Manager → Agent access** open so DingDong can validate the external change and synchronize current resources; otherwise reopen Resource Manager or restart DingDong before verifying Prompt/MCP targets and legacy Skill cleanup. An Adapter showing as valid is not by itself proof that synchronization succeeded.

DingDong retains three snapshots per ID: current, previous, and two versions ago. The internal directory is named `Agent Adapter History`. Do not edit the history directory directly. If the user requires that no history copy exist, stop instead of modifying an Adapter; this history cannot be disabled through the Adapter document. Invalid external YAML remains visible in Resource Manager for repair but blocks Agent resource synchronization.

## Configure Reminder Conversation Launchers

This is a user-level file preference, not a Prompt, Skill, MCP, or trigger-group resource. Use it when the user asks DingDong to reopen Claude Code, Gemini CLI, or Kiro conversations in Terminal.app or iTerm.

Resolve `agent-launchers.json` by operating system:

| Platform | File |
|---|---|
| macOS | `~/Library/Application Support/DingDong/agent-launchers.json` |
| Windows | `%APPDATA%\DingDong\agent-launchers.json` |
| Linux | `~/.local/share/DingDong/agent-launchers.json` |

The root must contain `"schemaVersion": 1`. Optional `defaults` settings apply globally, and entries under `agents` override them. The only supported Agent keys are `codex`, `claude-code`, `cursor`, `gemini-cli`, and `kiro`. Each settings object accepts only:

- `"macosTerminal"`: `"terminal"` or `"iterm"`
- `"itermOpenMode"`: `"new-window"` or `"new-tab"`

For example, make DingDong reopen Claude Code in a new tab of the current iTerm window:

```json
{
  "schemaVersion": 1,
  "agents": {
    "claude-code": {
      "macosTerminal": "iterm",
      "itermOpenMode": "new-tab"
    }
  }
}
```

When modifying this file:

1. Confirm the Agent runs on the same machine as the DingDong installation.
2. Read the entire existing file, or start with `{"schemaVersion": 1}` if it does not exist.
3. If the existing file is invalid, has duplicate JSON keys, uses another schema version, or contains unsupported fields or values, stop and report the conflict instead of overwriting it. Rebuild it or remove an unknown field only after the user explicitly authorizes the exact data loss.
4. Preserve unrelated defaults and Agent entries. Change only fields the user requested.
5. Require the target to be absent or a regular non-symlink file inside the expected DingDong directory. Write valid JSON to a uniquely named regular temporary file in the same directory. Re-read the target immediately before replacement and stop on concurrent changes. Preserve its permissions where supported, then atomically replace the target, read it back, and clean up or restore the original after failure.
6. Report the exact file and effective setting. Ask the user to click a matching DingDong reminder for real validation.

DingDong reloads the file for every open action, so no restart is required. A missing file means Terminal.app with a new window on macOS. With iTerm `new-tab`, DingDong creates a tab in the current window, or a new window if none exists. Invalid JSON, unknown fields, unknown Agent keys, or unsupported values make the open action fail instead of being silently ignored. If iTerm is selected but unavailable, do not silently switch to Terminal.app.

These settings currently affect macOS CLI launchers for Claude Code, Gemini CLI, and Kiro. Codex and Cursor use application links, and Windows continues to use `wt.exe`. The configuration chooses where to create a resumed session; it does not locate or focus an original terminal tab.

## Capability Map

| Intent | DingDong representation |
|---|---|
| Policy or instruction | Prompt resource |
| Agent procedure | Skill resource or online GitHub Skill |
| Tool connection | MCP resource |
| Project/repository scope | Trigger group with OR-ed rules |
| SKU/domain ownership | Resource tags, title, and group |
| Reusable clipboard item | Alias/tag or promoted resource |
| Agent MCP/Prompt targets and legacy Skill cleanup locations | User-level Agent Adapter YAML |
| Reminder conversation destination | User-level `agent-launchers.json` |
| Completion/attention signal | `/ding` or `dingdong_notify` |

## Guardrails

- Do not edit `resource-library.json` or `trigger-groups.json` directly.
- Use the write tools only after the user explicitly asks DingDong to change configuration.
- Ask before destructive deletion. Deleting a trigger group detaches it from every resource.
- Keep clipboard content hidden unless the user explicitly requests it; sensitive content requires separate explicit consent.
- Treat `contains` as case-insensitive substring matching, not a path-segment boundary check.
- Strict project Skill loading requires an `equals` rule with an existing exact absolute project path.
- Strict scope controls DingDong's dynamic catalog and load endpoints only. Detect and disclose any separate user-owned native copy of the same Skill before claiming that other projects cannot use it.
- Never treat Skill or MCP candidate summaries as Prompt instructions.
- Never place commands, scripts, Hooks, tokens, or environment variables in Agent Adapter YAML.
- Do not edit the `Agent Adapter History` directory directly.
- Never put arbitrary commands, scripts, tokens, environment variables, workspace paths, or conversation IDs in `agent-launchers.json`.
