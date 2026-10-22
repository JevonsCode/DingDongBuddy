# Optional AI+

Open **Resource Manager → AI+**. Clipboard insights, resource usage
optimization, progressive disclosure advice, Token suggestions and proactive check-ins each
have their own switch. All start off. Opening the workspace does not contact a
model. Suggestions are read-only; review links open the existing clipboard or
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

The AI page shows today's internal usage, all-time recorded usage, and the last
request in this window. Model-assisted analysis, resource selection and connection tests
record numeric API usage; local analysis and check-ins do not call a model.
The dedicated ledger stores only a
random receipt ID, operation, time and numeric usage, never request content or keys.
It survives restarts and ignores duplicate receipt IDs.
Opening AI+, returning to the app, or using the usage refresh icon reads the local
ledger again, including receipts from background selection; it makes no model request.

**Include in global statistics** defaults off, including for existing settings.
Internal history is always visible separately. Enabling the switch includes all
recorded internal history as the DingDong source in global totals, filters and
CSV export; disabling it excludes that source without deleting or reimporting
history. New receipts and switch changes invalidate the cached global view.
History begins with requests recorded by this version; past calls are not guessed.

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
