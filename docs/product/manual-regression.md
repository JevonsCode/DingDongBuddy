# DingDong 0.7.2 Manual Regression Checklist

Run this checklist on macOS and Windows before publishing. Automated tests
cover models, repositories, HTTP/MCP contracts, long-list construction, widgets,
and macOS golden images; the items below exercise real operating-system state.

## Window, tray, and startup

- DingDong opens the saved default workspace and restores theme, density, and opacity.
- Closing the window follows the configured desktop behavior and the tray can reopen it.
- Tray actions open Dynamic and Clipboard and can quit the process.
- Launch at startup reads and updates the current-user OS setting.
- The selected API port is written to the application data `api-port` file.
- If the selected port is occupied, the UI and Agent manifest show the actual loopback fallback port.

## Clipboard

- The global shortcut opens Clipboard and remembers the previously focused application.
- Text, URLs, commands, file selections, and bitmap images appear in history.
- Search, kind filters, group filters, pinning, organizing, deletion, and promotion persist.
- Arrow keys change selection and Enter restores it.
- `Command-1…9` on macOS and `Control-1…9` on Windows restore the matching visible row.
- Restoring from the global shortcut returns focus and pastes into the previous app.
- macOS requests Accessibility access when quick paste needs it; Settings reflects the latest status.
- Windows quick paste does not require a separate Accessibility permission.
- A 5,000-row retained history scrolls smoothly without eagerly building every row.
- Sensitive rows stay hidden from default Agent API responses.

## Resource library

- Prompt, Skill, MCP, and Knowledge resources can be created, edited, pinned, enabled, and deleted.
- Search and type/pinned filters preserve the active editor selection.
- Folder import reports imported and skipped files; JSON export can be saved and reopened.
- A direct HTTPS update link replaces content after a successful fetch.
- A GitHub `blob` file link fetches its raw file; repository and folder links are rejected.
- Failed or empty updates preserve the prior resource content and show an error.
- The list remains responsive with 10,000 resources.

## Agent API and MCP

- `GET /health` succeeds only on a loopback address.
- The Agent API workspace displays the actual origin and can send a test notification.
- The editable setup prompt persists and Reset restores the localized, platform-specific default.
- The displayed MCP executable exists inside the installed distribution.
- Sending JSON-RPC `tools/list` to the bundled executable returns DingDong tools.
- `dingdong_bridge` remains summary-first and does not include clipboard content by default.
- `dingdong_notify` uses the sound selected in Settings when no sound is supplied.
- Agent sessions, memories, bundles, and handoffs remain available after restarting DingDong.
- Native MCP installation preview does not write configuration; explicit install preserves unrelated entries.

## Settings and notifications

- Language changes immediately update navigation and feature labels.
- System/light/dark theme and list density render without clipped controls.
- Clipboard retention accepts 20–5,000 items and 1–730 days.
- Built-in, random, system, muted, and custom notification sounds behave as labeled.
- Choosing a custom sound uses the OS file picker; clearing it returns to the default.
- Version checking shows current/latest values, notes, failure state, website, and release links.
- Memory and local storage usage can be refreshed without blocking navigation.
- API port accepts 1024–65535 and states that restart is required.

## Packaging

- `flutter analyze` passes.
- `flutter test` passes on macOS.
- `flutter test --exclude-tags golden` passes on Windows.
- `flutter build macos --release` contains `Contents/MCP/bundle/bin/dingdong_mcp`.
- `flutter build windows --release` contains `mcp/bundle/bin/dingdong_mcp.exe`.
- The bundled MCP executable passes a JSON-RPC `tools/list` smoke test.
- The macOS app metadata is version `0.7.2` build `9` and bundle id `com.dingdongbuddy.app`.
- The Windows executable metadata is version `0.7.2.9` and product name `DingDong`.
- A tag build creates both macOS and Windows ZIP artifacts without modifying release metadata automatically.
