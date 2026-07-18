# Windows Tray Unread Badge and Attention Motion

**Date:** 2026-07-19

**Status:** Approved direction, pending implementation plan

**Scope:** Windows notification-area icon only

## Goal

Make a new DingDong notification visible from the Windows notification area in the same functional sense as the existing macOS menu-bar treatment:

- show the accumulated unread notification count on the icon;
- play a brief, noticeable but restrained attention motion for every new notification;
- make the built-in DingDong mascot occupy slightly more of the Windows tray slot;
- preserve the existing automatic light/dark taskbar adaptation;
- leave all macOS visuals and behavior unchanged.

## Current Behavior and Root Cause

`TrayUnreadController` already increments and clears a shared unread count. The desktop shell gateway sends the count to macOS as a tray title, but Windows currently receives only a single static unread ICO. The Windows native tray plugin loads that ICO at the system small-icon size and has no count-compositing or animation state.

The normal Windows tray artwork also retains roughly one quarter of its canvas as transparent padding, making the mascot appear smaller than neighboring notification-area icons.

## Approved Visual Direction

### Built-in mascot

- Reuse the existing DingDong mascot artwork. Do not redraw, replace, or reinterpret the icon.
- Preserve the existing light/dark taskbar variants: a light mascot on dark taskbars and a dark mascot on light taskbars.
- Increase the mascot's visible footprint by about 10%, targeting an occupied alpha-bounds width/height of roughly 84–86% of the tray canvas instead of the current roughly 75%.
- Keep enough safe area for Windows scaling and for the unread badge; no clipping at 100%, 125%, 150%, or 200% display scaling.

### Unread number badge

- When unread count is zero, show no badge.
- Show `1` through `9` for counts 1–9.
- Show `9+` for counts above 9 because a longer value is not reliably legible in a Windows notification-area slot.
- Place the badge at the lower-right of the mascot, inset from the canvas edge so it survives Windows resampling.
- Use the product's existing blue accent family with a white, semibold Segoe UI number and a one-device-pixel contrasting keyline. The keyline changes for light/dark taskbars so the badge remains distinct from both the mascot and the taskbar.
- Compose the badge at native Windows icon sizes rather than shipping a separate hand-authored mascot or a large matrix of numbered ICO files.

### Attention motion

- Play a short vertical bounce each time a new notification is received, including when unread count is already non-zero.
- Use three diminishing bounces over approximately 600 ms.
- Maximum displacement is two physical pixels at the system small-icon size; later bounces use one pixel.
- End on the stable numbered icon. Do not loop, blink continuously, or consume CPU after the animation completes.
- If another notification arrives during the motion, immediately update the badge count and restart the short motion from the beginning so the newest event remains noticeable.
- Taskbar theme changes and Explorer restarts restore the current stable badge without replaying the attention motion.

## Interaction and State Rules

1. App starts with the normal enlarged Windows icon and no badge.
2. Every notification increments unread count, updates the badge, and starts/restarts the attention motion.
3. Opening/focusing the DingDong panel clears the count, stops any active motion, and restores the normal enlarged icon.
4. Right-clicking the tray icon does not clear unread state.
5. Changing taskbar brightness refreshes the correct icon contrast while preserving the current count.
6. Explorer/taskbar recreation restores the current stable icon and count.
7. macOS continues to use its existing menu-bar title badge and receives no Windows animation arguments or asset changes.

## Technical Direction

### Dart state boundary

- Keep `TrayUnreadController` as the source of truth for unread count.
- Extend the tray icon call with Windows-only presentation data: unread count and whether this update should request attention motion.
- Separate state refresh from notification arrival so brightness refreshes and taskbar restoration do not accidentally trigger animation.
- Clamp only the displayed Windows label to `9+`; retain the actual unread count in Dart so state semantics stay correct.

### Windows native rendering

- Extend the bundled `tray_manager` Windows implementation to build an `HICON` from the existing selected ICO plus an optional badge.
- Render into a 32-bit premultiplied-alpha DIB at the system small-icon dimensions, using GDI/GDI+ primitives and Segoe UI for the badge label.
- Cache/reuse the stable composed icon for the current base icon, count label, size, and taskbar contrast.
- Drive the finite bounce with a window timer and `Shell_NotifyIcon(NIM_MODIFY, ...)`; destroy replaced `HICON`, bitmap, font, brush, and timer resources deterministically.
- Stop the timer when unread state is cleared, the icon is destroyed, or the plugin is disposed.

## Accessibility and Quality Constraints

- The badge must remain recognizable against both dark and light taskbars and at common Windows scale factors.
- Motion is finite and low-amplitude to avoid distraction. No persistent flashing.
- Tooltip and context-menu behavior remain unchanged.
- The icon must not disappear or leak GDI handles after repeated notifications, theme changes, sleep/resume, or Explorer restart.

## Verification

### Automated

- `TrayUnreadController` tests cover increment, clear, count above nine, and refresh without attention replay.
- Dart tray-manager contract tests cover Windows-only count and animation arguments and confirm macOS behavior is unchanged.
- Windows native unit/contract tests cover display-label clamping, bounce-frame sequence, stable final frame, cancellation, and resource replacement boundaries where practical.
- Existing full Flutter test suite, analyzer, and Windows build must pass.

### Windows visual QA

- Compare the supplied taskbar screenshot with a same-state implementation screenshot at the same taskbar scale.
- Verify the normal mascot appears slightly larger and visually balanced beside neighboring tray icons.
- Trigger one, two, three, and ten unread notifications and verify `1`, `2`, `3`, and `9+` respectively.
- Observe the three-bounce motion for a new notification and for a second notification while unread state already exists.
- Open the panel and verify immediate return to the unbadged icon.
- Repeat on light and dark taskbars and at 100% and at least one high-DPI scale.
- Record the final comparison and outcome in `design-qa.md`; final result must be `passed` before completion.

## Non-Goals

- No redesign of the DingDong mascot.
- No change to macOS menu-bar visuals, title badge, shortcuts, or behavior.
- No Windows toast redesign.
- No continuous taskbar animation or sound changes.
- No new user-facing setting for the badge or motion in this iteration.
