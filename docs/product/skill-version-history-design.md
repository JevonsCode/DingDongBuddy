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
