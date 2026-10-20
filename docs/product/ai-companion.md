# Optional AI companion

Open **Resource Manager → AI companion**. Clipboard insights, resource usage
optimization, progressive disclosure advice, Token suggestions, proactive check-ins, and supportive chat each
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

Configure an OpenAI-compatible Chat Completions endpoint and model to enable
model-assisted analysis or chat. HTTPS is required for remote providers; HTTP
is accepted only for a loopback local model. The endpoint can be a base URL
ending in `/v1` or the complete `/chat/completions` URL. Remote providers require
the user's own API key, saved in the operating system's secure storage. Changing
the endpoint clears the previous provider's key unless a new key is supplied.
**Test connection** makes an explicit, constant-text model request.

Cloud analysis is separately opt-in and sends only bounded, whitelisted
metadata: record counts, anonymous resource references and usage counters, and
numeric Token aggregates with data-availability flags. Clipboard text, resource
contents and titles, local identifiers, paths, images, and file contents are
excluded structurally. Local insights remain available without a provider.
Analysis does not upload files or grant model access to tools.

Chat accepts only text entered in its own input. Local rules reject recognized
credentials, secret assignments, opaque key-like strings, file references and
URLs before transmission, and check responses before displaying them. These
rules are conservative and cannot identify every possible password; avoid
entering private material. Chat history stays in memory and can be cleared.
Persisted reports contain suggestion codes and local references, plus filtered
model summaries when requested, rather than clipboard or resource contents.

Proactive check-ins run locally while the AI page is open and opted in. They
offer an occasional break reminder; page-open time is not evidence of continuous
work. A check-in does not trigger model requests or inspect clipboard content.
Closing the page stops its timer.

Provider requests have time and size limits and do not follow redirects.
Failures display a stable diagnostic category without echoing provider response
bodies or API keys. Configured models and providers may differ in which Chat
Completions parameters they support.
