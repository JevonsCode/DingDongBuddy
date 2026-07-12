# DingDong

DingDong 0.7.0 is a Flutter desktop companion for local AI agents. It keeps
clipboard history, prompts, skills, MCP references, and knowledge in one local
workspace, and exposes them through a loopback HTTP API and a bundled stdio MCP
bridge.

## Desktop support

- macOS 10.15 or newer
- Windows 10 or newer
- Flutter 3.44.6 / Dart 3.12

The application preserves the data location and preference keys used by the
previous native macOS release. Windows uses the current user's `%APPDATA%`
directory.

## Features

- Virtualized resource and clipboard lists for large local histories
- Text, file, and image clipboard capture with sensitive-content protection
- Global quick-paste shortcut, tray controls, and launch at startup
- Prompt, Skill, MCP, and knowledge management with import/export and update links
- Local Agent API, durable sessions/handoffs/memories, and MCP JSON-RPC tools
- English, Simplified Chinese, light, dark, density, opacity, and sound settings
- Version checks, system usage diagnostics, and custom notification sounds

## Develop

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
  platform/            macOS/Windows Flutter method-channel adapters
macos/                  Flutter macOS runner
windows/                Flutter Windows runner
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
Flutter release artifacts on macOS and Windows, packages both distributions, and
creates the GitHub release. Creating a branch or ordinary commit does not publish
anything.

## License

MIT. See [LICENSE](LICENSE).
