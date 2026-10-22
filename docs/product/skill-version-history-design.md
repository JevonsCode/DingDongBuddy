# Skill version history

Approved scope: online refresh and manual saves retain full Skill versions, restore any version, and compare any two versions. User approved implementation on 2026-10-23 and requested the user-taste skill.

## Behavior

- Existing Skills acquire an initial snapshot when the library is loaded. New Skills acquire version 1 after a successful save. History begins with currently available content; past versions cannot be reconstructed.
- Version only Skill name, document, source URL and complete package files (including executable bits). Do not version usage counters, enabled state, trigger scope, Agent delivery or local notes. Unchanged saves/refreshes do not add a version.
- Each entry has a monotonic per-Skill number, UTC time, source (initial/manual/online/restored), snapshot identity and optional restored-from version. Identical full snapshots share storage. History is local and persists across restart.
- Restoration creates a new entry, even when restoring the currently active content, and preserves the current resource ID, enablement, scope, delivery configuration, notes, counters and other organizational metadata. Restore source URL/name/document/package together, synchronize Agent copies through the existing path, and never fetch the remote URL during restore.
- History includes all package files. Reject symbolic links and unsafe paths; binary files are restored byte-for-byte. Report binary changes without pretending to render a textual diff. Track executable permission changes.
- Default comparison is previous -> latest. Either endpoint is selectable independently, including nonadjacent/reversed versions. Show added/deleted/modified files and line-level text additions/deletions. Metadata differences (name/source) are visible. Single-version history shows the saved document and an empty comparison state.

## Storage and transaction boundary

Use content-addressed immutable local snapshots outside the live package cleanup root, plus atomic per-resource history manifests. Use existing managed-file locks and the resource mutation lock. Capture previous/proposed packages before live cleanup. Publish a new history entry only after resource persistence and Agent synchronization succeed; if history persistence fails roll back the resource and Agent copies. Do not clean up the old live package until history is durable. Ignore abandoned unreferenced snapshot files. Do not silently reset damaged history.

Read baseline and restore under the resource lock, using fresh current resource state. Compare content fingerprints to avoid revisions for unrelated edits. Keep original resource JSON and public API shapes compatible. Centralize tracking in SynchronizedResourceStore so UI and Agent writes both retain history. Restore is exposed internally to the view model; no new external API is needed.

## UI

Add a Version history action to the existing Skill detail header. Open a restrained desktop dialog with compact version rows and a comparison workspace. On narrow windows stack selectors and allow file/diff scrolling. Use existing controls, 12-13px readable text, disciplined dividers, muted surfaces, accessible selector names, keyboard focus, and small green/red diff accents with +/- symbols. No animation, decorative gradients or nested card layout. Restore requires a concrete confirmation naming the version and then refreshes the editor. Respect unsaved editor changes before opening history. Show loading/error/retry states and prevent double restoration.

## Verification

Test durable restart, online/manual saves, no-op refresh, non-content changes, whole-package and binary restoration, restore lineage, historical package survival after cleanup, failed synchronization/history write, and concurrent stale saves. Test arbitrary diff directions, additions/deletions, trailing newlines, binary and permission changes. Widget tests cover selectors, restore, empty/loading/error states and narrow width. Render actual widget screenshots for visual review; desktop runtime acceptance is reported separately if unavailable. Run relevant library tests and analyzer, then broader suite as appropriate.

## Implementation and validation (2026-10-23)

Open a Skill in Resources and use the history icon in the detail header. Choose either comparison endpoint independently; restore applies the right-hand version as a new revision. History is stored locally in `Skill History` beside the resource JSON. Existing historical content predating this feature is unavailable.

When current Agent settings require native delivery, restoring a document-only version builds a minimal package from the historical document. Restoration uses a snapshot-specific artifact identity, retaining metadata bytes excluded from native deployment hashes. Local history restores preserve all recorded files and bypass online import size/count limits; ordinary imports retain their existing limits.

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --exclude-tags golden --concurrency=2`: 1290 passed, 12 skipped.
- Screenshot-enabled dialog/diff checks: 15 passed, including actual desktop, narrow and dark widget renders, inspected locally. Screenshots are local QA outputs in `.design-qa/skill-history/`.
- Spec compliance and independent code quality reviews approved after fixes. Regressions include full binary/empty-directory/metadata restoration, more than 600 package files, failed history writes, native Agent restoration and nested mutation locks.
- A default-concurrency run exposed an existing real-time tray mascot test race (35ms wait versus a 50ms idle threshold). Its isolated rerun and the full concurrency-2 run passed; no unrelated timer behavior was modified.
- POSIX permissions require Linux/macOS execution (that platform-only test is skipped on Windows). Screenshot checks establish rendered widget layout; no installed-desktop upgrade or manual native runtime acceptance was performed. Golden-tagged tests were excluded from the full suite.
