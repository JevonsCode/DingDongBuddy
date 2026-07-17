<p align="center">
  <img src="docs/assets/dingdong-icon.png" width="128" alt="DingDong logo">
</p>

<h1 align="center">DingDong</h1>

<p align="center">
  <strong>Find what you copied. Hear a DingDong when your Agent is done.</strong><br>
  <strong>复制过的随时找，Agent 做完就叮咚。</strong>
</p>

DingDong keeps clipboard history, prompts, Skills, and MCP configurations close
at hand. When an Agent finishes, gets stuck, or needs a decision, DingDong rings
so you do not have to keep watching it.

DingDong 把剪贴板历史、提示词、Skill 和 MCP 收在一个地方。Agent 做完、卡住或
等你决定时，它会叮咚一声——你不用一直盯着。

## Philosophy

- **Your data stays yours.** Clipboard history and the resource library stay on
  your computer unless you choose to export or share something.
- **Set things up once.** Keep a prompt, Skill, or MCP configuration in DingDong
  and use the same copy from every connected Agent.
- **Bring only what helps.** Agents see names and short descriptions first, then
  open the full resource when it is actually useful.
- **Come back when it rings.** Keep working elsewhere and let DingDong call you
  back when an Agent is ready.

## What DingDong does

- Find text, links, images, and files you copied earlier
- Sort clipboard items into reusable groups and your own matching rules
- Keep prompts, Skills, and MCP configurations in one tidy library
- Pull a Skill from GitHub, read it locally, and update it when you choose
- Turn resources on only for matching projects or repositories
- Share a few selected resources without exporting the whole library
- Let connected Agents find the right resource and ring DingDong when work ends
- Search and paste from the keyboard with the global quick-paste panel
- Use native desktop menus, English or Simplified Chinese, and light or dark mode

## Download

- [macOS · Apple Silicon](https://github.com/JevonsCode/DingDongBuddy/releases/latest)
- [macOS · Intel (beta)](https://github.com/JevonsCode/DingDongBuddy/releases/latest)
- [Windows x64 (beta)](https://github.com/JevonsCode/DingDongBuddy/releases/latest)

On macOS, open the `.dmg` and drag **DingDong** onto the **Applications**
shortcut. ZIP packages remain available for portable or diagnostic use. The
installer includes `安装与权限说明.txt` with first-launch, Accessibility,
clipboard-access, and login-item guidance. Quick Paste needs Accessibility
permission; ordinary clipboard history does not need Full Disk Access or Screen
Recording.

## Feedback and privacy

Use **Settings → Version → Report a problem** or **Request a feature** to open a
guided GitHub form. The forms remind contributors to remove clipboard contents,
secrets, personal or company information, usernames, and local file paths.

DingDong does not include analytics or usage-event reporting.

---

## Development

### Desktop support

- macOS 13 or newer (Apple Silicon and Intel)
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
or the ready-to-use setup prompt. Paste it into Codex, Claude Code, or another
Agent and let it add DingDong to the right MCP configuration, reload, and send a
test notification. The bridge provides tools including:

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
