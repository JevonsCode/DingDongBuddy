# AI+ resource selection

Open **Resource Manager → AI+** to configure task-driven resource selection and
its model connection. This is one settings page. There is no insight tab, report,
manual analysis button, scheduled analysis or proactive check-in. Opening a window
or saving settings does not invoke a model. Old analysis settings are ignored.

## Resource selection for Agents

**AI+ → Automatic resource selection** is off by default.
When an Agent calls DingDong Bridge, the configured model can narrow the eligible
Skill, task-matched Prompt and MCP catalog before returning it to the Agent. This does
not intercept messages before Codex's own model receives them, remove native MCP
schemas already loaded by a client, or modify resource configuration.

The selector receives the current task, optional caller-provided `taskContext`,
and candidate titles/descriptions. It never reads conversation history itself.
Task and context are each limited to 4,000 characters; at most 64 candidates are
sent, with 120-character titles and 500-character descriptions. Resource bodies,
MCP connection configuration, local IDs, workspace paths and conversation IDs
are excluded from the model input. Known sensitive formats are screened locally;
the user should still choose a provider suitable for their task text.

Always-enabled Prompts and MCP references remain mandatory. Explicitly named
eligible Prompts, Skills and MCP references are retained. Disabled, manual or
out-of-scope Prompts and MCP references cannot be enabled by the selector. Every subsequent Skill load
still validates its current scope and availability. Diagnostic `expand=all`
does not run selection.

Code validates returned IDs against the candidate set. Invalid output, timeout,
missing provider or unsupported inputs fall back to the deterministic catalog.
A bounded in-memory cache reuses identical decisions and failures; task, context,
catalog, scope or provider changes invalidate the matching entry. No selection
transcript is appended to the main conversation. Actual Token savings depend on
the client and task; this feature does not promise a measured reduction.

## Model connection

Configure an OpenAI Chat Completions or Anthropic Messages endpoint and model.
Auto tries the other protocol only on HTTP 404/405; authentication failures,
rate limits, timeouts and server errors do not trigger retries. Service roots,
API bases and full endpoint URLs are accepted over HTTP or HTTPS. A root OpenAI
URL gains `/v1/chat/completions`; Anthropic gains `/v1/messages` unless already
present. Loopback providers may omit the API token.

The API token is stored separately in ordinary local preferences. AI+ does not
read Keychain; a token from an older Keychain-backed configuration must be entered
again. The field supports paste and visibility controls. Changing an endpoint
clears the old token unless a replacement is provided. **Test connection** sends
only a fixed probe and reports whether the model responded.

Resource selection has a 15-second request limit and a 16-second Bridge budget.
Requests have bounded sizes, use Content-Length and do not follow
redirects. Anthropic requests include `anthropic-version`, a random client session
ID and, when supplied, Bearer authorization plus `x-api-key`. Error diagnostics
never echo response bodies or credentials. Routing results contain candidate IDs,
not advice for a human reader.

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
Internal feature rows summarize resource selection and connection tests for the
selected period; older model-analysis receipts remain historical usage only. CSV includes each receipt group's feature name.
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
