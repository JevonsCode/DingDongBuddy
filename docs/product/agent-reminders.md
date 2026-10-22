# Agent reminders

In **Settings → Notifications**, **Agent completion** and **Needs your input**
are independent. Turn completion off and needs-input on to be interrupted only
when the Agent requests your help. Each type has its own sound, tray style and
color. Existing completion color preferences are preserved.

On macOS unread reminder types follow the same array order as Settings. The first
active type supplies the main capsule's color and its own unread count alongside
the original DingDong artwork. It is not duplicated in the trailing circles and
the capsule does not display a global total. Missing types are skipped; for example,
A/orange becomes primary when completion is absent. A new completion moves A to
the next slot and takes the primary capsule when it precedes A in the array.

There are at most four visible slots including the main capsule. Exactly four
active types show their own colors and counts; above four, show the first three
types and a gray circle with three centered white dots in slot four. The dots
indicate other types, not a count. Hovering the ellipsis for 160ms opens a native
macOS popover below it with the hidden fourth and later types in array order,
showing color, localized name and own count. Up to eight rows fit before scrolling;
the panel remains open while the pointer is inside and closes shortly after exit,
on outside click, when reminders clear, or when overflow no longer exists. Native
popover animation honors Reduce Motion. It does not acknowledge reminders or call `NSApp.activate`. Hover text still lists all active reminder names.
Each circle has a one-point vertical optical inset. Counts stay centered in the
complete circle even when overlapped. `99+` caps large counts; `?` preserves
unknown legacy history until acknowledged. Snapshot acknowledgement preserves
newer counts across restarts.

Bubbles overlap by eight points at rest; hovering opens three-point gaps over a
200ms ease-out transition. Type insertion, removal and promotion use stable IDs
to interpolate position, size, color and opacity over 220ms. Interrupted transitions
continue from their current geometry. System Reduce Motion switches immediately.
Leaving collapses after a short delay and verifies the current screen bounds to
avoid enter/exit loops during resizing. The primary capsule fits its artwork and
number rather than reserving a fixed width.
On Windows the fixed-size notification-area marker uses a check or exclamation
mark; the trailing-bubble layout is macOS-specific. An unread needs-input event
still takes priority over subsequent completion events until acknowledged.

**Static marker** keeps a steady badge. **Soft pulse** alternates two close color
shades; it does not hide the icon. System reduced-animation preferences suppress
the pulse. Completion defaults to static; needs-input defaults to soft pulse and
amber. The macOS bubbles pulse individually according to their saved style;
the primary capsule uses its active type’s color. Hover names and the activity
list identify types that share colors. Gradient styling is not offered.

Tell the Agent, for example: “When you need a decision or action from me, call
DingDong to remind me.” The Agent must explicitly send an `attention` event using
the configured integration. Turning this setting on does not make DingDong read
every conversation, schedule independent AI work or infer that an Agent is
blocked. Completion hooks and explicit attention calls remain distinct sources.

These styles apply to DingDong's tray/menu-bar surface. Operating-system banners
and phone notifications keep their own platform presentation and delivery rules.

## Named reminders

The Reminders list starts with `completion` and `attention`. Their existing
switches, colors, sounds and phone preferences remain authoritative. Add up to
32 custom profiles, each with a name, optional condition hint, enabled switch,
priority (completion or attention), tray style, color, sound and phone switch.
Custom profiles can be deleted; built-ins can be disabled. Attention priority
still wins over a later completion, including after restarting DingDong.

The Agent decides whether a condition such as “build failed” or “review ready”
has occurred. DingDong stores the presets and delivers the selected notification;
it does not evaluate natural-language conditions or call a model to monitor
conversations. The condition hint is descriptive data, not an executable rule.
A custom profile's switch is independent of the two built-in switches. Quiet
hours, voice-task filters and subagent filters still apply. The minimum completion
duration applies to the built-in completion profile, not explicit custom events.

Agent tools:

- `dingdong_list_reminders`: read profiles and imported sounds.
- `dingdong_upsert_reminder`: create or patch by stable `id`. New IDs require a
  `name`. Names are at most 64 characters; condition descriptions at most 160.
- `dingdong_delete_reminder`: delete a custom profile, leaving shared sounds.
- `dingdong_import_reminder_sound`: copy an existing absolute local file into
  DingDong's audio library. AI-prepared files use this same path. Mono/stereo PCM
  WAV only, maximum 15 seconds and 5 MiB; no URL fetching or audio generation.
- `dingdong_notify`: pass `reminderId` to select that profile. Omit `sound` to use
  its saved audio. An unknown ID fails rather than ringing the default reminder.

Example tool arguments (example configuration, not a live user setting):

```json
{"id":"build-error","name":"Build failed","description":"When a build or test fails","kind":"attention","color":"pink","style":"softPulse","sound":"dingDeep"}
```

When that condition occurs:

```json
{"reminderId":"build-error","message":"Tests failed; a decision is needed","source":"Codex"}
```

For imported audio, use `sound: "custom"` and the returned `sounds[].path` as
`customSoundPath` in the profile. At most 64 imported sounds are retained. The
source file can be removed after import. Existing custom sound paths remain
compatible. Colors and audio can be reused by any number of profiles. The sound
dropdown in the reminder editor shows referencing profiles as colored dots at
the right; more than two overlap and the tooltip lists all names, including
disabled profiles. Preview buttons do not select a sound or close the menu.
Import is available at the bottom of the dropdown. There is no separate exposed
sound list. Codex voice-task and subagent switches belong to the Reminders group.

The loopback API provides `GET /settings/reminders` and
`POST /settings/reminders` with action `upsert`, `delete` or `importSound`.
`POST /ding` accepts the same `reminderId`. The older
`POST /settings/reminder-sounds` and `dingdong_set_reminder_sounds` continue to
configure the built-ins. MCP clients must refresh their tool catalog after
upgrading to discover the four new tools; editing saved profiles takes effect
without a client restart. No live Agent client refresh has been assumed.

Spoken-text notifications are tracked in [issue #24](https://github.com/JevonsCode/DingDongBuddy/issues/24) for the next version. There is
no `speechText` field in this version's tool schema.

## Development previews

DEV → Test Panel → Reminder colors and counts offers six colors. Repeated clicks
increment a temporary per-color count; Clear preview removes only those previews.
These are explicitly labeled DEV, do not play sounds, send notifications, change
reminder settings or create activity history. Restarting clears them.
