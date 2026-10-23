# selection-hook Windows selection subset

Upstream: https://github.com/0xfullex/selection-hook

Pinned commit: `d8ac605db1b0a87f816f6fdfd880e054033737e5`.
License: MIT, copyright 2025 0xfullex; the full notice is in `LICENSE`.

`engine.cc` and `engine.h` are a **locally adapted subset**, not unmodified
upstream files. `upstream/engine.cc` and `upstream/engine.h` retain the exact
original source fetched at this commit for attribution and comparison. Their
Git blob SHAs are `7ad0fdbfe308534d1ddc456b860063aa0ba4aa49` and
`1cd17324632bf99fdf1a7dc7c38d4c4d65b0fa8b` respectively. Only the files at this
directory's root are compiled.

Reused implementation: explicit UIA TextPattern GetSelection, first nonempty
range extraction, focused LegacyIAccessible selection interpretation, bounded
ancestor search, object replacement character cleanup, and bounding rectangles.
No JavaScript/Electron/N-API or upstream overlay UI is included. The upstream
worker is not copied: DingDong implements its value-only serial MTA worker and
Flutter channel delivery in `windows/runner/windows_selection_monitor.cpp`.

Local adaptations:

- Removed clipboard fallback, all clipboard read/write and synthetic copy keys,
  program-list heuristics, StringPool, and N-API dependencies. No ATL dependency.
- Require focused/ancestor UIA elements to belong to the captured foreground
  process and positively report a non-password field. Legacy MSAA runs only
  through this validated focused element and additionally rejects protected or
  unknown accessibility state. Direct root-window MSAA fallback is omitted.
- Read only explicit selections, never DocumentRange, ValuePattern, control
  values, or complete documents. Limit text to 16,384 UTF-16 code units, ranges
  to 64, ancestors to 10, and rectangle array size to 65,536 elements.
- Validate bounding-array structure, finite coordinates, and reasonable bounds.
  Preserve first/last line positions. Permit high-DPI line heights above the
  upstream historical 100-physical-pixel threshold.
- Cancel by generation, reject stale foreground/results older than two seconds,
  and keep at most one pending request plus one pending result. Disable cancels
  outstanding delivery immediately. Hooks ignore DingDong's own process.
- Bounded shutdown wait, then a worker with only shared value state may finish
  independently if a third-party accessibility provider is stuck. The worker
  never owns a Flutter/window object; COM is created/used/released on its MTA.

## Flutter contract

The primary engine registers `dingdong/windows_selection`. It starts disabled.
`configure` accepts `{enabled: bool}`; it and `status` return `{running: bool}`.
Running means both low-level hooks were installed and the COM/UIA worker started.
A hook/COM initialization failure reports false. No native popup is created.

Events: `selected` carries `text`, `x`, `y`, `width`, `height`, `coordinateScale`,
`workAreaX`, `workAreaY`, `workAreaWidth`, `workAreaHeight`. Numeric rectangle
values are physical desktop pixels divided by the primary window DPI / 96.
Before calling window_manager from a different Flutter window, multiply those
values by `coordinateScale / childDevicePixelRatio`. This matches the vendored
window_manager's physical = logical * callerDevicePixelRatio contract, including
negative desktop origins. Work area is from the selection's Windows monitor.
`dismiss` has no arguments and follows outside input, Escape, or an empty result.
Clicks inside any DingDong process window preserve the open selection popup.

Triggers: mouse drag, double click, Shift+click, and Shift release after keyboard
navigation. Input callbacks do not query accessibility. Retrieval waits 70 ms on
the worker for the target application to process its release event.

## Verification and limits

Run `scripts/test_windows_selection_native.ps1 -FlutterRoot <Flutter SDK>`.
It compiles the adapter and engine with C++17, `/W4 /WX`, and tests null,
cancelled, and stale-foreground handling. A separate native Edit fixture verifies
actual selected text, rectangles, password/empty rejection, and unchanged clipboard when
Windows grants foreground access. The test explicitly prints SKIP for this
interactive portion if background execution cannot acquire foreground; that is
not application compatibility evidence.

Unsupported or inaccessible providers simply produce no selection. Elevated
apps, protected fields, custom-rendered editors, browser/PDF accessibility,
multi-monitor DPI, hook behavior, and real popup interaction require interactive
application testing. UIA/MSAA provider calls cannot reliably be interrupted; one
stuck provider may stall later retrieval until restart, while the Flutter UI and
disable remain responsive. No clipboard fallback is enabled to mask this limit.
