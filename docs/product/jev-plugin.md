# Jev optional plugin

Jev is an optional built-in DingDong integration. In Resource Manager → Plugins → Jev,
users install Jev, enter their own TypeSafe API key, then explicitly allow paid
calls. The integration ships with DingDong, so installation needs no additional
download, Node runtime, local model, or separate MCP server. It is a DingDong
adapter using TypeSafe's official HTTP API, not a TypeSafe-published plugin.

The tray right-click menu → Plugin market opens the same Plugins workspace.
System selection tools also live there; their existing settings and native
permission controls are preserved.

## User controls

- New installations start uninstalled; installing does not enable calls or
  create an external account. Saving a key also pauses calls until opted in.
- Keys stay in platform secure storage: macOS Keychain (non-shared login
  keychain, no provisioning entitlement required) and the Windows secure-storage
  plugin. Development and production use different key identifiers.
- The explicit connection test sends a short, non-private red-ball example to
  Jev and is billable. Saving, installing, refreshing local usage, and opening
  account billing do not call Jev.
- Disabling prevents new calls. Removing a key disables calls before removal.
  Uninstall removes the key and installation state, retaining accounting history.
  Requests already sent may still complete and be billed.
- No background requests or automatic retries. The user's main Agent model is
  unchanged. Reconnect DingDong MCP after installation to discover Jev tools.
- Existing standalone Jev MCP setups are independent. This plugin does not
  silently import their keys, disable their connections, or merge past usage.

## API and billing

The fixed endpoint is `https://api.typesafe.ai/v1/systemone`, model
`jev-1.13.0`. Jev supplies typed judgments: yes/no probability, choice, and score.
It does not provide a replacement conversational model or execution permission.

The interface links to the [official website](https://typesafe.ai/) and the
TypeSafe account console for current pricing and bills. It does not embed a
price table, claim free calls, or display monetary amounts. The Token ledger
remains independent from other Agent usage. Without a cache counter, the footer
falls back to its original total and the plugin table retains input/output rows. Existing
internal cost estimates are not used by this token-only display.

Sources: [models](https://docs.typesafe.ai/models),
[HTTP API](https://docs.typesafe.ai/api),
[primitives](https://docs.typesafe.ai/primitives),
[secure storage](https://pub.dev/packages/flutter_secure_storage).

## Independent usage

The `jev.sqlite` ledger records a timestamp, source, conversation ID, result
state, API-reported input/output tokens and input-cost estimate. It stores no
request text, answers, credentials, or private file paths. Each request is
persisted as usage-unknown before sending; process crashes and lost responses
therefore do not become free calls. A malformed judgment still records valid
usage reported by the service. Missing input/output usage is explicitly unknown.

The plugin page shows today (device local calendar) and lifetime totals, including
unknown-usage requests. It counts only calls through this device's plugin,
including explicit connection tests; other applications and standalone adapters
are excluded. Requests have no automatic retry.

With the existing conversation-token display preference enabled, Bridge adds
a separate `Jev … Token` suffix for the exact source/conversation. It never adds
Jev tokens to the host Agent total. Calls with no conversation ID remain in
device totals without being assigned to another conversation. Bridge is a
snapshot; subsequent Jev call results also carry current conversation usage.

## Implementation boundaries

- The primary Flutter engine owns `JevService`; Resource Manager auxiliary windows use
  the existing native window channel. Install, key edits, billing opt-in and
  uninstall have no HTTP or MCP write endpoint.
- `GET /plugins/jev/status` is local read-only. POST `check`, `choose`, `score`
  require installed state, a configured key, and billing opt-in on every call.
- DingDong's stdio MCP exposes `dingdong_jev_status`, `dingdong_jev_check`,
  `dingdong_jev_choose`, and `dingdong_jev_score` only while installed. Stale
  tool definitions cannot bypass the runtime gate.
- Request and response sizes are bounded at 24 KB and 256 KiB respectively.
  Timeout is 25 seconds, redirects are refused, and errors omit raw bodies and
  credential-bearing exception strings. The fixed model is not auto-upgraded.
- Price changes require an explicit adapter update; older estimates are stored
  per request and not retroactively recomputed.

## Validation

Unit/contract tests use explicitly synthetic API responses and temporary or
in-memory stores. They cover opt-in, lifecycle, failure accounting, input/output
validation, MCP discovery and conversation attribution. Widget tests cover key
clearing, duplicate actions, errors, and English/Chinese/Spanish layout. The
native secure-storage integration test uses a unique disposable test key and
never reads a user's key or sends a Jev request.

Released in DingDong 1.6.0. Installing the plugin does not purchase credits or migrate an existing
standalone account configuration. Production deployment remains the normal
DingDong release process.
