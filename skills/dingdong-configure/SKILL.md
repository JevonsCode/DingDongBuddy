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
| Skill | Enabled Skills are mirrored as native Skill packages. The bridge returns only candidate metadata until full content is requested. | Match the Skill description first; load or use it only when the task fits. A Skill summary is not an instruction. |
| MCP | Enabled MCP servers are written into the client's native MCP configuration. The bridge returns only candidate metadata. | Call a configured MCP tool only when the task needs it. MCP availability is not an instruction and does not require a call every turn. |

Activation and trigger groups filter bridge routing. In the current app, enabled native Skills and MCP servers remain globally available to the client; the Agent still decides whether to load a Skill or call an MCP tool.

## Workflow

1. Locate the active loopback port, call `GET /health`, then inspect `GET /agent/capabilities`.
2. Read before writing. Search `GET /library?q=...` and list `GET /library/trigger-groups`; update a matching object instead of duplicating it.
3. Model the request:
   - Store behavioral policy as a `prompt`.
   - Store reusable procedures as a `skill` with valid `SKILL.md` content.
   - Store connection settings as an `mcp` resource.
   - Model a SKU, service, environment, or team as tags/group metadata; DingDong has no first-class SKU type.
   - Model where a resource applies with a trigger group, then attach its ID through `triggerGroupIds`.
4. Create or patch the trigger group before attaching it to a resource. Never invent an unknown trigger-group ID.
5. Verify with `POST /agent/bridge` using representative task text, `workspacePath`, and `repositoryUrl`. Check both a matching and non-matching context.

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
- Ask before destructive deletion. Deleting a trigger group detaches it from every resource.
- Keep clipboard content hidden unless the user explicitly requests it; sensitive content requires separate explicit consent.
- Treat `contains` as case-insensitive substring matching, not a path-segment boundary check.
- Never treat Skill or MCP candidate summaries as Prompt instructions.
