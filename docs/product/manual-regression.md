# DingDong 1.0.1 Manual Regression Checklist

Run this checklist on macOS and Windows before publishing. Automated tests
cover models, repositories, HTTP/MCP contracts, long-list construction, widgets,
and macOS golden images; the items below exercise real operating-system state.

## Window, tray, and startup

- A freshly installed macOS build opens without a `WindowManagerPlugin` crash.
- A saved non-default opacity can be restored before the desktop shell starts without a native window crash.
- DingDong opens the saved default workspace and restores theme and opacity.
- On macOS, switching Spaces and reopening the popup keeps the selected opacity
  instead of falling back to the default appearance.
- Opening DingDong from Applications, Launchpad, or Spotlight reveals and focuses
  the panel both on a cold launch and when the app is already running; login
  startup remains silent.
- Closing the window follows the configured desktop behavior and the tray can reopen it.
- After Command-dragging the macOS status item, its position is restored across
  application restarts.
- Right-click tray actions open Clipboard, toggle monitoring, clear history, open Settings, and quit the complete process.
- Launch at startup reads and updates the current-user OS setting.
- Change clipboard retention to 5,000 items and 190 days without pressing
  Return, close Settings, and reopen it; both values remain saved.
- The selected API port is written to the application data `api-port` file.
- If the selected port is occupied, the UI and Agent manifest show the actual loopback fallback port.

## Clipboard

- The global shortcut opens Clipboard and remembers the previously focused application.
- Settings → Keyboard shortcuts records a modified global shortcut, applies it
  immediately, updates the popup footer, and restores it after relaunch.
- The same section records Dynamic, Library, and Clipboard shortcuts
  independently; each change immediately updates navigation and the hint shown
  while its modifier is held, and remains after reopening Settings.
- A workspace shortcut that duplicates another workspace, the global panel
  shortcut, `Command/Control-F`, `Command/Control-R`, item shortcuts 1–9, or a
  reserved system combination is rejected without replacing the previous value.
- Reset restores `Control-Q/W/E` on macOS or `Alt-Q/W/E` on Windows.
- The shortcut recorder rejects a key without a modifier, Escape cancels
  recording, and Reset restores Command-Shift-V on macOS or
  Control-Shift-V on Windows.
- Choosing a shortcut already owned by another application keeps the previous
  working shortcut and shows an actionable error.
- Every Clipboard reveal performs a fallback system read and places the latest non-duplicate item first.
- `Command-F` focuses Clipboard search on macOS; `Control-F` does the same on Windows.
- Text, URLs, commands, and file selections appear in history. Copied image
  files retain only their source path; screenshots or copied image pixels
  without a source path remain available from DingDong-managed storage.
- Keep both the main Clipboard workspace and Resource Manager Clipboard view
  open, then use ChatGPT's Copy Image action. The new image and item count appear
  in both lists immediately without leaving the view or pressing refresh.
- Single-click a text or URL row: its side preview keeps Copy, system Open,
  Share, and QR Code in a balanced action group. QR Code appears only when the
  exact content can be encoded; sensitive text remains eligible, while local
  file/image records and over-capacity content do not leave an empty action.
- Click QR Code, then click the rendered code: the first action reveals a
  scannable code with a white quiet zone. The second keeps the 304 x 420 side
  preview unchanged and opens only the QR artwork in a separate centered 620 x
  680 image-viewer window. The large window is edge-resizable and the QR scales
  with it. Clicking the large artwork, its close control, or pressing Escape
  closes that large window and focuses the side preview; pressing Escape again
  then closes the side preview.
- Search, kind filters, group filters, pinning, organizing, deletion, and promotion persist.
- `Command-R`/`Control-R` opens filters; when filters are active, the next press
  resets them to All while keeping the bar open, and the following press closes
  the bar. Mouse clicks keep their existing behavior.
- The default `Control-Q/W/E` changes workspaces on macOS without replacing
  standard Command-Q/Command-W behavior; the default `Alt-Q/W/E` does the same
  on Windows. All three combinations are individually configurable.
- Hovering the Clipboard monitoring switch keeps the surface stable, shows a click cursor, and explains whether clicking will turn monitoring on or pause it.
- Arrow keys change selection and Enter restores it.
- Textual-row context menus expose both Paste and Paste as Plain Text; file and
  image rows do not expose the plain-text action.
- `Command-1…9` on macOS restores the matching visible row with its original
  rich-text representation when available; `Control-1…9` restores the matching
  row on Windows.
- Holding Option changes the macOS row hint to `Option-Command-1…9`, adds the
  Plain text label, and restores only the plain-text representation.
- Restoring from the global shortcut returns focus and pastes into the previous app.
- macOS requests Accessibility access when quick paste needs it; Settings reflects the latest status.
- Windows quick paste does not require a separate Accessibility permission.
- A 5,000-row retained history scrolls smoothly without eagerly building every row.
- Pinned and custom-group archived rows survive item and age
  retention; an old archive remains searchable beyond 5,000 newer ordinary rows.
- Managed screenshot/image data is deleted with an ordinary row removed by
  retention or manual deletion, while archived and pinned managed images remain.
  Deleting a copied source-image row never deletes the source file.
- Search text remains visible after leaving and returning to Clipboard, and
  clearing it restores the complete visible history.
- Sensitive rows stay hidden from default Agent API responses.

## Resource library

- Prompt, Skill, and MCP resources use type-specific creation and editing flows.
- Online Skills parse `name` and `description` from `SKILL.md`, keep upstream
  content read-only, retain their source URL, and support Open and Update.
- Local Skills can be edited directly or imported from a local folder.
- Trigger groups can be named, searched, assigned to multiple resources, and
  limited by workspace path, repository-address, or Agent-source rules (for
  example Codex, Claude Code, or Cursor).
- A Skill with a trigger scope is visibly marked in the Resource Manager list,
  the popup resource library, and the popup Enabled list.
- Search and type/pinned filters preserve the active editor selection.
- Popup and Resource Manager tabs, search fields, filters, group chips, and bulk
  actions use the shared desktop controls: labels stay vertically centered,
  adjacent actions retain a visible gap, and changing a segmented choice does
  not flash a native Material hover, ink, or ripple surface.
- Creating, enabling, disabling, or deleting resources in the dedicated
  Resource Manager updates the popup resource list, Dynamic resource count,
  and the complete Enabled list without restarting DingDong; reopening the
  popup also recovers the latest on-disk state if a notification was missed.
- Folder import reports imported and skipped files; JSON export can be saved and reopened.
- GitHub repository, folder, `blob` `SKILL.md`, and raw `SKILL.md` links install
  the complete Skill directory rather than only its entry file.
- Updating an online Skill replaces the complete local package only after the
  new package passes metadata and path validation.
- Failed or empty updates preserve the prior resource content and show an error.
- Codex `AGENTS.md` and Claude Code `CLAUDE.md` contain only DingDong's
  persistent bridge bootstrap without changing user-owned sections; enabled
  global, project, and task Prompts are returned dynamically by the next bridge
  call, each successful response replaces the previous Prompt snapshot, and
  Prompt bodies never appear in those native files.
- Every successful Bridge call returns all enabled, scope-matched Skills as
  `id`, `name`, and `description` only, regardless of Prompt activation mode.
- Loading a returned Skill provides its complete `SKILL.md` and package
  manifest; referenced files can be read on demand, while disabled or
  out-of-scope loads fail.
- Existing DingDong-managed native Skill mirrors are removed during
  synchronization; user-owned native Skills are preserved and appear as
  warnings in Resource Manager's first-level Issues page.
- The Issues page stays available when empty, has one manual detection action,
  and can open the affected resource when one is recorded.
- An enabled Claude Code plugin with the same Skill name produces a warning
  rather than blocking synchronization.
- Agent access shows the five bundled Adapters and defaults to an evidence
  summary. Detected/not-detected directory badges are explicit, and the page
  says that directory detection or a declared path does not verify MCP, Hook,
  Bridge, authentication, or completion callbacks.
- Advanced config validates user YAML, preserves current plus two prior
  revisions, and does not overwrite an unsaved editor when its file changes
  externally.
- Saving, restoring, or deleting an Adapter immediately resynchronizes current
  resources. Changing its paths removes only legacy DingDong-managed Skill
  copies and managed Prompt/MCP content from old targets while preserving
  user-owned content.
- Native MCP synchronization refuses unrelated duplicate tables instead of
  overwriting them, removes only DingDong-managed stale tables, detects a file
  changed after it was read, writes atomically, and verifies the saved result by
  reading it back. Incrementing only usage count or last-used time does not
  rewrite the native configuration; explicitly saving the resource still does.
- An Adapter path that leaves the home directory directly or through a symbolic
  link remains visible as invalid and blocks synchronization.
- The list remains responsive with 10,000 resources.

## Agent API and MCP

- `GET /health` succeeds only on a loopback address.
- Opening `/` redirects to the configured DingDong website.
- Browser requests with a cross-origin `Origin` or cross-site Fetch Metadata are
  rejected outside `/` and `/health`. Form-style POST requests are rejected,
  while valid JSON Agent requests continue to work.
- Request bodies above 8 MiB are rejected before routing.
- Agent connections health-checks the actual bound origin, discloses preferred
  port fallback, distinguishes real completion receipts from unknown state, and
  can send a test notification.
- The Agent setup prompt is read-only, can be copied with visible feedback, and
  describes how the Agent should install and verify DingDong MCP.
- The displayed MCP executable exists inside the installed distribution.
- Sending JSON-RPC `tools/list` to the bundled executable returns DingDong tools.
- `dingdong_bridge` remains summary-first and does not include clipboard content by default.
- With **Allow Agents to read clipboard content** off, metadata queries remain
  available but content reads, API capture, collection, and promotion are
  rejected. Enabling it takes effect without a restart; sensitive records still
  require a separate explicit request.
- `dingdong_notify` uses the sound selected in Settings when no sound is supplied.
- Agent sessions, memories, bundles, and handoffs remain available after restarting DingDong.
- Enabling or disabling an MCP updates supported Agent user configurations and preserves unrelated entries.
- An online Skill installs its complete directory, including scripts, references, and assets.

## Recent Agents

- Dynamic shows at most six recent Agent items.
- Repeated notifications with the same conversation ID are grouped into one
  item by default, play the notification sound, show a bottom-aligned `×N`
  watermark, and do not increase the recent-Agent count. A newly revealed
  unread watermark is pale orange; after acknowledgement it returns to the
  low-contrast gray used by older items.
- **Settings → Recent Agents → Group repeated sessions** can disable grouping;
  when disabled, repeated notifications appear as separate items and increase
  the count. The choice persists after restart.
- Long Agent source and message text uses ellipsis without overflowing the
  Dynamic panel or Recent Agents manager.
- When more than six items exist, the `More` button opens Resource Manager directly at Recent Agents.
- A resumable Recent Agent item opens its exact conversation from both Dynamic and Resource Manager.
- Codex thread links, Claude Code, Gemini, and Kiro resume commands reopen the expected session.
- A valid `agent-launchers.json` can open Claude Code in a new iTerm tab; an
  invalid file fails visibly without silently falling back to Terminal.app.
- Cursor background-agent links open the exact conversation; local Cursor sessions fall back to the recorded workspace.
- An item without a safe resume target has no open affordance and does not launch a process.
- A failed launch keeps DingDong responsive and shows a visible error.
- The Kiro Stop hook records the session id and workspace needed to resume a conversation.

## Settings and notifications

- Language changes immediately update navigation and feature labels.
- System/light/dark theme and window opacity render without clipped controls.
- Clipboard retention accepts 20–5,000 items and 1–730 days.
- Agent clipboard-content access defaults to off and persists after restart.
- Built-in, random, system, muted, and custom notification sounds behave as labeled.
- Notifications play the selected sound without requesting Dock icon attention.
- Completion hooks show the first useful sentence from the Agent's final reply;
  missing or unreadable hook context falls back to a generic completion message.
- A fallback completion alert is suppressed only after the same Agent's recent
  primary alert; interleaved Agents and separate fallback-only tasks remain
  independent.
- Choosing a custom sound uses the OS file picker; clearing it returns to the default.
- Version checking shows current/latest values, notes, failure state, website, and release links.
- A newer release adds a small orange-red dot beside the popup version; current,
  unknown, checking, and failed states do not show the dot.
- Report a problem and Request a feature open the matching structured GitHub forms.
- Settings do not expose analytics controls, and release builds contain no analytics SDK or analytics build key.
- Memory and local storage usage can be refreshed without blocking navigation.
- API port accepts 1024–65535 and states that restart is required.

## Accessibility and readability

- The Settings, Hide, Issues, workspace-tab, Clipboard monitoring, Clipboard
  filter, resource action, metric, Agent connection, and Agent Adapter controls
  expose explicit button, selected/toggled, enabled, label, and action semantics
  where their visual composition would otherwise be ambiguous.
- Workspace-tab semantics always include the configured shortcut, even when the
  visual shortcut hint is hidden.
- Recent-Agent counts, Agent metadata and timestamps, Activity status text,
  Clipboard group labels, Clipboard timestamps, the Plain text label, and
  resource tags use at least 10 px rather than the previous 7–9 px body/status
  sizes. Small DEV, MCP, and numeric badges may remain 8–9 px because their
  parent control exposes the complete accessible label.
- Settings and Resource Manager expose named semantic roots. The current macOS
  secondary-window accessibility bridge still needs a real VoiceOver pass
  because automated inspection may expose only the native window shell.

## Packaging

- `flutter analyze` passes.
- `flutter test` passes on macOS.
- `flutter test integration_test/desktop_agent_connection_smoke_test.dart -d
  macos` passes with a real occupied loopback port, fallback bind, and `/health`
  request. Its product data stores are explicitly in-memory test substitutes.
- When that macOS test runner sends `SIGTERM`, the Debug host exits through
  AppKit without opening an “unexpectedly quit” report; actual crash signals
  remain unaffected.
- `flutter test --exclude-tags golden` passes on Windows.
- `flutter build macos --release` contains `Contents/MCP/bundle/bin/dingdong_mcp`.
- `flutter build windows --release` contains `mcp/bundle/bin/dingdong_mcp.exe`.
- The thin arm64 and x86_64 MCP bundles each pass a native JSON-RPC `tools/list` smoke test before packaging.
- The final MCP bundle contains native `arm64` and `x86_64` sub-bundles and one stable executable launcher path.
- The launcher selects and runs the native MCP successfully on both an Apple Silicon Mac and an Intel Mac.
- The Windows MCP executable passes `tools/list` on a Windows x64 machine.
- A Debug macOS build is named `DingDong DEV`, uses bundle id
  `com.dingdongbuddy.app.dev`, stores data under `DingDong DEV`, shows a DEV
  badge, and does not offer release updates.
- With Accessibility permission absent, **Settings → Quick paste permission →
  Open permission helper** opens the macOS Accessibility list and shows a
  floating native panel beside it. The current app card can be dragged into the
  system list, and the panel explains that any stale DingDong entry must first
  be selected and removed with **−** by the user. If **−** starts disabled,
  dragging once makes the stale entry removable; after removal, dragging the
  current app a second time allows the user to enable it.
- When Accessibility changes from denied to granted while the helper is open,
  DingDong closes the helper, shows and focuses the main popup first, switches
  it to Clipboard, waits for that view to render, and only then refreshes the
  permission state. The visible yellow **Open settings** banner splits into two
  jagged fragments, emits a short amber particle burst, and then collapses
  exactly once; reopening Clipboard does not replay the completion animation.
- The macOS release app metadata is version `1.0.1` build `36` and bundle id `com.dingdongbuddy.app`.
- The Windows executable metadata is version `1.0.1.36` and product name `DingDong`.
- The macOS DMG uses the DingDong volume icon and contains a branded background, `DingDong.app`, an `Applications` shortcut, and `安装与权限说明.txt`.
- The DMG background clearly points from DingDong to Applications and explains first launch and Accessibility permission.
- The app copied from the DMG passes `codesign --verify --deep --strict`.
- On Apple Silicon and Intel Macs, the installed app remains alive for at least 30 seconds and creates no new DingDong crash report.
- A tag build creates macOS DMG/ZIP plus Windows Setup/update-feed artifacts without modifying release metadata automatically.
