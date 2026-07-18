# Windows Platform Visuals Design

Date: 2026-07-18
Status: Approved

## Goal

Give DingDong a deliberate Windows experience while preserving all current
macOS behavior. The Windows work covers shortcut hints, the root window frame,
the notification-area icon, and in-app secondary-click menus.

## Scope

1. Show shortcut hints while the platform's primary shortcut modifier is held:
   Command on macOS and Control on Windows/Linux.
2. Keep existing shortcut actions working, including Control plus a digit on
   Windows.
3. Let the Windows system frame own the main popup's outer corners instead of
   clipping the Flutter root surface to DingDong's custom radius.
4. Select a high-contrast Windows tray icon from the actual taskbar brightness,
   with a clearly visible unread variant.
5. Render every in-app Windows secondary-click menu with one Notion-inspired
   Flutter menu component that follows DingDong's light/dark theme.

## Non-goals

- Do not replace the Windows notification-area icon's native context menu.
- Do not restyle ordinary toolbar/dropdown menus unless they also serve an
  in-app secondary-click interaction.
- Do not change the macOS native context-menu gateway, template tray icon,
  window surface, or Command shortcut behavior.
- Do not require Windows App SDK or WinUI dependencies.

## Platform boundaries

### Primary shortcut modifier

A shared platform helper is the single source of truth for both hint visibility
and shortcut activation. It reports Meta/Command on macOS and Control on
Windows/Linux. The shell listens for both modifier key-down and key-up events so
the hint UI follows the key state immediately. The existing macOS native
modifier channel remains supported and unchanged.

### Main popup surface

On Windows only, the Flutter root Material has no custom outer radius, outer
border, or anti-aliased shape clip. Its background fills the native client area.
The standard Windows frame determines the outer shape: rounded on Windows 11
when supported and rectangular on Windows 10. Inner cards, buttons, tabs, and
other DingDong components retain their current radii.

Other platforms keep the existing custom popup shape.

### Taskbar appearance bridge

The Windows runner exposes taskbar appearance through a small platform channel.
It samples multiple pixels adjacent to the notification-area icon rectangle and
uses median relative luminance to classify the current taskbar as light or dark.
It refreshes after startup, taskbar recreation, theme changes, settings changes,
and DWM colorization changes.

If live sampling is unavailable, the bridge falls back to the Windows system
theme setting. If icon loading fails, DingDong keeps the last valid icon instead
of removing the tray entry.

Flutter combines taskbar brightness and unread state to select one of four ICO
assets:

- white monochrome mascot on a dark taskbar;
- dark monochrome mascot on a light taskbar;
- each base icon with a small warm-yellow unread dot and a contrasting outline.

### Windows in-app context menus

All Windows in-app secondary-click flows use a shared Flutter menu renderer.
Business modules continue to provide actions and handle selected results; the
renderer owns only presentation, positioning, keyboard interaction, and route
dismissal. macOS continues to route these actions through
`NativeDesktopContextMenuGateway`.

The Windows menu supports normal, disabled, checked/toggle, shortcut, separator,
and destructive entries. Existing menu call sites migrate to the shared entry
model without moving edit/delete/archive business logic into the renderer.

## Visual specification

The context menu is 220-280 logical pixels wide and grows only when its labels
require it. It uses a 10 px radius, a subtle 1 px border, a soft two-layer
shadow, and 6 px outer padding. Action rows are approximately 34 px high with a
16 px leading line icon, 14 px label, and optional 12 px muted shortcut aligned
to the trailing edge. Separators are low-contrast one-pixel lines. Destructive
actions use red foreground and a light red hover/focus background.

Colors follow DingDong's light or dark theme. The menu opens next to the pointer,
clamps to the visible screen, and supports hover, arrow navigation, Enter,
Escape, and outside-click dismissal. Animation is a short fade/scale transition
and must respect reduced-motion behavior.

## Data flow and failure behavior

1. A pointer secondary-click produces an ordered list of menu entries.
2. On macOS, the existing native gateway receives the list.
3. On Windows, the shared Flutter renderer opens in the active overlay and
   returns the selected action identifier.
4. The originating feature executes its existing domain action.

Taskbar appearance changes independently produce a light/dark classification.
The tray controller combines that classification with its unread state and
applies the corresponding ICO. Duplicate classifications do not reload the icon.

Menu positioning clamps both axes. Missing icons fall back to aligned empty
space so text columns remain stable. A taskbar sampling or theme lookup failure
falls back deterministically and does not interrupt application startup.

## Testing and verification

- Widget tests prove Control key-down/up shows and hides hints on Windows and
  that Control plus a digit still selects the expected clipboard row.
- Existing Command tests remain green, with an explicit macOS regression case.
- Menu tests cover light/dark colors, row structure, separators, destructive
  styling, keyboard navigation, dismissal, and edge clamping.
- Tray selection tests cover all four brightness/unread combinations and the
  fallback path. Native Windows source/build verification covers refresh
  messages and icon-load failure handling.
- A Windows Release smoke test verifies the system-owned outer corners, both
  taskbar contrast variants, the unread marker, and every in-app secondary-click
  entry point.
- Run the complete static analysis and non-golden test suite. macOS-specific
  tests must remain unchanged and pass.

## Acceptance criteria

- Holding Control after opening the Windows panel visibly reveals shortcut
  hints; releasing it hides them.
- No dark-on-dark or light-on-light Windows tray icon is produced across taskbar
  color/theme changes.
- Windows 11 shows only the system's outer corner treatment, with no second
  Flutter radius or transparent fringe.
- Every in-app Windows secondary-click menu has the approved compact,
  Notion-inspired presentation in both themes.
- macOS window, menu, tray, and Command-key behavior is unchanged.
