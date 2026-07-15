<p align="center">
  <img src="docs/assets/dingdong-icon.png" width="128" alt="DingDong logo">
</p>

<h1 align="center">DingDong</h1>

DingDong is a local desktop tool for clipboard history and Agent-assisted work.
It keeps recent clipboard items searchable, organizes reusable prompts, Skills,
MCP servers, and knowledge, and alerts you when an Agent finishes or needs your
input.

DingDong 是一款围绕剪贴板与 Agent 协作设计的本地桌面工具。它记录并搜索剪贴板
历史，集中管理提示词、Skill、MCP 和知识库，并在 Agent 完成任务或需要你处理时
及时提醒，让日常工作衔接得更顺畅。

Resources in the local library have individual switches, stable IDs, usage
counts, selective sharing, and a local API for connected Agents.

## Philosophy

- **People stay in control.** 让 AI 工具服务于人，帮助人更高效地完成工作；
  decisions and data remain in the user's hands.
- **Local and deliberate.** Data stays on your computer. Clipboard history is
  excluded from library exports, and you choose exactly what to share.
- **One source of truth.** Maintain reusable AI resources once, enable only what
  matters, and let every connected agent use the same library.
- **Quiet until useful.** Agents see summaries first, load full content only
  when needed, and DingDong gets your attention only when work is ready.

## What DingDong does

- Manages prompts, Skills, MCP references, and knowledge with per-item switches
- Counts actual Agent use and records when each resource was last used
- Exposes the whole library—or selected types and IDs—for AI-assisted duplicate
  and unused-resource analysis
- Selectively exports and imports portable JSON bundles while stable IDs and
  content matching prevent repeated imports
- Connects local agents through a loopback HTTP API and bundled stdio MCP bridge
- Captures searchable clipboard history with sensitive-content protection
- Refreshes from the system clipboard whenever the panel is revealed and moves
  exact matches to the top without creating duplicate history rows
- Plays a chosen DingDong sound when an agent finishes or needs attention
- Supports English, Simplified Chinese, light/dark themes, a complete tray menu,
  keyboard-first search, and global quick paste

## Install on macOS

Download the latest `.dmg` from [GitHub Releases](https://github.com/JevonsCode/DingDongBuddy/releases/latest),
open it, and drag **DingDong** onto the **Applications** shortcut. The ZIP remains
available for portable or diagnostic use. The branded installer includes
`安装与权限说明.txt` with first-launch, Accessibility, clipboard-access, and
login-item guidance. Quick Paste needs Accessibility permission; ordinary
clipboard history does not need Full Disk Access or Screen Recording.

## Feedback and privacy-safe diagnostics

Use **Settings → Version → Report a problem** or **Request a feature** to open a
guided GitHub form. The forms remind contributors to remove clipboard contents,
secrets, personal or company information, usernames, and local file paths.

Anonymous diagnostics are optional and off by default. When enabled, DingDong
can send content-free events such as app starts, clipboard-panel opens, Agent
notifications, and error type names to Aptabase. It never sends clipboard
content, user-entered text, file paths, URLs, names, company information, error
messages, or stack traces. Builds without `APTABASE_APP_KEY` do not initialize
analytics or make analytics requests.

---

## Development

### Desktop support

- macOS 10.15 or newer
- Windows 10 or newer
- Project toolchain: 3.44.6 desktop SDK / Dart 3.12

The application preserves the data location and preference keys used by the
previous native macOS release. Windows uses the current user's `%APPDATA%`
directory.

### Build and test

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d macos
```

On Windows, replace the last command with:

```powershell
flutter run -d windows
```

Desktop builds compile the MCP bridge automatically with `dart build cli` and
place its complete bundle inside the application distribution.

```bash
flutter build macos --release
flutter build windows --release
```

For repeatable local macOS upgrades, create the stable `DingDong Local Development`
signing identity
once, then seal each Release bundle before installing it:

```bash
scripts/setup_macos_codesigning.sh
scripts/sign_macos_bundle.sh build/macos/Build/Products/Release/DingDong.app
```

The identity remains in the login keychain, so macOS can match subsequent
`com.dingdongbuddy.app` builds to the same accessibility permission. Official
distribution can override it with `CODE_SIGN_IDENTITY` set to an Apple
Developer ID Application certificate.

The Windows build command must be run on Windows. CI verifies both platforms;
golden image tests run on macOS and are excluded on Windows.

## Project structure

```text
lib/
  app/                 composition, data paths, localization, theme
  core/                shared models and platform contracts
  features/
    agent_api/         HTTP, MCP, durable coordination, Agent API UI
    clipboard/         capture, classification, history, quick paste
    library/           resources, import/export, updates, long-list UI
    settings/          preferences, release/usage status, desktop settings
    shell/             navigation, tray and global desktop commands
    activity/          Dynamic workspace and Agent completion activity
  platform/            macOS/Windows platform adapters
macos/                  macOS application host
windows/                Windows application host
test/                   unit, contract, widget, performance and golden tests
bin/dingdong_mcp.dart   bundled stdio MCP entry point
```

UI files are split by feature and responsibility. Long lists use lazy builders;
repositories and platform APIs are injected behind interfaces so behavior can be
tested without a desktop host.

## Local data

- macOS: `~/Library/Application Support/DingDong`
- Windows: `%APPDATA%\DingDong`

The HTTP server binds only to `127.0.0.1`. The selected port defaults to `2333`;
if it is occupied, DingDong writes the actual bound port to the application data
directory so the bundled MCP bridge can reconnect.

Clipboard content is private by default. Agent history endpoints omit full and
sensitive content unless the caller explicitly requests supported content modes.

## MCP setup

Open **Agent API** in DingDong and copy the displayed platform-specific MCP path
or the editable setup prompt. The bridge provides tools including:

- `dingdong_bridge`
- `dingdong_notify`
- resource search/detail tools
- native MCP reference preview/install tools

The executable communicates with DingDong through the loopback API. It does not
start a second resource database or a second clipboard monitor.

## Main API routes

- `GET /health`
- `POST /ding`
- `GET|POST /library`
- `GET /library/export` (all resources by default; filter with `type`, `ids`, or
  `q`; includes unused IDs and exact duplicate groups)
- `POST /library/import` (folder scan or schema-v2 selective JSON bundle)
- `GET /clipboard/history`
- `POST /clipboard/capture`
- `POST /clipboard/restore/{id}`
- `GET|POST /agent/bridge`
- `GET /agent/manifest`
- Agent presence, session, memory, bundle, and handoff routes

Use the endpoint reference in the Agent API workspace for the current loopback
origin and privacy notes.

## Release

Pushing a `v*.*.*` tag runs `.github/workflows/release.yml`. It tests and builds
the macOS and Windows applications, creates a drag-to-Applications macOS DMG plus
portable ZIPs, and publishes the GitHub release. When Apple distribution secrets
are configured, the same workflow uses Developer ID signing, notarization, and
stapling; otherwise it falls back to an ad-hoc signed community build.

Official distribution uses these repository secrets:
`MACOS_CERTIFICATE_BASE64`, `MACOS_CERTIFICATE_PASSWORD`,
`MACOS_KEYCHAIN_PASSWORD`, `APPLE_ID`, `APPLE_TEAM_ID`, and
`APPLE_APP_PASSWORD`.

When the website is opened with `?debug=1`, it reads GitHub's public Releases
API and totals each version's asset `download_count`. GitHub exposes counts for
uploaded release assets; the automatically generated source-code archives are
not part of this metric. The normal website neither displays nor requests these
diagnostics. See the
[GitHub Releases API](https://docs.github.com/en/rest/releases/releases).

## License

MIT. See [LICENSE](LICENSE).
