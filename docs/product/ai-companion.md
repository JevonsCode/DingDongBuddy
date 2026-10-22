# Optional AI+

Open **Resource Manager → AI+**. Clipboard insights, resource usage
optimization, progressive disclosure advice, Token suggestions and proactive check-ins each
have their own switch. These capabilities start off. The **Insights and suggestions**
tab defaults to automatic analysis of enabled categories; **Settings** contains the
category and model configuration. Analysis starts with the resource window and
checks every 30 minutes while that window engine is running. Changed settings are
debounced for five seconds. Unchanged analysis inputs are skipped, including after
restart. Turn **Automatic analysis** off for manual-only operation. Model requests
require the separate model-analysis opt-in. Suggestions are read-only; review links open the existing clipboard or
resource editor so changes remain explicit.

Clipboard and Token analysis cover the local calendar day; resource usage
counters are cumulative. The local analysis limits its clipboard/resource input
to 500 items and cloud resource metadata to 100 items.

Local insights use deterministic rules. They identify frequently copied or
repeated text, ungrouped items, resources repeatedly offered without evidence of
use, large always-on Prompts, and measured Token patterns. A Skill load, Prompt
activation, MCP invocation, and candidate match are different measurements.
Suggestions about task matching and on-demand loading do not automatically
rewrite Agent configuration or change a client's tool-discovery protocol.

Configure an **OpenAI Chat Completions** or **Anthropic Messages** service and
model to enable model-assisted analysis. The protocol defaults to **Auto**,
including existing settings. Auto starts with OpenAI (or Anthropic for a complete
`/messages` URL) and tries the other protocol only after HTTP 404/405. Authentication
failures, rate limits, timeouts and server errors are not retried. You can select
one protocol explicitly when the service requires it.

Both HTTP and HTTPS are accepted for explicitly configured services, including
company gateways and loopback proxies. HTTP traffic is unencrypted; use it on
networks you trust. URLs cannot embed credentials, query parameters or fragments.
The endpoint accepts a service root, an API base such as `/v1`, or a complete
`/chat/completions` or `/messages` URL. A root OpenAI URL gains `/v1/chat/completions`;
custom OpenAI bases gain `/chat/completions`. Anthropic bases gain `/v1/messages`
unless they already end in `/v1` or `/messages`. For example:

- Kiro proxy: `http://127.0.0.1:3456`, Auto or Anthropic, using a model ID provided by the proxy.
- Company Anthropic gateway: `http://gateway.example.com/coding-plan`,
  Anthropic, producing `/coding-plan/v1/messages`. The gateway's model access and
  credentials must still be valid; accepting a URL does not verify upstream access.

Remote providers require the user's own API key, saved in the operating system's
secure storage. Loopback providers may leave it empty. Changing the endpoint
clears the previous provider's key unless a new key is supplied. Anthropic requests
send `anthropic-version: 2023-06-01`, Bearer authorization and `x-api-key` for
compatible proxies, plus a random per-client `X-Claude-Code-Session-Id` correlation
header required by some gateways. It does not reuse a Claude conversation or user
identity. Requests use a fixed Content-Length for gateways that reject chunked
JSON. System instructions are sent separately from conversation
turns, and only returned text blocks are displayed. See the
[Anthropic Messages API](https://platform.claude.com/docs/en/api/messages/create).
**Test connection** makes an explicit, constant-text model request.

Cloud analysis is separately opt-in and sends only bounded, whitelisted
metadata: record counts, anonymous resource references and usage counters, and
numeric Token aggregates with data-availability flags. Clipboard text, resource
contents and titles, local identifiers, paths, images, and file contents are
excluded structurally. Local insights remain available without a provider.
Analysis does not upload files or grant model access to tools.

Analyses are retained in local `ai-insights.sqlite3`, with 20 entries per page,
newest first and automatic/manual source labels. Local and model results from one
analysis update the same entry. The previous latest report is migrated on first
load. Disabling automatic analysis does not erase history.

Keychain failures are reported separately from preference failures; local settings
and insights remain available. The app never falls back to plaintext key storage.

Persisted reports contain suggestion codes and local references, plus filtered
model summaries when requested, rather than clipboard or resource contents.

Proactive check-ins run locally while the AI page is open and opted in. They
offer an occasional break reminder; page-open time is not evidence of continuous
work. A check-in does not trigger model requests or inspect clipboard content.
Closing the page stops its timer.

## Automatic resource selection

**AI+ → Automatic resource selection** is a separate switch, off by default.
When an Agent calls DingDong Bridge, the configured model can narrow the eligible
Skill and task-matched MCP catalog before it is returned to the Agent. This does
not intercept messages before Codex's own model receives them, remove native MCP
schemas already loaded by a client, or modify resource configuration.

The selector receives the current task, optional caller-provided `taskContext`,
and candidate titles/descriptions. It never reads conversation history itself.
Task and context are each limited to 4,000 characters; at most 64 candidates are
sent, with 120-character titles and 500-character descriptions. Resource bodies,
MCP connection configuration, local IDs, workspace paths and conversation IDs
are excluded from the model input. Known sensitive formats are screened locally;
the user should still choose a provider suitable for their task text.

Prompts and always-enabled MCP references remain mandatory. Explicitly named
eligible Skills and MCP references are retained. Disabled, manual or out-of-scope
MCP references cannot be enabled by the selector. Every subsequent Skill load
still validates its current scope and availability. Diagnostic `expand=all`
does not run selection.

Code validates returned IDs against the candidate set. Invalid output, timeout,
missing provider or unsupported inputs fall back to the deterministic catalog.
A bounded in-memory cache reuses identical decisions and failures; task, context,
catalog, scope or provider changes invalidate the matching entry. No selection
transcript is appended to the main conversation. Actual Token savings depend on
the client and task; this feature does not promise a measured reduction.

The four insight categories are shown at the top of AI+. **Analyze now** stays
visible while settings scroll. Changing analysis switches changes the scope of
the next run; it does not fabricate a new report.

Provider requests have time and size limits and do not follow redirects.
Failures display a stable diagnostic category without echoing provider response
bodies or API keys. Configured models and providers may differ in which Chat
Completions parameters they support.


## Internal token accounting

Open **Token usage** to inspect DingDong's own API usage alongside supported
Agent history. **Include DingDong usage** defaults off and is saved across
restarts. **DingDong only** temporarily limits the page to internal receipts and
disables the Agent picker; leaving that mode restores the prior Agent selection
and inclusion preference. The multi-select Agent menu lists supported local log
readers (Codex, Claude Code and Pi) with their observed availability, not clients
that have connected to DingDong.

Summary counts, calendar cells, day details, coverage and CSV use the selected
sources. The calendar displays the selected year within the chosen date range.
Internal feature rows summarize resource selection, model analysis and connection
tests for the selected period. CSV includes each receipt group's feature name.
Missing components remain unknown. The separate numeric ledger survives restarts
and ignores duplicate receipt IDs; it stores no request content or keys. Changing
filters reads the loaded local data and never calls a model. Refreshing or
reopening Token usage reloads local history, including background selection.
Recording begins with requests observed by this version; past calls are not guessed.

Counts come from the configured service, not local text-length estimates.
OpenAI prompt tokens include cache reads; Anthropic input adds reported cache
reads and creation to fresh input. Reasoning is not added to total output again.
Unreported components remain unknown, and partial totals are marked as lower
bounds. The protocol's absence of an OpenAI cache-creation category is zero;
missing cache-read details are unknown. Responses with readable usage are counted
before content validation, even if the answer cannot be displayed. Transport
failures, invalid JSON and error bodies have no measured receipt here; this is
not an invoice or a guarantee of every upstream billed token. Storage errors are
shown separately and do not fail or retry a successful model answer.
