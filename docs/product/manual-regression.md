# DingDong 1.5.0 Manual Regression Checklist

Run this checklist on macOS and Windows before publishing. Automated tests
cover models, repositories, HTTP/MCP contracts, long-list construction, widgets,
and macOS golden images; the items below exercise real operating-system state.

## Window, tray, and startup

- A freshly installed macOS build opens without a `WindowManagerPlugin` crash.
- A saved non-default opacity can be restored before the desktop shell starts without a native window crash.
- DingDong opens the saved default workspace and restores theme and opacity.
- In dark mode, the popup uses layered blue-black surfaces rather than pure or
  near-black gray, with a distinct header, workspace body, cards, fields, and
  footer.
- Populate Dynamic with recent Agent events plus Prompt, Skill, and MCP cards;
  no title, summary, or tag row clips, and badges remain legible.
- Populate Resource Library with Prompt, Skill, and MCP cards; Manage, type and
  group filter counts, status actions, tags, and card text retain clear contrast
  without bottom overflow.
- On macOS, switching Spaces and reopening the popup keeps the selected opacity
  instead of falling back to the default appearance.
- Opening DingDong from Applications, Launchpad, or Spotlight reveals and focuses
  the panel both on a cold launch and when the app is already running; login
  startup remains silent.
- Closing the window follows the configured desktop behavior and the tray can reopen it.
- After Command-dragging the macOS status item, its position is restored across
  application restarts.
- A fresh macOS launch starts in normal state with `AgentToolIcon-w` rendered as
  a native template image. With no Agent reminder or Clipboard capture, it
  switches to the template `rest-w` state after three minutes and the template
  `sleeping-w` state after five minutes.
- A new Agent reminder shows `ding-w`. A Clipboard capture or acknowledging the
  reminder restores normal and restarts both idle thresholds; there is no turn
  animation.
- On macOS, changing between light and dark appearance immediately retints the
  template normal, resting, and sleeping artwork without restarting DingDong or
  swapping assets. The non-template reminder art remains white over its colored
  capsule; `ding-w` alternates with `ding-w2` every 0.7 seconds. Resting and
  sleeping alternate with their matching second frames every 1.2 seconds;
  resting is rendered 2px smaller in both dimensions.
- On Windows light and dark taskbars, normal, reminder, resting, and sleeping
  use their matching artwork and the same 0.7/1.2-second frame timing.
- On Windows, the two reminder animation frames use the adaptive unread icons
  and remain legible after switching between light and dark taskbars. Normal,
  resting, and sleeping continue to use their taskbar-specific resources.
- With an unread macOS reminder, the count is visually centered inside the
  capsule and sits about 2px lower than before.
- Receive an Agent completion while the popup is hidden or while another
  workspace is selected. Its unread state remains until Dynamic is actually
  visible and the completion card has rendered.
- Leave an Agent reminder unopened for five minutes: the status item nudges
  horizontally once per minute until the reminder is acknowledged.
- Click the popup mascot three times within five seconds: it uses `thinking`
  for two seconds, then returns to the state that is currently active.
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
- Copy the same content from multiple applications: DingDong keeps one newest
  row, updates its timestamp on every copy, increments its pale-blue count, and
  retains each observed source without auto-archiving the item.
- Resource Manager can sort Clipboard rows by copy count.
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
- Expanding the filter bar keeps the enabled built-in categories visible even
  when the current history has no matching item; an empty persisted category
  configuration restores Text, Links, Images, and Files.
- The default `Control-Q/W/E` changes workspaces on macOS without replacing
  standard Command-Q/Command-W behavior; the default `Alt-Q/W/E` does the same
  on Windows. All three combinations are individually configurable.
- The compact Clipboard toolbar shows search and filters only; clipboard monitoring remains available from the tray menu and Settings.
- Click Manage categories from the compact Clipboard filter row. DingDong hides
  the popup, opens or focuses Resource Manager on its Clipboard workspace, and
  opens category rules there; no category-rule editor is layered over the
  compact popup.
- Arrow keys change selection and Enter restores it.
- Textual-row context menus expose both Paste and Paste as Plain Text; file and
  image rows do not expose the plain-text action.
- Promoting a custom Clipboard group creates a permanent archive entry that
  survives item and age retention; archive images remain available after
  ordinary history cleanup.
- Archived Clipboard rows can be pinned from either Clipboard view. The angled
  pin peeks from the upper-right edge, pinned rows lead the archive, and manual
  drag ordering in Resource Manager persists after reopening.
- An untitled row offers Add title; after saving a title the same action reads
  Edit title and updates the existing title.
- `Command-1…9` on macOS restores the matching visible row with its original
  rich-text representation when available; `Control-1…9` restores the matching
  row on Windows.
- Holding Control on macOS or Alt on Windows reveals the first five visible
  Clipboard groups as 1–5; pressing a number selects that group and expands
  the filter row when needed.
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

## Connected Devices and mobile PWA

- Open Connected Devices from both the popup header and tray menu. It opens as
  one dedicated resizable window rather than crowding the compact popup.
- Show a fresh QR code on the computer, scan it with Android Chrome, confirm the
  pairing, refresh the page, and reopen the installed PWA if present. The saved
  pairing reconnects without scanning again.
- In the PWA device settings, verify **PWA 更新** shows the current version and
  exposes **手动升级**. With the current deployment it reports the latest
  version without re-pairing. With a newer deployment it refreshes to the new
  shell, restores every saved computer, and reconnects without scanning again.
- Pair a second computer from the same phone without deleting or replacing the
  first. Both computers remain independently connected when available. The
  header shows a green online dot plus the online-computer count; opening it
  lists every paired computer and switches the active computer without
  disconnecting the others.
- Put different Clipboard items, Agent events, selected files, and unsent text
  drafts into the two computer sessions. Switch repeatedly and verify every
  value returns only with its source computer. Refresh and confirm the same
  active computer and all pairings are restored.
- While the PWA is already open, scan a third computer QR. The confirmation
  opens without a page reload, says the new computer will be added, and leaves
  the existing computer connections running. Cancel without changing the
  existing device list.
- Open the same pairing in a second browser tab. The newer page takes over once;
  the replaced page stops reconnecting and the devices do not enter a repeating
  connect/disconnect loop.
- Leave automatic Clipboard delivery off. The phone receives no Clipboard
  history and no newly copied content. Turn it on for only one device: only
  Clipboard items captured after pairing arrive there; content from before the
  connection does not backfill.
- Use **Send to Device** on one existing text item and one existing supported
  file. Only the selected online device receives them; the operating-system
  native share sheet is not opened.
- On the phone, verify that DingDong never requests or reads the system
  clipboard. Paste text into the composer and select a file: neither leaves the
  phone until **Send** is tapped, and each then appears in the computer's
  Clipboard list with the phone name as its source.
- Send text at the 128 KiB UTF-8 boundary and one byte beyond it. The boundary
  item arrives without closing the relay; the oversized item is rejected with
  a clear message suggesting a file instead.
- Transfer a file immediately below 25 MB. A file above 25 MB is rejected.
  Disconnect before downloading a computer-hosted file and confirm it is no
  longer available; reconnecting does not expose unsent history.
- Verify a same-network connection can establish WebRTC. Then block or fail the
  direct channel and confirm encrypted relay fallback remains connected without
  duplicating Clipboard items. Confirm both desktop and phone explain that local
  WebRTC is preferred and that the encrypted relay is a fallback, rather than
  claiming that the feature is LAN-only.
- In phone settings, switch the interface icon background between soft blue and
  white. Verify the header and install preview update immediately and the copy
  accurately says the operating system may require re-adding the PWA before the
  Home Screen icon changes.
- Trigger a rich Agent completion while the PWA is visible, in the background,
  and with the phone locked. Each event appears once with description, source,
  and completion time; background delivery does not require reopening the PWA.
- In one Codex chat whose Bridge cannot provide a stable conversation ID,
  trigger eight consecutive task starts from the same workspace. The phone
  shows one running item and a running count of one, using the latest task and
  start time instead of retaining one item for every turn.
- Start two tasks from different Agent clients, including two tasks that reuse
  the same conversation ID. The phone's selected-computer Agent view lists both
  as running with their real start times. Completing one removes only its
  matching run and adds a completion with task, detail, start, end, and total
  duration; its unread count matches the desktop snapshot.
- Disconnect and reconnect while one task is running and after one has
  completed. The selected computer restores the authoritative running and
  completion snapshot without duplicates. Restarting the desktop app does not
  restore an old run as active.
- Tap the Clipboard and Agent tabs, then swipe both directions between them.
  The selected tab, accessibility state, horizontal snap position, and panel
  height remain synchronized without a vertical jump or mid-gesture lockout.
- Tap a completion notification with the PWA visible, backgrounded, and fully
  closed. Each path opens Agent reminders directly. A running page is not
  reloaded, an older page cannot create a competing connection, and a
  notification from an earlier pairing never injects content into the current
  pairing.
- Inspect the system notification: both its main icon and badge use DingDong
  artwork rather than a stale or browser-default icon.
- Turn vibration off and on per device. Run the direct vibration diagnostic and
  a test Push. Record separately whether the browser accepted vibration and
  whether the operating system vibrated; system notification-channel policy may
  override the requested pattern.
- Disable Agent reminders and trigger another completion: no system notification
  or foreground fallback appears. Re-enable them and verify the Push
  subscription is rebuilt and the diagnostics reach browser-created status.
- Disconnect and reconnect one saved device, then delete it. Manual disconnect
  remains stable until reconnect; delete removes the desktop record, PWA
  pairing, relay subscription, and future delivery.
- On iPhone/iPad Safari, add DingDong to the Home Screen, open that Home Screen
  web app, pair again if Safari did not transfer the pairing, and verify
  permission plus background Web Push. Record this separately from Android;
  browser-tab Safari alone is not a valid iOS Web Push test.

## Website

- The five colored menu-bar previews use white `ding-w` and `ding-w2`, changing
  frames every 0.7 seconds.
- The hero finish note uses animated rest, the custom sound card uses animated
  sleeping, and the local API title includes thinking.
- Open the Clipboard website demo: All, Images, Text, Links, and Files are
  visible by default in that order.
- The 1.3 Connected Devices section is visible in English and Chinese, labels
  its composed product preview as an illustration, and accurately states the
  new-item-only, explicit phone Send, 25 MB, disconnect, and system-vibration
  boundaries.

## Resource library

- Prompt, Skill, and MCP resources use type-specific creation and editing flows.
- Online Skills parse `name` and `description` from `SKILL.md`, keep upstream
  content read-only, retain their source URL, and support Open and Update.
- Local Skills can be edited directly; exported JSON files and resource links
  can be imported through the review flow.
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
- JSON export can be saved and reopened, with imported and skipped entries
  reported in the review flow.
- JSON file and link imports resolve online content before conflict review,
  retain source links, and add a bounded import-history record.
- Resource editors limit Agent conversation loading names to seven Unicode
  characters; the built-in DingDong Configure Skill keeps the hide-in-summary
  switch enabled while remaining usable by the Agent.
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
- Each Skill has one master enabled switch and exactly one delivery mode per
  Agent: `dynamic`, `nativeUser`, or `nativeProject`. Changing one Agent does
  not silently change another Agent's delivery plane.
- Every successful Bridge call returns the resolved dynamic-delivery Skill
  catalog as `id`, `name`, and `description` only. Native-delivery Skills,
  transitions whose native absence is not yet confirmed, and ambiguous
  duplicate-name artifacts are withheld and reported through delivery
  suppressions or conflicts instead of falling back to dynamic delivery.
- Loading a returned dynamic Skill provides its complete `SKILL.md` and package
  manifest; referenced files can be read on demand. Disabled, out-of-scope,
  native-delivery, transition-suppressed, and duplicate-conflict loads fail by
  the same rules as catalog construction.
- `nativeUser` installs the complete receipt-owned package in that Adapter's
  user Skill root. `nativeProject` installs it only under each exact existing
  project root, and its configured project paths remain one shared exact set
  across Agents for that Skill.
- The same Skill cannot mix user-native and project-native modes across Agents;
  user-native mode clears trigger-group/project scope.
- Supported Agents discover native Skill file changes automatically. Delivery
  responses recommend a new task when state actually changed and recommend an
  Agent restart only when an enabled native Skill remains missing; they never
  claim a reload is unconditionally required.
- Codex does not merge same-name native Skills. DingDong deduplicates identical
  managed artifacts, suppresses different managed artifacts with the same name,
  and fails closed on an unmanaged native destination collision. A separate
  user-owned native copy is preserved and may still appear independently.
- The project Hook switch is independent from Skill delivery, defaults off, and
  is accepted only for Codex project-native Impeccable. Writing or updating the
  Hook does not grant trust: `/hooks` must review its exact current definition,
  and any definition change requires another review. Matching Hooks from all
  loaded sources run, so duplicate, partial, or different same-family entries
  are surfaced as conflicts instead of being appended.
- Legacy pre-delivery DingDong mirrors are removed during synchronization;
  current receipt-owned native deliveries are reconciled to desired state.
  User-owned native Skills are preserved and appear as warnings in Resource
  Manager's first-level Issues page.
- The Issues page stays available when empty, has one manual detection action,
  uses the `rest.png` mascot when no issue is found, and can open the affected
  resource when one is recorded.
- An enabled Claude Code plugin with the same Skill name produces a warning
  rather than blocking synchronization.
- Agent access shows the seven bundled Adapters and defaults to an evidence
  summary. Detected/not-detected directory badges are explicit, and the page
  says that directory detection or a declared path does not verify MCP, Hook,
  Bridge, authentication, or completion callbacks.
- Advanced config validates user YAML, preserves current plus two prior
  revisions, and does not overwrite an unsaved editor when its file changes
  externally.
- Saving, restoring, or deleting an Adapter immediately resynchronizes current
  resources. Changing its paths reconciles receipt-owned native Skills and
  managed Prompt/MCP content from old targets to the new targets while
  preserving user-owned content.
- Native MCP synchronization refuses unrelated duplicate tables instead of
  overwriting them, removes only DingDong-managed stale tables, detects a file
  changed after it was read, writes atomically, and verifies the saved result by
  reading it back. Incrementing only usage count or last-used time does not
  rewrite the native configuration; explicitly saving the resource still does.
- Managed Prompt, JSON/TOML MCP, Adapter, Resource, Trigger Group, and internal
  state writes serialize concurrent DingDong writers, reject stale snapshots,
  validate unique sibling files before replacement, preserve POSIX permissions,
  and read the final target back. Strict JSON inputs reject duplicate object
  keys, including keys that become equal after Unicode unescaping.
- The Resource Manager list shows a quiet **Usage** column immediately after
  **Scope** at desktop widths and hides both at narrow widths. Prompt rows show
  activation count; Skill rows show candidate delivery and confirmed full-load
  counts; MCP rows show candidate delivery and confirmed real-call counts.
  Hovering the compact values exposes their exact meaning and most recent
  timestamps. Opening an existing item repeats the same type-specific metrics,
  with timestamps, beside **Configuration details** and stacks them below the
  heading at narrow widths. Legacy MCP match counts migrate to candidate count
  and never impersonate confirmed calls.
- A Trigger Group change that also rewrites Resource scope is guarded by a
  restrictive-permission transaction journal. Simulate interruption after only
  one file changes, then verify the next mutation deterministically completes
  or rolls back the pending transaction before applying new work.
- An Adapter path that leaves the home directory directly or through a symbolic
  link remains visible as invalid and blocks synchronization.
- With Pi installed, set `PI_EXECUTABLE` to its absolute path and run
  `flutter test test/integration/pi_agent_adapter_integration_test.dart`.
  Verify DingDong deploys the complete project-native package, Pi RPC reports
  `skill:pi-reviewer` with project scope, and disabling the resource removes the
  receipt-owned copy.
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
- `dingdong_set_skill_delivery` uses a closed input schema, requires an explicit
  master enabled value, requires at least one path for `nativeProject`, rejects
  project paths or enabled Hooks for other modes, and permits the Hook switch
  only with Codex project-native delivery before runtime Skill-name validation.
- `PUT /library/skills/{id}/delivery` and its MCP wrapper return `discovery`,
  `taskBoundaryRecommended`, and `restartAgentIfMissing`; they do not return the
  misleading legacy `reloadRequired` field. Repeating an unchanged request does
  not recommend another task boundary.
- `dingdong_get_skill_deployments` returns desired policy, observed
  DingDong-owned native deployments, and active recovery operations.
  `dingdong_reconcile_skill` validates the Skill before requesting an idempotent
  full native-resource synchronization and then returns the same snapshot;
  unknown IDs and unavailable deployment state have no synchronization side
  effect.
- `dingdong_bridge` remains summary-first and does not include clipboard content by default.
- When Bridge receives a workspace path but no repository URL, it resolves the
  workspace's Git `remote.origin.url`. SSH/SCP and HTTPS forms of the same
  host/repository match one repository trigger; a different repository does
  not. Latin task terms match complete tokens (`API` does not match `rapid`),
  while CJK task terms retain natural substring matching.
- A Bridge response exposes one `conversation` capsule for visible active
  Prompts, candidate Skills, and available MCPs. Repeating the Bridge call
  replaces the prior snapshot by stable merge key instead of appending duplicate
  labels or retaining resources that are no longer active.
- Codex desktop includes the current merged footer exactly once as a single
  Markdown text line. `DingDong` remains text; use the exact user-configurable
  symbols and item `lineToken` values supplied by the Bridge or replacement
  receipt. No image, MCP Apps renderer, or outer tool card is created.
- Explicitly ANSI-capable terminals use current merged ANSI tokens. Every other
  host shows the current merged plain-text tokens exactly once with the
  `DingDong` text label.
- A candidate Skill has no `*` marker. After `dingdong_load_skill` succeeds,
  replace the same merge-key item with the returned loaded item and verify it
  gains exactly one `*` marker without creating a second footer entry.
- An available MCP has no `*` marker. After one real tool call returns from that
  MCP, call `dingdong_confirm_mcp_use` once with the Bridge `id`, `serverName`,
  and exact `toolName`; replace the same merge-key item and verify it gains one
  `*`. A successful, error-result call is marked, while availability, tool
  discovery, a mismatched Codex prefix, and an out-of-scope MCP are not.
- Prompt items stay unmarked: Bridge delivery is observable, but semantic
  compliance is not. Verify the footer never infers Prompt use from the final
  prose alone.
- In Settings → Agent reply footer, verify the initial Prompt, Skill, and MCP
  symbols are `♥`, `♦`, and `♠`. Change all three symbols, call both Bridge
  routes and load one Skill, then verify every line uses the new values without
  a restart. Restore defaults and verify the preview returns to `♥`, `♦`, `♠`.
- **Show conversation Token usage** is on by default. When enabled, a Bridge
  response for a supported Codex, Claude Code, or Pi conversation appends one
  compact exact total after the resource footer, for example
  `DingDong · ♥ · 12.4K Token`. Unsupported clients, missing session evidence,
  malformed logs, and resolver failures omit the suffix instead of estimating.
  Turn it off and verify Bridge and completion notifications do not read local
  conversation usage files.
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
- With conversation Token usage enabled and an exact supported snapshot
  available, hovering `×N` reports both values: `This conversation has
  notified you N times and used X tokens.` The Chinese locale uses
  `本轮会话已经提醒 N 次，共消耗 X Token`. The visible watermark remains
  only `×N`; when usage is disabled or unavailable, the previous repeat-only
  tooltip remains.
- **Settings → Recent Agents → Group repeated sessions** can disable grouping;
  when disabled, repeated notifications appear as separate items and increase
  the count. The choice persists after restart.
- Long Agent source and message text uses ellipsis without overflowing the
  Dynamic panel or Recent Agents manager.
- When a recent Agent message starts with a DingDong or FULI marker line, its
  description uses the next meaningful content line. Verify both the legacy
  `◇ FULI` form and the current `🌠 FULI · 知识增强` form.
- When more than six items exist, the `More` button opens Resource Manager directly at Recent Agents.
- A resumable Recent Agent item opens its exact conversation from both Dynamic and Resource Manager.
- Start matching conversation IDs from two known Agent clients, then complete
  only one. Its completion retains the original task and start time while the
  other client's run remains active; a generic `Agent` source may match only
  when the remaining context is unambiguous.
- Codex thread links, Claude Code, Gemini, and Kiro resume commands reopen the expected session.
- A valid `agent-launchers.json` can open Claude Code in a new iTerm tab; an
  invalid file fails visibly without silently falling back to Terminal.app.
- Cursor background-agent links open the exact conversation; local Cursor sessions fall back to the recorded workspace.
- An item without a safe resume target has no open affordance and does not launch a process.
- A failed launch keeps DingDong responsive and shows a visible error.
- The Kiro Stop hook records the session id and workspace needed to resume a conversation.

## Settings and notifications

- Switch among Follow System, English, Simplified Chinese, and Spanish. The
  compact popup, Resource Manager, Connected Devices, Settings, DEV panel,
  native right-click menus, tray menu, window titles, update notes, setup
  sentence, fallback completion message, and macOS permission/recovery dialogs
  update to or reopen in the selected language without mixed-language labels.
- Follow System resolves a supported operating-system language and deliberately
  falls back to English for every unsupported language.
- Spanish layouts keep controls readable without clipping or overflow. Product
  terms such as Prompt, Skill, MCP, Agent, Hook, Bridge, and Token remain
  consistent across screens.
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
- Version checking shows current/latest values, notes, failure state, website,
  and release links. It tries the Cloudflare Worker metadata mirror before the
  website and GitHub fallbacks, and a failed source does not prevent the next
  source from being checked.
- A newer release adds a small orange-red dot beside the popup version; current,
  unknown, checking, and failed states do not show the dot.
- Report a problem and Request a feature open the matching structured GitHub forms.
- A release build shows no lifecycle-statistics prompt. **Settings → Version**
  contains the default-on disclosure and switch, and an existing disabled
  preference remains disabled after upgrading.
- With lifecycle statistics enabled, a fresh successful launch sends exactly one `install`
  event, and the first successful launch after each version/build change sends
  exactly one `upgrade` event. Ordinary launches and feature use send nothing.
  An offline failure is retried with the same event ID on a later launch.
- Disabling lifecycle statistics sends no new event and discards any locally
  pending retry.
- Lifecycle requests contain only the documented random ID, version/build,
  platform, architecture, event type, and time. They contain no clipboard,
  file, Agent, activity, session, or feature-use data; the Worker stores only
  the HMAC installation hash in D1. No third-party analytics SDK or analytics
  build key is present.
- Memory and local storage usage can be refreshed without blocking navigation.
- Storage usage separates Clipboard images, text, files, and archive entries;
  category cleanup preserves the archive.
- macOS Settings and the Dock menu can open the menu-bar recovery assistant,
  and Command-dragging the status item restores its position.
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
- The macOS release app metadata is version `1.5.0` build `55` and bundle id `com.dingdongbuddy.app`.
- The Windows executable metadata is version `1.5.0.55` and product name `DingDong`.
- Node 22 runs `npm ci`, `npm run check`, and a Wrangler dry-run for the PWA
  and relay before the desktop workflow can authorize a release.
- Deploy the device-link Worker from the tested `main` commit either through a
  configured, protected `device-link-production` environment or with an
  authenticated Wrangler session that supplies the exact release SHA. Finish
  before the desktop CI gate completes, or rerun the failed gate after
  deployment. Production
  `/v1/health` must report version `1.5.0` and that exact commit SHA; every
  allowlisted PWA asset hash and the CSP, HSTS, and nosniff headers must match.
- GitHub Pages remains unchanged while packages build. After the GitHub Release
  assets exist, the Release workflow sends a `deploy-release-pages`
  `repository_dispatch` whose `client_payload.source_ref` is the exact release
  tag. The current four-workflow chain exceeds GitHub's automatic `workflow_run`
  chaining limit, so versioned download links must not be exposed before this
  final deployment succeeds.
- The macOS DMG uses the DingDong volume icon and contains a branded background, `DingDong.app`, an `Applications` shortcut, and `安装与权限说明.txt`.
- The DMG background clearly points from DingDong to Applications and explains first launch and Accessibility permission.
- The app copied from the DMG passes `codesign --verify --deep --strict`.
- On Apple Silicon and Intel Macs, the installed app remains alive for at least 30 seconds and creates no new DingDong crash report.
- A tag build creates macOS DMG/ZIP plus Windows Setup/update-feed artifacts without modifying release metadata automatically.
