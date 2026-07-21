---
name: dingdong-configure
description: Use when a user asks an Agent to configure DingDong resources, project or repository trigger scopes, policies, prompts, Skills, MCP servers, or clipboard organization, including business objects such as SKUs that need reusable Agent rules.
---

# Configure DingDong

## Overview

Configure DingDong through its loopback Agent API. Translate the user's intent into reusable resources and project-aware trigger groups, then verify the result through the same bridge Agents use at task start.

Canonical source: <https://github.com/JevonsCode/DingDongBuddy/tree/main/skills/dingdong-configure>

## Runtime Semantics

Keep the three resource types distinct:

| Type | How it reaches the Agent | What the Agent does |
|---|---|---|
| Prompt | A global always-on Codex Prompt is injected into DingDong's managed `AGENTS.md` block. Routed Prompts are returned in full by `dingdong_bridge`. | Apply every active Prompt automatically as a required instruction. |
| Skill | Enabled unscoped Skills are mirrored globally. Strict project-scoped Skills are mirrored only into that project's native Skill directories. The bridge returns only candidate metadata until full content is requested. | Match the Skill description first; load or use it only when the task fits. A Skill summary is not an instruction. |
| MCP | Enabled MCP servers are written into the client's native MCP configuration. The bridge returns only candidate metadata. | Call a configured MCP tool only when the task needs it. MCP availability is not an instruction and does not require a call every turn. |

Activation and trigger groups filter bridge routing. MCP servers remain client-global because native MCP configuration is global. A Skill bound with strict project scope is absent from global Skill directories and is copied only to project-native Skill directories such as `.agents/skills`, `.claude/skills`, `.cursor/skills`, and `.gemini/skills`.

## Workflow

1. Prefer the native DingDong MCP tools. If the write tools are unavailable, locate the active loopback port, call `GET /health`, then inspect `GET /agent/capabilities` and use the equivalent HTTP endpoints.
2. Read before writing. Call `dingdong_search_assets` and inspect existing scopes before creating anything; update or reuse a matching object instead of duplicating it.
3. Model the request:
   - Store behavioral policy as a `prompt`.
   - Store reusable procedures as a `skill` with valid `SKILL.md` content.
   - Store connection settings as an `mcp` resource.
   - Model a SKU, service, environment, or team as tags/group metadata; DingDong has no first-class SKU type.
   - Model where a resource applies with a trigger group, then attach its ID through `triggerGroupIds`.
4. Create or patch the trigger group before attaching it to a resource. Never invent an unknown trigger-group ID.
5. Verify with `dingdong_bridge` using representative task text, `workspacePath`, and `repositoryUrl`. Check both a matching and non-matching context.

## Install a Skill for One Project

When the user asks to install “this Skill through DingDong for project X”:

1. Resolve the Skill source to either an official GitHub repository/folder/`SKILL.md` URL or an absolute local Skill directory/`SKILL.md` path. Resolve project X to its existing exact absolute project path. Do not guess either value. If a local source is already inside a user-global native Skill directory and is not a DingDong-managed copy, warn that importing it cannot hide that original global copy; ask the user to move/remove the original or use a neutral/GitHub source before claiming strict isolation.
2. Search for the Skill first. If it is not already managed by DingDong, call `dingdong_install_skill`. Keep the returned resource `id`.
3. Call `dingdong_upsert_trigger_group` with a stable name dedicated to this Skill/project pair and only the exact absolute `projectPath`. Keep the returned group `id`; do not add another OR-ed rule to a strict project Skill group or reuse a shared group's name when its rules would change.
4. Call `dingdong_bind_resource_scope` with the resource ID, that group ID, and `strictProjectSkill: true`.
5. Call `dingdong_bridge` once with the matching workspace and once with an unrelated workspace. The Skill must be a candidate only in the matching context.

These writes are idempotent: installation updates the same source/name, trigger-group upsert reuses its name, and scope binding replaces the resource's group IDs. A newly installed Skill stays disabled until it is successfully bound, so the multi-step workflow does not create a transient DingDong-managed global copy. Strict binding rejects `contains`, repository rules, relative, root, missing, or unknown project scopes. Never emulate strict scope with a global Skill plus a routing hint.

## Capability Map

| Intent | DingDong representation |
|---|---|
| Policy or instruction | Prompt resource |
| Agent procedure | Skill resource or online GitHub Skill |
| Tool connection | MCP resource |
| Project/repository scope | Trigger group with OR-ed rules |
| SKU/domain ownership | Resource tags, title, and group |
| Reusable clipboard item | Alias/tag or promoted resource |
| Completion/attention signal | `/ding` or `dingdong_notify` |

## Guardrails

- Do not edit `resource-library.json` or `trigger-groups.json` directly.
- Use the write tools only after the user explicitly asks DingDong to change configuration.
- Ask before destructive deletion. Deleting a trigger group detaches it from every resource.
- Keep clipboard content hidden unless the user explicitly requests it; sensitive content requires separate explicit consent.
- Treat `contains` as case-insensitive substring matching, not a path-segment boundary check.
- Strict project Skill installation requires an `equals` rule with an existing exact absolute project path.
- Strict scope controls DingDong-managed copies only. Detect and disclose any separate user-owned global copy of the same Skill before claiming that other projects cannot use it.
- Never treat Skill or MCP candidate summaries as Prompt instructions.
