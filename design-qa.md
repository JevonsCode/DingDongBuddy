# Windows visual QA

- Date: 2026-07-18
- Scope: Windows in-app context menus, shortcut hint labels, popup framing, and adaptive tray icon presentation.
- Reference: `C:\Users\jevons\AppData\Local\Temp\codex-clipboard-69282919-92e9-4065-a3ee-b566fb036cf8.png`
- Implementation capture: `test/core/widgets/goldens/windows_context_menu_reference.png`
- Combined comparison: `.dart_tool/qa/context-menu-reference-vs-implementation.png`
- Viewport: 271 × 483 logical pixels at 1.0 device pixel ratio.
- State: light theme, context menu open, no hovered item.

## Comparison history

1. The first implementation capture had a heavier shadow, a narrower 224 px menu, a 34 px row height, and automatically highlighted the first item.
2. The menu was adjusted to a 252 px minimum width, 32 px rows, 2 dp elevation, a lighter shadow, and no initial focus highlight.
3. The destructive action returned to the reference's neutral resting color. Real project `Assets/Symbols` icons were preloaded before capture; no replacement artwork or synthetic icons were introduced.
4. The source and final implementation were combined at the same viewport and inspected together.

## Final findings

- Typography, row density, icon alignment, shortcut alignment, border radius, border contrast, separator treatment, and shadow weight match the Windows Notion reference closely.
- The implementation keeps DingDong's own action set; differences in menu item count and copy are intentional product-content differences, not styling defects.
- Keyboard selection, Escape dismissal, dark-theme colors, viewport clamping, and the non-Windows Material fallback are covered by widget tests.
- Windows number badges use `Ctrl 1/2/3`; macOS badges remain `⌘ 1/2/3`.
- Windows delegates the outer popup corners to the native system frame. macOS retains the existing rounded app-owned frame.
- Tray icons reuse the existing normal and hot built-in artwork. The Windows runtime only selects a white or dark tint from taskbar luminance and preserves the existing unread geometry.

## Result

final result: passed
