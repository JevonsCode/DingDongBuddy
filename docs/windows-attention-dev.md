# Windows reminder capsule preview

This local preview starts from main at `5525050` (1.9.1). It preserves the actual
DingDong reminder IP and adds a visual-only hover capsule using the existing
reminder colors, priority order, and read semantics.

- Reminders use the original `ding-w` / `ding-w2` adaptive tray assets. The whole
  original IP rocks visibly in a short burst, pauses, and repeats while unread.
  No replacement character, redrawn face or tint.
  Native reduced-motion preferences and each reminder's static/pulse choice
  still control animation.
- Hover: a vertical capsule stacks colored circles in reminder priority order.
  Each circle contains its own group's count. Long lists scroll vertically.
  A separate circular badge above it shows only the first-priority group's count
  and uses that group's color. No visible titles, names, footer or app label.
  The capsule does not acknowledge reminders. Clicking uses the existing tray-open
  behavior. Leaving, clearing reminders, or opening the menu dismisses it.
- Counts come from the existing unread controller. Unknown per-group counts from
  legacy data remain unknown (`?`). The numeric badge is not a total count.
  Text is retained in the accessible window name, while Explorer's visible text
  tooltip is blank during reminders.
- The DEV test panel includes a needs-input example and silent color/count
  previews on Windows. Preview counts are temporary and can be cleared separately.

## Local installation

Version `1.9.2-dev.3+76` is a local development artifact, not a public release.
The `-dev` Windows build writes `dingdong-development.marker` and uses the
`DingDong DEV` product identity. This isolates both app files in
`%APPDATA%\DingDong DEV` and path-provider preferences in
`%APPDATA%\Jevons\DingDong DEV` from the stable app.

Install the built Release directory side by side and use its dedicated shortcut.
To stop testing, quit **DingDong DEV** from its tray menu and keep using the
stable DingDong shortcut. Do not configure Agent integrations against the DEV
bridge unless you intentionally want real Agent traffic routed to this preview.

Windows DEV resource synchronization is sandboxed: it neither discovers nor
modifies live Agent configuration, Skill deployments or project Hooks. Its
synchronization state is separate even from an older DEV installation's live
target journals. The Windows startup entry is also named `DingDong DEV`.

Use `scripts/install_windows_dev.ps1` to install a validated Release directory
into `%LOCALAPPDATA%\DingDong DEV\<version>` and create a desktop shortcut.
It refuses a non-DEV binary or an existing version directory.

## Validation

Run Flutter analyze and the reminder/hover bridge, unread-state and DEV panel
tests. `scripts/verify_windows_tray_visuals.cpp` renders the actual Win32 icons
at several DPI sizes. Also build Windows, verify the compiled product identity
and development marker, exercise the isolated local `/ding` API, and manually
check tray hover/click behavior. Unit tests and API responses alone do not prove
the visual interaction.

### Local build environment

This machine has MSVC and CMake but no registered Desktop C++ workload or ATL
headers. This preview uses the pinned Flutter 3.44.7 SDK and direct CMake build.
Only the unchanged secure-storage native dependency is reused from the installed
1.9.1 app; its export, x64 import library and SHA256 are verified in
`build/verification/secure-storage-prebuilt/provenance.json`. The local generated
plugin junction points to a build-only imported target. No Pub cache or SDK
source was modified. A guarded rollback script is beside the provenance file.
All reminder UI and application code is rebuilt from this branch.

The local CMake C++ flags retain the standard Windows defines and add `/utf-8`
for dependencies containing non-ASCII source. Neither the native dependency
overlay nor these local build settings are part of a public release package.
