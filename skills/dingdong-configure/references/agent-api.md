# DingDong Agent API Reference

Use JSON over DingDong's local loopback HTTP service. Keep DingDong running.
Every `POST` and `PATCH` request must send `Content-Type: application/json`.

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
| `PUT /library/skills/{id}/delivery` | Atomically set one Agent delivery plane, master state, project paths, and independent Hook switch |
| `GET /library/skills/{id}/deployments` | Read desired state, observed native copies, and in-progress recovery operations |
| `POST /library/skills/{id}/reconcile` | Retry idempotent deployment/removal reconciliation |
| `GET /library/{id}?mode=full&workspacePath=...` | Read one enabled, in-scope resource |
| `PATCH /library/{id}` | Patch a resource |
| `DELETE /library/{id}` | Delete after confirmation |
| `GET /library/trigger-groups` | List scopes |
| `POST /library/trigger-groups` | Create a scope |
| `POST /library/trigger-groups/upsert` | Idempotently create or replace an exact scope by name |
| `PATCH /library/trigger-groups/{id}` | Patch a scope |
| `DELETE /library/trigger-groups/{id}` | Delete and detach a scope |
| `POST /library/{id}/scope` | Replace scope IDs and optionally enforce exact-project Skill loading |
| `POST /agent/bridge` | Verify task and project routing |
| `GET /agent/skills/load?id=...&workspacePath=...` | Load a scoped Skill's complete `SKILL.md` by ID or name |
| `GET /agent/skills/file?id=...&path=...&workspacePath=...` | Read one referenced package file by Skill ID or name |

A resource accepts `type`, `title`, `content`, `group`, `tags`, `source`, `updateURL`, `pinned`, `enabled`, `activation`, `triggerGroupIds`, and `sortOrder`. User-facing configurable types are `prompt`, `skill`, and `mcp`. Activations are `always`, `taskMatch`, and `manual`.

Online Skills use a GitHub repository, folder, or direct `SKILL.md` link in `updateURL`; `content` must still be a valid `SKILL.md` document. The dedicated install endpoint also accepts an absolute local Skill directory or `SKILL.md` path and copies the complete package into DingDong-managed storage. MCP `content` is a JSON string such as `{"type":"stdio","command":"npx","args":["server"]}` or `{"type":"streamable-http","url":"https://example.com/mcp","bearerTokenEnvVar":"TOKEN"}`.

## Direct MCP configuration tools

Prefer these tools over manually composing loopback HTTP:

| Tool | Required input | Result |
|---|---|---|
| `dingdong_install_skill` | `source` | Creates or updates one complete Skill and returns its resource ID; a new resource stays disabled until scope binding succeeds |
| `dingdong_upsert_trigger_group` | `name`, plus `projectPath` and/or `repositoryUrl` | Creates or updates one exact trigger group and returns its ID |
| `dingdong_bind_resource_scope` | `resourceId`, `triggerGroupIds` | Replaces trigger-group scope for dynamic delivery; an exact project Skill scope is enforced by the route without exposing its legacy persistence flag |
| `dingdong_set_skill_delivery` | `resourceId`, `agentId`, `mode` | Selects exactly one of `dynamic`, `nativeUser`, or `nativeProject`; project paths and Hooks are validated atomically |
| `dingdong_get_skill_deployments` | `resourceId` | Returns desired and observed deployment/recovery state |
| `dingdong_reconcile_skill` | `resourceId` | Safely retries only DingDong-owned installation or removal work |

For a strict project Skill, every bound rule must be an existing exact absolute `projectPath` using the `equals` operator. Do not mix in repository or `contains` rules because trigger-group rules are OR-ed. DingDong includes that Skill only in matching Bridge catalogs, and both full-content and package-file loads re-check the same scope.

Strict dynamic scope does not control a separate user-owned copy that already lives in a client's native Skill directory. Warn about that independent copy before promising a global off switch. DingDong native reconciliation also refuses to overwrite or delete that copy because it has no matching ownership receipt.

## Runtime delivery

- **Prompt:** native instruction files contain only the persistent Bridge bootstrap. `dingdong_bridge` includes every active Prompt in full and marks the successful response as the authoritative replacement snapshot for the current task.
- **Dynamic Skill:** each successful Bridge response contains the authoritative complete set of every valid, enabled, scope-matched dynamic Skill for the current workspace as `id`, `name`, and `description` only. Match a returned description first, then fetch the complete `SKILL.md` by ID or name with `dingdong_load_skill`; read only referenced package files with `dingdong_read_skill_file`. Every load re-checks enabled state and scope.
- **Native Skill:** DingDong copies the complete package to the selected Agent's user or exact-project discovery root and withholds it from Bridge catalog/load routes. Relative scripts, references, assets, and manifests therefore resolve from a real package directory. A receipt owns the deployment; unmanaged same-name content fails closed.
- **MCP:** the bridge returns summary metadata and the enabled server is synchronized to native client configuration. Call its tools only when needed; do not interpret an MCP summary as an instruction or mandatory call.

The Bridge conversation capsule exposes typed items and a light/dark palette: Prompt uses warm orange, Skill blue, and MCP green. Keep the capsule until the final response whenever `conversation.visible` is true. A successful visible `dingdong_load_skill` response returns a replacement `conversation.item` with the same opaque `mergeKey` as its candidate, `confirmedUse: true`, `usage: loaded`, and `marker: "*"`; replace only the item with that merge key and never display the key itself. Only direct full-load evidence earns the marker. A catalog candidate remains unmarked, and the marker is not evidence that every Skill instruction was followed. Codex desktop includes `conversation.line` exactly once as a single Markdown text line. Use the exact Prompt, Skill, and MCP symbols already supplied in `conversation.line` and each item's `lineToken`; these symbols are user-configurable, so never infer or rebuild them. Do not use an image, HTML/XML, inline font, or rendering tool for the footer. Explicitly ANSI-capable terminals use `conversation.presentations.ansi.line`; every other host falls back to `conversation.fallbackLine`.

Trigger groups filter dynamic Skill candidates while Prompt activation rules filter Prompt delivery. Native project paths control on-disk placement instead. A Skill has one delivery plane per Agent, so a native copy and dynamic candidate are never intentionally active together. The resource `enabled` field is the master switch; the optional managed Hook switch is independent and defaults off. Supported Agents discover native Skill changes automatically; recommend a new Agent task to refresh its catalog, and restart the Agent only if the Skill is still missing. Every active, scope-matched MCP and Knowledge candidate is returned as summary metadata. MCP servers remain client-global.

Project-native paths are exact existing absolute directories and are shared across all project-native Agents configured for the same Skill. A Skill cannot mix `nativeUser` and `nativeProject` across Agents. `nativeUser` is Agent-global and cannot carry trigger groups, project paths, or managed project Hooks. The managed Hook integration currently supports Impeccable on Codex project-native delivery only. New or changed Hook definitions remain pending until the user reviews them with `/hooks`; DingDong does not calculate, store, or transfer Codex's opaque trust hash.

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
- Full clipboard content is available only when the user enables **Allow Agents
  to read clipboard content** in DingDong Settings and the request explicitly
  sets `includeContent=true`. Sensitive records additionally require
  `includeSensitiveClipboard=true`.
- Do not retry `403` clipboard-content responses or attempt to bypass the
  setting through capture, collection, or promotion; ask the user to enable the
  setting when the task genuinely requires content.
- Patch a record's `title`, `group`/`groups`, `tags`, or `pinned` through `PATCH /clipboard/{id}`.
- Promote a record with `POST /clipboard/promote/{id}` or assign snippet aliases with tags shaped as `alias:name`.
- Clipboard classification-rule editing and desktop preferences are currently UI-only; do not claim they are Agent-configurable.
- Use `/agent/memory`, sessions, bundles, and handoffs for coordination records, not for resource policy.
- Use `/ding` only for a completed, blocked, or attention-required outcome.
