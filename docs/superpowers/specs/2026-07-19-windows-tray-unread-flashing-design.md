# Windows tray unread flashing design

## Goal

Make unread attention on Windows behave like a native messaging app: keep the bundled white DingDong tray icon, remove numeric badge rendering, flash while unread content remains, and expose the unread count through the hover tooltip. macOS keeps its existing numeric title badge.

## Approved behavior

- Windows never draws an unread number into the 16×16 tray icon.
- The normal and unread states reuse the bundled light/dark DingDong ICO assets; no replacement icon asset is created.
- With one or more unread items, the tray alternates between the normal and hot white icon every 550 ms.
- Flashing continues until the unread count is cleared by opening the DingDong panel.
- New unread events increment the count and keep the existing flash timer running rather than creating another timer.
- The Windows tooltip is:
  - Chinese UI: `DingDong · N 条未读内容`
  - English UI: `DingDong · N unread`
  - Zero unread: `DingDong`
- Taskbar appearance changes reload the correct light/dark assets without resetting the unread count or creating duplicate timers.
- Sleep/resume and taskbar recreation restore the correct flashing state.
- macOS continues to render its existing numeric title badge and does not use the Windows tooltip count behavior.

## Architecture

### Dart unread state

`TrayUnreadController` remains the source of truth for the process-local unread count. Every apply sends the current count; the native Windows plugin derives whether flashing should run from `count > 0`.

The desktop shell gateway converts the count into platform-specific presentation:

- Windows: sends both bundled ICO paths and the unread count to the native plugin, and updates the tooltip.
- macOS: selects the current menu-bar image and title badge exactly as before.

### Windows native tray plugin

The Windows plugin retains two loaded icons:

- the current stable source icon supplied by Dart;
- the alternate attention icon path supplied for flashing.

A single native timer toggles the displayed icon every 550 ms while unread count is greater than zero. Clearing unread stops the timer and restores the stable icon. Refreshes update the source icons without multiplying timers.

The previously added GDI+ numeric badge compositor is removed because Windows no longer draws digits into the tray icon. Transparent-padding cropping remains only if it is required to keep the bundled white mascot visibly larger; otherwise the plugin loads the prepared ICO directly at the native small-icon size.

## Failure handling

- If either Windows icon cannot be loaded, keep the last valid tray icon and return a method-channel error.
- Timer cleanup is mandatory during clear, destroy, and plugin shutdown. Taskbar recreation and resume reapply the current frame while preserving the one active timer.
- Tooltip updates are independent of animation, so the unread count remains available even if animation cannot start.

## Testing

- Controller tests cover count accumulation, refresh, and clear.
- Gateway/channel tests verify Windows receives no numeric badge request, receives the hot/normal icon paths, and formats the localized tooltip.
- Native contract tests verify one 550 ms timer, alternating icons, no GDI+ badge renderer, timer reuse, and cleanup.
- Windows Release build and real taskbar QA verify:
  - no numeric badge at 1, 3, or 9+ unread;
  - visible alternating white icon frames;
  - localized tooltip count through the Windows channel contract;
  - flashing stops after clear;
  - macOS-specific code paths are unchanged.

## Non-goals

- No Windows toast redesign.
- No taskbar-button `FlashWindowEx` behavior.
- No new icon artwork.
- No changes to macOS context menus, title badges, or shortcuts.
