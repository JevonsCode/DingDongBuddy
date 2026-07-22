# DingDong Agent API Reference

Use JSON over DingDong's local loopback HTTP service. Keep DingDong running.

## Locate the service

Read the active port from:

- macOS: `~/Library/Application Support/DingDong/api-port`
- Windows: `%APPDATA%\DingDong\api-port`
- Linux: `~/.local/share/DingDong/api-port`

Set `BASE=http://127.0.0.1:<port>`, then call `GET $BASE/health` and `GET $BASE/agent/capabilities`. Do not guess the default port when the port file exists.

## Configuration endpoints

| Method and path | Purpose |
|---|---|
| `GET /library?q=...&type=prompt` | Search resources |
| `POST /library` | Create a resource |
| `POST /library/skills/install` | Idempotently install a complete GitHub or local Skill package |
| `GET /library/{id}?mode=full` | Read one resource |
| `PATCH /library/{id}` | Patch a resource |
| `DELETE /library/{id}` | Delete after confirmation |
| `GET /library/trigger-groups` | List scopes |
| `POST /library/trigger-groups` | Create a scope |
| `POST /library/trigger-groups/upsert` | Idempotently create or replace an exact scope by name |
| `PATCH /library/trigger-groups/{id}` | Patch a scope |
| `DELETE /library/trigger-groups/{id}` | Delete and detach a scope |
| `POST /library/{id}/scope` | Replace scope IDs and optionally enforce project-native Skill isolation |
| `POST /agent/bridge` | Verify task and project routing |

A resource accepts `type`, `title`, `content`, `group`, `tags`, `source`, `updateURL`, `pinned`, `enabled`, `activation`, `triggerGroupIds`, and `sortOrder`. User-facing configurable types are `prompt`, `skill`, and `mcp`. Activations are `always`, `taskMatch`, and `manual`.

Online Skills use a GitHub repository, folder, or direct `SKILL.md` link in `updateURL`; `content` must still be a valid `SKILL.md` document. The dedicated install endpoint also accepts an absolute local Skill directory or `SKILL.md` path and copies the complete package into DingDong-managed storage. MCP `content` is a JSON string such as `{"type":"stdio","command":"npx","args":["server"]}` or `{"type":"streamable-http","url":"https://example.com/mcp","bearerTokenEnvVar":"TOKEN"}`.

## Direct MCP configuration tools

Prefer these tools over manually composing loopback HTTP:

| Tool | Required input | Result |
|---|---|---|
| `dingdong_install_skill` | `source` | Creates or updates one complete Skill and returns its resource ID; a new resource stays disabled until scope binding succeeds |
| `dingdong_upsert_trigger_group` | `name`, plus `projectPath` and/or `repositoryUrl` | Creates or updates one exact trigger group and returns its ID |
| `dingdong_bind_resource_scope` | `resourceId`, `triggerGroupIds` | Replaces the binding; Skills default to `strictProjectSkill: true` |

For a strict project Skill, every bound rule must be an existing exact absolute `projectPath` using the `equals` operator. Do not mix in repository or `contains` rules because trigger-group rules are OR-ed. DingDong copies that Skill only into the selected project's native Skill directories and removes its DingDong-managed global copies.

Strict scope cannot remove a separate user-owned copy that already lives in a client's user-global native Skill directory. Inspect a local source before promising isolation; if it is such a copy, ask the user to move/remove it or install from a neutral directory/GitHub source. Never delete that source without explicit permission.

## Runtime delivery

- **Prompt:** `dingdong_bridge` includes every active Prompt in full and marks it as required instruction content. Global always-on Prompts without a trigger group are also injected directly into DingDong's managed `~/.codex/AGENTS.md` and `~/.claude/CLAUDE.md` blocks. Claude Code receives only these static global Prompts through its native file; routed Prompts still require bridge delivery.
- **Skill:** the bridge returns summary metadata. Match its description first, then fetch the complete Skill with `dingdong_load_skill` or use the synchronized native Skill package. Unscoped Skills are global; strict project Skills are project-native only. Do not execute a Skill summary as an instruction.
- **MCP:** the bridge returns summary metadata and the enabled server is synchronized to native client configuration. Call its tools only when needed; do not interpret an MCP summary as an instruction or mandatory call.

Trigger groups and activation rules filter bridge candidates. MCP servers and unscoped Skills remain globally available. Strict project Skills are synchronized only below each exact project root, so their native availability follows the configured project boundary.

## Trigger groups

Create the trigger group first:

```http
POST /library/trigger-groups
Content-Type: application/json

{
  "name": "Checkout project",
  "rules": [
    {"field":"projectPath","operator":"contains","value":"checkout"},
    {"field":"repositoryUrl","operator":"equals","value":"https://github.com/acme/checkout.git"}
  ]
}
```

Rules are OR-ed. Fields are `projectPath` and `repositoryUrl`; operators are `equals` and `contains`. Matching is trimmed and case-insensitive. Path separators are normalized, but `contains` remains substring matching. Prefer an exact repository URL when a strict boundary matters.

Use the returned group `id` when creating a policy for a business object such as a SKU:

```http
POST /library
Content-Type: application/json

{
  "type": "prompt",
  "group": "Checkout policies",
  "title": "SKU sku-pro pricing policy",
  "content": "Before changing the price of sku-pro, check region and effective date.",
  "tags": ["sku:sku-pro", "policy", "pricing"],
  "source": "Agent",
  "enabled": true,
  "activation": "always",
  "triggerGroupIds": ["<returned-group-id>"]
}
```

Verify positive and negative contexts:

```http
POST /agent/bridge
Content-Type: application/json

{
  "task": "change sku-pro price",
  "workspacePath": "/work/checkout/service",
  "repositoryUrl": "https://github.com/acme/checkout.git",
  "expand": "prompts"
}
```

Confirm the group ID appears in `context.matchedTriggerGroupIds` and the policy appears in `active.prompts`. Repeat with an unrelated path and repository; the scoped policy must be absent.

## Clipboard and operational capabilities

- Inspect counts with `GET /clipboard/overview`, groups with `GET /clipboard/groups`, and metadata with `GET /clipboard/history`.
- Patch a record's `title`, `group`/`groups`, `tags`, or `pinned` through `PATCH /clipboard/{id}`.
- Promote a record with `POST /clipboard/promote/{id}` or assign snippet aliases with tags shaped as `alias:name`.
- Clipboard classification-rule editing and desktop preferences are currently UI-only; do not claim they are Agent-configurable.
- Use `/agent/memory`, sessions, bundles, and handoffs for coordination records, not for resource policy.
- Use `/ding` only for a completed, blocked, or attention-required outcome.
