# Windows visual QA

## Existing Windows platform pass

- Scope: Windows in-app context menus, shortcut hints, popup framing, and adaptive tray icon presentation.
- The Notion-style context-menu reference and the implementation golden were compared at the same 271×483 viewport and open-menu state.
- The final menu uses a 252 px minimum width, 32 px rows, light border and shadow treatment, aligned shortcuts, and no automatic first-item highlight.
- DingDong's action set remains product-specific; differences in copy and item count are intentional.
- Windows shortcut hints use `Ctrl`; macOS keeps `⌘`.
- Windows delegates outer popup corners to the system frame; macOS keeps the existing app-owned frame.
- Keyboard selection, Escape dismissal, dark-theme colors, viewport clamping, and the non-Windows Material fallback remain covered by widget tests.

## Tray unread source truth

- The user rejected the numeric badge because its glyph was unreadable at the Windows notification area's native 16×16 density.
- The approved direction is WeChat-like attention: no number inside the icon, persistent flashing while unread content exists, and the count in the hover tooltip.
- The bundled white DingDong icon must remain the source asset; macOS behavior must not change.

## Tray comparison evidence

- The rejected user screenshot and two live Release frames were inspected together at native scale.
- Rejected state: a small blue numeric badge obscured the mascot and the digit could not be read reliably.
- Revised normal frame: the bundled white mascot fills the available native tray canvas without a badge.
- Revised attention frame: the existing bundled unread ICO alternates with the normal ICO every 550 ms. The frame change is visible without placing text inside the icon.
- Adjacent Orange and Notion tray icons were retained as physical size references. DingDong now reads at a comparable visual scale.

## Tray runtime behavior verified

- A Windows Release build launched successfully and `GET /health` returned `status: ok`.
- `POST /ding` started persistent alternation between the bundled normal and attention ICOs.
- Sixteen native-scale captures over roughly two seconds showed both icon frames recurring; the sequence did not stop after one cycle.
- Pressing `Ctrl+Shift+V` opened the panel. The unread controller cleared the count and the tray returned to the stable normal frame.
- The localized tooltip contract is `DingDong · N 条未读内容` in Chinese and `DingDong · N unread` in English; zero unread restores `DingDong`.

## Tray visual fidelity review

- Asset fidelity: no replacement icon, synthetic badge, text glyph, emoji, SVG, or CSS-drawn asset is used. Both frames come from the existing Windows DingDong ICO set.
- Size: transparent source padding is cropped before the mascot is rendered at 100% of the Windows small-icon canvas.
- Legibility: there is no text inside the 16×16 tray slot, removing the reported blur at its source.
- Motion: one native Windows timer alternates the two frames at 550 ms and remains active only while the unread count is non-zero.
- Platform isolation: numeric tray titles remain in the macOS path; the dual-icon timer and Windows tooltip are confined to the Windows tray implementation.

## Findings

- No actionable P0, P1, or P2 visual issue remains in the reported dark-taskbar state.
- The native light/dark taskbar selector and taskbar appearance refresh path remain covered by automated contract tests.

## Verification checklist

- [x] Remove the Windows numeric badge.
- [x] Reuse the bundled white DingDong ICOs.
- [x] Enlarge the mascot inside the native tray slot.
- [x] Flash continuously while unread content exists.
- [x] Clear and stop flashing when the panel opens.
- [x] Put the unread count in the localized hover tooltip.
- [x] Preserve macOS unread presentation.

## Build checks

- Flutter analyze: no issues.
- Non-golden Flutter tests: 294 passed.
- Windows x64 Release `INSTALL` build: passed, including the rebuilt native tray plugin and MCP bridge.

final result: passed
