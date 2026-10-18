# DingDong Android companion

Status: design + prototype (`android_companion/`), 2026-10-18. Not released.

## Why a native app

On 2026-10-18 the installed PWA (WebAPK `org.chromium.webapk.a1dd5179403762e0f_v2`)
on a Xiaomi 13 Ultra (HyperOS 3, Android 16) had never subscribed to push, its OS
notification permission was `ignore`, every launch raised a MIUI "DingDong wants to
open Chrome" prompt, and background delivery depended on Chrome's push channel
surviving HyperOS autostart and battery policies. Web Push also cannot give each
reminder kind its own sound.

A native Android app removes the Chrome dependency and gets first-class Android
notification channels. The user accepted an APK if it is more stable than the PWA.

Goals: reliable, configurable Agent reminders on Android; reuse the existing pairing
and relay protocol unchanged. Non-goals for the first version: clipboard, file
transfer and Studio content (the PWA keeps those).

## Technology: Kotlin with platform APIs

The prototype is Kotlin with plain Android views, OkHttp for the WebSocket and the
Google code scanner for QR. A Flutter Android target was considered and rejected:

- Everything that matters here is native API anyway: foreground services, notification
  channels, battery-optimization exemption, boot receivers, Xiaomi autostart intents.
  In Flutter each of these becomes a platform channel or a plugin with its own
  lifecycle quirks, and a Dart isolate inside a long-running service is the fragile
  part we would be adding.
- The DingDong Flutter app is a desktop app (macOS/Windows, `flutter_webrtc`,
  window/tray plugins). An Android target would drag those dependencies into a
  build matrix that has never targeted mobile, and couples phone releases to desktop
  releases.
- Size and startup: the debug APK is 4.2 MB including the QR scanner; a Flutter
  APK starts around 15–20 MB and boots an engine for what is mostly a service.
- The protocol surface the phone needs is small (AES-GCM envelopes, HMAC token,
  JSON messages), so writing it a third time is cheap. Wire compatibility is pinned by
  unit tests that decrypt envelopes produced by the PWA's own `app-codecs.js`.

Cost: a second language in the repository and a third copy of the envelope codec.

## Pairing reuses the existing protocol

Nothing on the desktop or relay changes for the prototype.

- **Link/QR payload.** The desktop's QR code is
  `https://dingdong.xn--m8txu.com/app/#pair=<base64url JSON>` with
  `{version:1, room, secret, relay, hostId, hostName}`. The app accepts it by scanning
  (Google code scanner), pasting, sharing text to the app, or an `ACTION_VIEW` of the
  link. Validation mirrors `isScannedPairing` in `docs/app/pairing-state.js` (room
  20–64 base64url chars, 43-char secret, http(s) relay without credentials or hash).
- **Transport.** The app joins `wss://<relay>/v1/rooms/<room>?side=peer` exactly like
  `docs/app/app-connection.js`. Frames are `{type:"relay"|"data"|"signal"}`; data
  payloads are `base64url(nonce12 || AES-256-GCM(JSON))` keyed by the pairing secret
  (`app-codecs.js`, `secure_message_codec.dart`).
- **Handshake.** On `host_joined` the app sends `hello` with
  `device:{id, name, kind:"phone", platform:"android"}`,
  `agentNotificationsEnabled:true`. The desktop's `_handleHello` registers it as a new
  phone for that room and replies `welcome`. The app then sends
  `settings.update {transportPreference:"serviceRelay"}` so the desktop stops offering
  WebRTC to this device (the app never answers offers; data rides the relay).
- **Events.** `agent.completed` messages are decoded with the same fallbacks as
  `notification-policy.js`. Tapping a notification sends `agent.seen {activityIds}`.
  Message ids are de-duplicated locally (the desktop can resend on reconnect).
- **Coexistence with the PWA.** Each desktop pairing creates a fresh room, so the
  companion and the PWA are separate linked devices and never fight over a room. Two
  clients on the *same* room would trigger the relay's
  `1008 "Replaced by a newer connection"`; the app treats that as "re-scan needed"
  and does not reconnect-loop. After installing the companion, turn off Agent
  reminders for the PWA device on the desktop to avoid double alerts.

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
- The desktop's quiet hours, minimum task duration and per-kind phone push stay on
  the desktop. The phone's own control is per channel in Android settings (sound,
  vibration, lock screen, Do Not Disturb override), reachable from the app.
- Android freezes a channel's sound and vibration after creation, so changing the
  bundled defaults means a new channel id (`_v3`) and deleting the old one. Sounds
  are referenced as `android.resource://<pkg>/raw/<name>`, never by numeric `R.raw`
  id, because the frozen URI must survive rebuilds (v1 used ids and is deleted on
  start). The per-message `vibrate` flag is not honoured individually; vibration is
  a channel setting.
- Sounds are generated by `android_companion/tools/generate_sounds.mjs` (original,
  no licensing questions).

## What the PWA keeps doing

- iOS/iPadOS (home-screen web app with Web Push) and desktop browsers.
- Android users who do not install the APK.
- Clipboard, file transfer, Agent list and Studio content on every platform. The
  companion is notification-only until it proves itself.

## Prototype

`android_companion/` (Gradle 8.14, AGP 8.13, Kotlin 2.2, minSdk 26, targetSdk 36):

| File | Role |
|---|---|
| `Pairing.kt` | Link parsing and validation |
| `EnvelopeCrypto.kt` | AES-GCM envelopes and the push token |
| `RelayConnection.kt` | Peer-side relay socket, handshake, backoff reconnect |
| `RelayService.kt` | Foreground service, one connection per computer, network-change reconnect |
| `AgentEvent.kt`, `AgentNotifications.kt` | Event decoding and per-kind channels |
| `MainActivity.kt` | Health checks, pairing, per-channel test buttons, recent events |
| `BootReceiver.kt` | Restart after reboot or update |
| `res/drawable-nodpi/dingdong_logo.png` | Launcher icon: the PWA's `docs/assets/dingdong-pwa-512.png`, inset into an adaptive icon |
| `tools/fake_desktop_host.mjs` | Desktop stand-in that speaks the real protocol through the real relay |

Build and test (JDK 21 from Android Studio):

```bash
cd android_companion && ./gradlew :app:testDebugUnitTest :app:assembleDebug
```

End-to-end without the desktop UI:

```bash
node android_companion/tools/fake_desktop_host.mjs --state /tmp/fake-host.json --seconds 90
```

It prints a pairing link; open it in the app (paste, or
`adb shell am start -n com.dingdongbuddy.companion/.MainActivity -a android.intent.action.VIEW -d '<link>'`).
It then sends a completion, an attention and a `silent` event.

### Verification

- Unit tests (9): envelopes sealed by the PWA's `app-codecs.js` open in Kotlin, the
  push token matches, pairing links parse/reject like the PWA, and `silent` /
  `notificationKind` / `needsUserAttention` map to the right behaviour.
- Android lint: 0 errors. It caught an API 28 `Handler.postDelayed` overload; the
  emulator run caught an API 31 `setForegroundServiceBehavior` crash on Android 11.
  Both are fixed.
- Emulator (Android 11, `google_apis` x86_64) against the production relay with
  `fake_desktop_host.mjs`: pairing from the link, `hello` → `welcome` →
  `settings.update {transportPreference:"serviceRelay"}`, completion posted on
  the completion channel, attention on the attention channel (heads-up), the `silent`
  event recorded in the app without a system notification, and the service
  reconnecting from the stored pairing after an app reinstall.
- Xiaomi 13 Ultra (HyperOS 3, Android 16), same fake host and production relay:
  paired from the link (default device name "Xiaomi 13 Ultra"), `hello`/`welcome`/
  `settings.update` exchanged, "Agent 完成" posted on the completion channel
  (importance 3) and "Agent 需要你处理" on the attention channel (importance 4,
  heads-up), and the `silent: true` event logged `shown=false` with no system
  notification. The foreground "已连接 1 台电脑" notification sat in the shade.
  Installing needed the user to tap "继续安装": HyperOS's USB-install dialog
  auto-rejects after ~10 s and ignores injected input even with
  `persist.security.adbinput=1`. A reinstall also reset `POST_NOTIFICATIONS` to
  denied; the health check shows it and offers "允许通知".
- Not yet tested with the real desktop app (needs someone to open its "connect
  phone" QR); the fake host mirrors `device_link_controller.dart` message shapes.

## What blocks a release

- **Signing.** No release keystore exists. Needs a keystore kept outside the repo,
  a signing config fed from CI secrets, and a decision on distribution (GitHub
  Releases sideload vs. Play). Play would also require the `specialUse` FGS
  justification and a Data safety form.
- **Install friction on HyperOS.** Sideloaded APKs need "install unknown apps"
  consent, and USB installs need an on-device tap that `adb input` cannot press.
  First-run must walk the user through autostart and battery "no restrictions";
  the app links to both screens but cannot verify autostart.
- **Push credentials (option A).** Firebase project, `google-services.json`, FCM
  service-account key as a Worker secret.
- **Relay changes.** FCM registration and sender (option A); an
  `/.well-known/assetlinks.json` with the release certificate fingerprint so the
  desktop's https QR link opens the app directly instead of the browser.
- **Desktop.** Recognise the companion (`platform:"android"` is all it sends today)
  so the device list can say "Android app", default its transport to service relay,
  and offer to disable reminders for an older PWA pairing of the same phone.
- **Two "DingDong" icons.** The companion and the PWA share the name and logo, so a
  phone with both shows two identical icons. Release should either label the app
  distinctly or tell users to uninstall the PWA once the companion is paired.
- **App hardening.** Keystore-wrapped pairing secrets (currently private prefs
  excluded from backup), English/Spanish strings (UI is Chinese only), QR scanning
  without Google Play services (CameraX + ZXing) for GMS-less phones, `agent.state`
  list, accessibility pass, update checks.
