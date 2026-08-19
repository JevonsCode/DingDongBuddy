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
| Skill | Each Agent has exactly one delivery plane per Skill: `dynamic`, `nativeUser`, or `nativeProject`. Dynamic delivery uses the Bridge catalog/load protocol; native delivery installs the complete package into that Agent's configured discovery root. | For a dynamic candidate, match its description, call `dingdong_load_skill` for the full `SKILL.md`, and read only referenced package files with `dingdong_read_skill_file`. For native delivery, let the Agent discover and run the on-disk package; do not also load it through DingDong. |
| MCP | Enabled MCP servers are written into the client's native MCP configuration. The bridge returns candidate metadata plus stable managed-server provenance. | Call a configured MCP tool only when the task needs it. After a real call reaches a terminal result, confirm that MCP once with `dingdong_confirm_mcp_use`; availability alone is never use evidence. |

Enabled state and trigger groups filter the dynamic Skill catalog, and every dynamic Skill and supporting-file load re-checks them so an old name or ID cannot bypass a disabled or out-of-scope resource. Native Skills are copied as complete receipt-owned packages so relative scripts, references, assets, and Agent manifests keep their original layout. Delivery planes are mutually exclusive: a native-mode Skill is withheld from Bridge catalog and load routes, including while deployment/removal state is uncertain. Every active, scope-matched MCP and Knowledge candidate is returned as summary metadata. Unscoped MCP servers are synchronized to every configured client; source-scoped MCP servers are synchronized only to matching native client configurations.

The bridge also returns a compact canonical `conversation.capsule` plus text presentations when Prompt, Skill, or MCP resources are exposed. When `conversation.visible` is true, keep that capsule until the final user-visible response so later usage evidence can be merged. A successful visible `dingdong_load_skill` response returns a replacement `conversation.item` with the same opaque `mergeKey` as its candidate, `confirmedUse: true`, and `marker: "*"`; replace only that matching item. Each active MCP summary includes its managed `serverName` and Codex `toolNamePrefix`. After an actual configured MCP tool call reaches a terminal result—success or error—call `dingdong_confirm_mcp_use` exactly once for that MCP resource with its active `id`, `serverName`, and the exact called `toolName`, then replace only the item matching its returned `conversation.item`. Never confirm availability, discovery, or an uncalled tool. A Skill marker means loaded; an MCP marker means called, not necessarily succeeded. Prompt items remain unmarked because delivery cannot prove semantic compliance. The merge key is merge-only metadata and must never be displayed. Codex desktop includes the current merged footer exactly once as a single Markdown text line. Use the exact user-configurable symbols and item `lineToken` values returned by DingDong; never infer them. The initial `conversation.line` is already final only when no item was replaced. The capsule palette keeps Prompt warm orange, Skill blue, and MCP green. Do not use an image, HTML/XML, inline font, or rendering tool for this footer. Explicitly ANSI-capable terminals use current merged ANSI tokens; every other host uses current merged plain-text tokens. Show only truncated titles and truthful markers; never display resource content, descriptions, IDs, server names, tool names, or merge keys.

## Workflow

1. Prefer the native DingDong MCP tools. If the write tools are unavailable, locate the active loopback port, call `GET /health`, then inspect `GET /agent/capabilities` and use the equivalent HTTP endpoints.
2. Read before writing. Call `dingdong_search_assets` and inspect existing scopes before creating anything; update or reuse a matching object instead of duplicating it. Use `dingdong_create_resource` only for a new Prompt or MCP, `dingdong_update_resource` for an existing Prompt or MCP, and `dingdong_install_skill` for a Skill package.
3. Model the request:
   - Store behavioral policy as a `prompt`.
   - Store reusable procedures as a `skill` with valid `SKILL.md` content and an optional complete package.
   - Store connection settings as an `mcp` resource.
   - Model a SKU, service, environment, or team as tags/group metadata; DingDong has no first-class SKU type.
   - Model where a resource applies with a trigger group, then attach its ID through `triggerGroupIds`.
4. Create or patch the trigger group before attaching it to a resource. Never invent an unknown trigger-group ID.
5. Verify with `dingdong_bridge` using representative task text, `workspacePath`, `repositoryUrl`, and `source` when relevant. Check both a matching and non-matching context.

For a new Prompt or MCP, keep it disabled while creating and binding its requested scope, then enable it with `dingdong_update_resource`. Preserve omitted fields during updates. Never create a second resource when search returns the intended existing item.

## Skill Delivery and Switches

Keep these controls separate:

- `enabled` is the resource master switch. Turning it off removes only DingDong-owned native copies and suppresses dynamic delivery; it never deletes an external same-name Skill.
- Delivery is selected per Agent and is not another enable switch. `dynamic` is Bridge-managed, `nativeUser` is Agent-global, and `nativeProject` is installed under each exact project root.
- A Skill must not mix `nativeUser` and `nativeProject` across Agents. User-native delivery is global and cannot retain trigger-group/project scope; project-native Agents for one Skill share the same exact project set.
- All project-native Agents for one Skill share the same exact project-path set. Do not retarget one Agent without changing the shared scope intentionally.
- The Hook switch is independent, defaults off, and currently supports only Impeccable with Codex project-native delivery. A new or changed Codex Hook still requires review in `/hooks`; DingDong never invents or migrates Codex's opaque trust hash.

Supported Agents discover native Skill changes automatically. A native change is durable on disk, but an already-running task may still have its old catalog: report the state as deployed or removed, recommend a new Agent task for verification, and restart the Agent only if the Skill is missing there. Never describe restart as required, or claim that turning off a native Skill makes the current task forget content it already loaded.

## Install a Skill for One Project

When the user asks to install “this Skill through DingDong for project X”:

1. Resolve the Skill source to either an official GitHub repository/folder/`SKILL.md` URL or an absolute local Skill directory/`SKILL.md` path. Resolve project X to its existing exact absolute project path. Do not guess either value. If a separate native Skill with the same name already exists in an Agent's global directory, warn that DingDong's switch cannot disable that independent copy.
2. Search for the Skill first. If it is not already managed by DingDong, call `dingdong_install_skill`. Keep the returned resource `id`; a new install remains disabled.
3. Call `dingdong_set_skill_delivery` with that resource ID, the exact Adapter `agentId`, `enabled: true`, `mode: "nativeProject"`, the existing absolute project path in `projectPaths`, and `hooksEnabled: false` unless the user separately requested the supported Hook integration.
4. Call `dingdong_get_skill_deployments`. The expected Agent/project deployment must be observed with no in-progress operation. If reconciliation failed for a recoverable reason, call `dingdong_reconcile_skill` once and inspect status again; never overwrite an unmanaged conflict.
5. Start a new Agent task in the target project and verify native discovery and one representative relative script/reference path. The Skill must not also appear in DingDong's dynamic Bridge catalog. Check an unrelated project to confirm that no project-native copy was created there.

These writes are idempotent: canonical source plus identical package digest reuses the existing resource/artifact, and an identical delivery request performs no write. A different source declaring the same Skill name is a conflict rather than an overwrite. Native deployment refuses user-owned same-name directories, invalid ownership receipts, symlinks, unsafe paths, and destination collisions.

For a dynamic project Skill instead, set that Agent's delivery to `dynamic`, create one exact-project trigger group with `dingdong_upsert_trigger_group`, and bind it with `dingdong_bind_resource_scope`. Then verify matching and unrelated Bridge catalogs plus full loads. Dynamic scope and native project placement are different delivery mechanisms; never configure both for the same Agent/Skill.

## Configure Agent Adapters

Agent Adapters are user-level declarative YAML files for Agent detection, MCP and Prompt targets, and native Skill deployment roots. DingDong uses the Skill roots both for receipt-owned native delivery and for legacy cleanup/external collision warnings. Use Adapters when the user asks to add a client or change those Agent integration paths. Do not use Adapters for conversation terminal selection; that is `agent-launchers.json`.

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
| Agent MCP/Prompt targets and native Skill deployment roots | User-level Agent Adapter YAML |
| Reminder conversation destination | User-level `agent-launchers.json` |
| Completion/attention signal | `/ding` or `dingdong_notify` |

## Guardrails

- Do not edit `resource-library.json` or `trigger-groups.json` directly.
- Use the write tools only after the user explicitly asks DingDong to change configuration.
- Ask before destructive deletion. Deleting a trigger group detaches it from every resource.
- Keep clipboard content hidden unless the user explicitly requests it; sensitive content requires separate explicit consent.
- Treat `contains` as case-insensitive substring matching, not a path-segment boundary check.
- Strict project Skill loading requires an `equals` rule with an existing exact absolute project path.
- Strict trigger-group scope controls DingDong's dynamic catalog/load endpoints. Project-native scope instead controls exact on-disk deployment targets. Detect and disclose any separate user-owned native copy before claiming that DingDong's switch controls every instance.
- Never deliver the same managed Skill through both Bridge and a native root for the same Agent/workspace.
- Never overwrite, adopt, or delete a native Skill or Hook entry without a matching DingDong ownership receipt and unchanged expected content.
- Treat native deployment success/removal and current Agent-session visibility as separate states; request a new task when discovery must be verified.
- Never treat Skill or MCP candidate summaries as Prompt instructions.
- Never place commands, scripts, Hooks, tokens, or environment variables in Agent Adapter YAML.
- Do not edit the `Agent Adapter History` directory directly.
- Never put arbitrary commands, scripts, tokens, environment variables, workspace paths, or conversation IDs in `agent-launchers.json`.
