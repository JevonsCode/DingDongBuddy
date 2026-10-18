# DingDong Android companion

Status: Flutter app in `mobile/` (0.2.0), 2026-10-19. Not released. It replaces the
Kotlin prototype (`android_companion/`, 2026-10-18), which proved the pairing,
relay and notification-channel path on the user's phone before it was removed.

## Why a native app

On 2026-10-18 the installed PWA (WebAPK `org.chromium.webapk.a1dd5179403762e0f_v2`)
on a Xiaomi 13 Ultra (HyperOS 3, Android 16) had never subscribed to push, its OS
notification permission was `ignore`, every launch raised a MIUI "DingDong wants to
open Chrome" prompt, and background delivery depended on Chrome's push channel
surviving HyperOS autostart and battery policies. Web Push also cannot give each
reminder kind its own sound.

A native Android app removes the Chrome dependency and gets first-class Android
notification channels. The user accepted an APK if it is more stable than the PWA,
then asked for it to look like the PWA and to be built with Flutter.

Goals: reliable, configurable Agent reminders; the PWA's clipboard, send and Agent
views; reuse the existing pairing and relay protocol unchanged.

## Technology: Flutter, with a little Kotlin

The first prototype was plain Kotlin views. Its UI looked like a demo, and the
user asked for Flutter so the phone app shares a toolkit (and, where it is clean,
code) with the desktop. The Flutter version keeps everything the prototype proved:

- **Shared Dart protocol.** `packages/dingdong_link_protocol` holds the pure-Dart
  wire format moved out of the desktop: `SecureMessageCodec` (AES-256-GCM
  envelopes), relay frame encoding and its 256 KB limit, the relay socket URI,
  replacement detection and `DevicePairingPayload`. The desktop files re-export it
  (`secure_message_codec.dart`, `device_link_models.dart`,
  `device_link_session.dart`), so desktop imports did not change; its 83
  device-link tests pass unchanged. The phone no longer has its own copy of the
  codec. Package tests decrypt an envelope sealed by the PWA's `app-codecs.js`, so
  browser, desktop and phone stay wire-compatible.
- **One socket owner.** `flutter_foreground_task` runs a foreground service with its
  own Flutter engine and Dart isolate. That isolate (`CompanionEngine`) owns the relay
  sockets, state, downloads and notifications. The UI isolate only renders
  snapshots and sends commands, because the relay allows one peer socket per room
  and the service must keep running after the UI closes.
- **Native where Android demands it.** Kotlin creates the notification channels
  (`CompanionChannels.kt`, ported from the prototype) so their sounds are frozen as
  name-based `android.resource://…/raw/<name>` URIs. A method channel in
  `MainActivity.kt` covers what Dart cannot do: the Google code scanner, saving to
  public Downloads through MediaStore, HyperOS autostart and battery shortcuts, and
  pairing links opened from other apps. `flutter_local_notifications` posts to the
  Kotlin-created channels.
- **Relay only.** The app never answers WebRTC offers, so `flutter_webrtc` stays out
  of the APK. After `welcome` it sends `settings.update
  {transportPreference:"serviceRelay"}` so the desktop stops offering. Files use
  the desktop's v1 messages (`file.start/chunk/end`, 32 KB chunks, 25 MB cap). The
  resumable v2 protocol is a follow-up.

Cost: an APK of about 20 MB (debug builds are larger), and a background isolate
with its own engine.

## Pairing reuses the existing protocol

Nothing on the desktop or relay changed.

- **Link/QR payload.** The desktop's QR code is
  `https://dingdong.xn--m8txu.com/app/#pair=<base64url JSON>` with
  `{v:1, room, secret, relay, hostId, hostName}`. The app accepts it by scanning
  (Google code scanner), pasting, sharing text to the app, or an `ACTION_VIEW` of
  the link. `DevicePairingPayload.parseInput` validates it like the PWA's
  `isScannedPairing`, and now accepts `version` as well as `v`, as the PWA does.
- **Transport.** The app joins `wss://<relay>/v1/rooms/<room>?side=peer` like
  `docs/app/app-connection.js`. Data payloads are `base64url(nonce12 ||
  AES-256-GCM(JSON))` keyed by the pairing secret.
- **Handshake.** On `host_joined` the app sends `hello` with
  `device:{id, name, kind:"phone", platform:"android"}` and no `fileTransferVersion`,
  so the desktop picks the v1 file messages. The desktop registers the phone and
  replies `welcome`, then `clipboard.snapshot` / `clipboard.upsert` and `agent.state`.
- **Messages handled.** `clipboard.snapshot`, `clipboard.upsert`, `agent.completed`,
  `agent.state`, `request.rejected` and `file.start/chunk/end` for downloads.
  The app sends `clipboard.create`, `file.start/chunk/end`, `file.request`,
  `agent.seen` (when the Agent tab is visible, like the PWA) and `settings.update`.
- **Coexistence with the PWA.** Each desktop pairing creates a fresh room, so the
  app and the PWA are separate linked devices. Two clients on the *same* room
  trigger the relay's `1008 "Replaced by a newer connection"`; the app shows
  "连接已转移到另一个设备" with an "在此连接" button and does not reconnect-loop.

## Look: the PWA's screen, natively

`mobile/lib/ui/tokens.dart` copies `docs/app/styles.css` `:root` (background
`#f4f3ef`, surface `#fffefc`, accent `#2b5877`, radii 9–17, type 10–23 px), and the
widgets follow the PWA's structure: header with mascot, computer name and online
dot; offline and notification banners; the 电脑剪贴板 / Agent 提醒 segmented tabs
with counts and a swipeable pager; "收到的内容" cards with 复制/下载; 正在运行 and
完成记录 with the Agent timeline; the bottom composer with file button, input and
发送; and the device switcher, settings, paste-link and delete dialogs. Assets are
the PWA's own mascots and symbols.

The PWA has no dark theme; the app follows the system theme with a derived dark
palette (background `#15181b`, surface `#1d2125`, accent `#7fb0d0`). Mascot drawings
sit on a light tile in dark mode so their navy outlines stay visible.

App-only additions: a "保持后台连接" banner when battery optimization applies, and
settings rows for channel sounds, per-channel test reminders and background running
(HyperOS autostart and battery policy shortcuts).

## Push channel options

| | A. FCM via the relay | B. Foreground-service WebSocket | C. Vendor push (Mi Push, HMS, …) |
|---|---|---|---|
| Works when app is killed / swiped | Yes for notification messages; data messages need the app to be startable (HyperOS autostart) | No — the service *is* the channel; needs autostart + "no restrictions" battery policy to survive | Yes on that vendor's ROM (system-level channel) |
| Custom sound per kind | Yes (data message → app posts on its channel, or notification message with `android_channel_id`) | Yes | Yes (channel id), vendor-specific setup |
| End-to-end encryption | Yes for data messages (relay forwards the existing sealed envelope); generic text only if a visible notification block is added | Yes | Payload goes through vendor servers; same split as FCM |
| Credentials | Firebase project, service-account key as a Worker secret, `google-services.json` in the app | None | Per-vendor developer accounts, app review, China mainland entity for some |
| Relay changes | New registration kind + FCM HTTP v1 sender in `device_link_relay/src/worker.js` | None | One sender per vendor |
| Network dependence | Needs Google connectivity (`mtalk.google.com`); unreliable on mainland networks without a proxy. The user's Chrome Web Push already depends on FCM | Only the relay | Works on mainland networks |
| Battery | Best (shared system socket) | One idle socket with 25 s pings; the relay uses hibernatable Durable Object sockets so server cost stays low | Best on that ROM |
| Visible cost | None | Persistent "connected" notification (channel importance MIN, user can hide it) | None |
| Play Store | Fine | `specialUse` FGS needs a policy justification | Fine |

**Recommendation.** Ship **B** first: it works today against the production relay,
needs no credentials, and on a phone the user has configured (autostart on, battery
"no restrictions") it is the most predictable path on HyperOS. Add **A** as the
background fallback once there is a Firebase project: the desktop already POSTs a
sealed envelope to `/v1/push/<room>`; the relay would accept a second registration
shape `{kind:"fcm", token, fcmToken}` (authorized by the same HMAC push token) and
send an FCM HTTP v1 *data* message carrying the envelope, high priority, TTL 24 h.
Consider **C** only if a wider audience on mainland ROMs needs killed-app delivery.

## Notification channels

| Channel id | Name | Importance | Sound | Vibration |
|---|---|---|---|---|
| `agent_completion_v2` | Agent 完成 | DEFAULT (sound, no heads-up) | `res/raw/agent_completion.wav` (soft two-note chime) | 0-120-80-120 ms |
| `agent_attention_v2` | Agent 需要你处理 | HIGH (heads-up) | `res/raw/agent_attention.wav` (two pairs of beeps) | 0-300-150-300-150-600 ms |
| `relay_connection_v1` | 连接状态 | MIN | none | none |

- Kind comes from `notificationKind == "attention"` or `needsUserAttention == true`;
  everything else is completion, matching the PWA.
- `silent: true` (set by the desktop's per-kind rules when `alertPhone` is false)
  raises no system notification; the event is only added to the in-app list.
- History from `agent.state` never notifies; only a first-seen `agent.completed` does.
- The desktop's quiet hours, minimum task duration and per-kind phone push stay on
  the desktop. On the phone, each channel's sound, vibration, lock screen and Do Not
  Disturb override are set in Android settings, reachable from the app.
- Android freezes a channel's sound and vibration after creation, so changing the
  bundled defaults means a new channel id (`_v3`) and deleting the old one. Sounds
  are referenced by name, never by numeric `R.raw` id, so the frozen URI survives
  rebuilds; `res/raw/keep.xml` keeps them through resource shrinking. The
  per-message `vibrate` flag is not honoured individually; vibration is a channel
  setting.
- Sounds are generated by `mobile/tool/generate_sounds.mjs` (original, no licensing
  questions).

## What the PWA keeps doing

- iOS/iPadOS (home-screen web app with Web Push) and desktop browsers.
- Android users who do not install the APK.
- Studio content tabs, image preview, resumable large-file transfer (v2) and LAN
  direct WebRTC, which the app does not implement yet.

## Layout

| Path | Role |
|---|---|
| `packages/dingdong_link_protocol/` | Pure-Dart wire format shared with the desktop |
| `mobile/lib/link/relay_peer.dart` | Peer-side relay socket, handshake, backoff reconnect, replacement handling |
| `mobile/lib/link/companion_engine.dart` | Service-isolate state: computers, clipboard, Agent events, sends, downloads |
| `mobile/lib/link/companion_store.dart` | Persistence (pairings, Agent history, notified ids) in app-private storage |
| `mobile/lib/service/companion_service.dart` | Foreground service entry point and notification posting |
| `mobile/lib/ui/` | PWA-matching screens, tokens, dialogs |
| `mobile/android/.../CompanionChannels.kt` | Notification channels with name-based sounds |
| `mobile/android/.../MainActivity.kt` | QR scan, Downloads, settings shortcuts, launch links |
| `mobile/tool/fake_desktop_host.mjs` | Desktop stand-in that speaks the real protocol through the real relay |

Build and test (Flutter 3.44.6, JDK 21 from Android Studio):

```bash
cd mobile && flutter test && flutter build apk --debug
```

`mobile/android/gradle.properties` sets `kotlin.incremental=false` because the pub
cache and the checkout sit on different Windows drives here, which breaks Kotlin's
incremental caches for plugins.

End-to-end without the desktop UI:

```bash
node mobile/tool/fake_desktop_host.mjs --state /tmp/fake-host.json --seconds 300 --out /tmp/received
```

It prints a pairing link to open in the app (paste, or
`adb shell am start -n com.dingdongbuddy.companion/.MainActivity -a android.intent.action.VIEW -d '<link>'`).
It then shares a text item and a downloadable file, sends completion, attention and
`silent` reminders and an `agent.state`, serves `file.request`, and logs and saves
whatever the phone sends.

### Verification

Automated:

- `packages/dingdong_link_protocol`: 6 tests, including an envelope sealed by the
  PWA's `app-codecs.js` and both pairing-payload key spellings.
- `mobile/test/companion_engine_test.dart`: 8 tests against a fake relay (pairing
  and hello, per-kind channels, `silent`, history never re-notifying, clipboard,
  text and v1 file send, download, drop/replacement reconnect, restart).
- Desktop: the 83 device-link tests and the full suite (1184 passed, 8 skipped,
  goldens excluded as usual on Windows) pass after the protocol extraction.
- Relay: 116 tests, including 3 new ones for stale sockets (below).

On devices (2026-10-19), against the production relay unless noted:

| Check | Emulator (Android 11) | Xiaomi 13 Ultra (HyperOS 3, Android 16) |
|---|---|---|
| Pair from the desktop link (`ACTION_VIEW`) | Pass | Pass |
| Notification permission from the pairing flow | Pass | Pass (user tapped 允许) |
| Clipboard items shown (`clipboard.snapshot/upsert`) | Pass | Pass |
| Copy a text item | Pass (toast, clipboard) | Not verified |
| Download a shared file to Downloads | Pass, SHA-256 matches | Pass, SHA-256 matches |
| Send text (`clipboard.create`) | Pass | Not run (see below) |
| Send a file (v1, 112 KB) | Pass via local relay, SHA-256 matches | Not run (see below) |
| "Agent 完成" on `agent_completion_v2` | Pass | Pass (importance 3) |
| "Agent 需要你处理" on `agent_attention_v2` | Pass | Pass (importance 4, heads-up) |
| `silent: true` raises no notification | Pass | Pass |
| `agent.seen` when the Agent tab is visible | Pass | — |
| Two computers, switcher | Pass | — |
| Dark mode | Pass | — (not toggled on the user's phone) |
| Foreground service type `specialUse` | Pass | Pass |
| Reconnect after Wi-Fi drop | App reconnects in 3 s; see relay bug | Not run (phone shared with another session) |
| Force-stop | Service stops; reopening reconnects in ~2 s | Same, reconnected in 3 s |
| Reboot | Service restarts and reconnects 21 s after boot, app not opened | Not run |
| App update | Service back in 7 s, app not opened | — |
| Pair with the real desktop app | Not run: needs one click in the desktop | Same |

Not run on the phone: midway through, HyperOS stopped accepting injected
touches (taps and swipes, including on the status bar) while key events still
worked, so text and file sending were not exercised there. The same code paths
pass on the emulator.

**Relay bug found and fixed (not deployed).** After the phone's network dropped
silently and it reconnected, the desktop never received the phone's
`settings.update`, and no further reminders arrived. The relay's Durable Object
keeps a replaced or dead socket listed after `close()`, and `webSocketMessage`
forwarded to every listed socket without a guard, so `send()` threw on the stale
socket first ("Can't call WebSocket send() after close()") and the live socket
never got `welcome` or anything after it. The production room stayed wedged and
answered later connections with error 1101. The PWA is exposed to the same bug.
`device_link_relay/src/worker.js` now skips stale sockets (`broadcast`) and guards
the replacement close. In an A/B run against `wrangler dev`, the old worker
reproduced the stall and the fixed one delivered `welcome` 1 s after the network
returned. Deploying the Worker is the user's call.

## What blocks a release

- **Signing.** No release keystore exists; release builds use the debug key. Needs a
  keystore kept outside the repo, a signing config fed from CI secrets, and a
  decision on distribution (GitHub Releases sideload vs. Play). Play would also
  require the `specialUse` FGS justification and a Data safety form.
- **Install friction on HyperOS.** Sideloaded APKs need "install unknown apps"
  consent, and USB installs need an on-device tap that `adb input` cannot press.
  First-run must walk the user through autostart and battery "no restrictions";
  the app links to both screens but cannot verify autostart.
- **Force-stop.** Android does not restart a force-stopped app's service; reminders
  resume when the user opens the app again (it restarts the service from the saved
  pairings). Reboot and app updates restart it automatically.
- **Push credentials (option A).** Firebase project, `google-services.json`, FCM
  service-account key as a Worker secret.
- **Relay deploy.** The stale-socket fix above must be deployed before release.
- **Relay changes.** FCM registration and sender (option A); an
  `/.well-known/assetlinks.json` with the release certificate fingerprint so the
  desktop's https QR link opens the app directly instead of the browser.
- **Desktop.** Recognise the companion (`platform:"android"` is all it sends today)
  so the device list can say "Android app", default its transport to service relay,
  and offer to disable reminders for an older PWA pairing of the same phone.
- **Two "DingDong" icons.** The app and the PWA share the name and logo, so a phone
  with both shows two identical icons. Release should either label the app
  distinctly or tell users to uninstall the PWA once the app is paired.
- **App hardening.** Keystore-wrapped pairing secrets (currently an app-private
  JSON file excluded from backup), English/Spanish strings (UI is Chinese only, like
  the PWA), QR scanning without Google Play services for GMS-less phones, resumable
  v2 file transfer, image preview, accessibility pass, update checks.
