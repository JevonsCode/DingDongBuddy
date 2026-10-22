# Skill version history implementation plan

> **For agentic workers:** Execute task-by-task with focused verification and review.

**Goal:** Durable complete Skill history with restore and arbitrary two-version diff.

**Architecture:** Track changes centrally at the synchronized resource store. Content-addressed immutable snapshot JSON stores document, source and every package file. Atomic per-resource manifests reference snapshots. Capture before cleanup; commit after successful sync; roll back on persistence failure. The view model exposes history and restore; the detail header opens a compact adaptive dialog.

**Tech Stack:** Flutter/Dart, SafeManagedFile, cryptography SHA256, existing desktop widgets and localization ARB files. No new dependencies or public HTTP/MCP contracts.

### Task 1: durable history primitives

Files: create `lib/features/library/domain/skill_version.dart`, `lib/features/library/data/skill_version_history.dart`, `test/features/library/skill_version_history_test.dart`.

- [ ] Define revision, file snapshot and full snapshot codecs, sorted canonical hashing and guarded path validation.
- [ ] Implement per-resource atomic manifests, immutable deduplicated snapshots, prepare/commit/rollback, baseline initialization, snapshot validation and materialization. Preserve executable permissions on POSIX. Never follow links; restore binaries exactly and empty directories as part of package identity.
- [ ] Test restart, no-op fingerprints, deduplication, corrupt history refusal, unsafe paths, complete files, binary and executable flags.
- [ ] Run `flutter test --no-pub test/features/library/skill_version_history_test.dart` (exit 0).

### Task 2: central tracking and restore

Files: modify `lib/features/library/data/agent_resource_synchronizer.dart`, `lib/features/library/data/synchronized_resource_store.dart`, `lib/features/library/ui/library_view_model.dart`, `lib/features/library/ui/resource_editor.dart`; create `test/features/library/skill_version_store_test.dart`.

- [ ] Add internal versioned-resource interface, infer disk history from the resource JSON location, and permit injected history for tests. Use the existing resource exclusive lock for load, save and restore.
- [ ] Initialize existing Skills on load. Prepare previous/current snapshots before saving; commit history only after synchronization, then clean live packages. Usage-only edits skip snapshots. On error restore previous resource/Agent state and retain old package. Newly created Skills get v1.
- [ ] Restore selected historical snapshot into a staging directory, install through the existing safe package installer, apply historical title/document/source to fresh current configuration, call the synchronized save path with restored-from metadata and force a new revision. Do not fetch remote content. Reload the view model/editor after success.
- [ ] Explicitly label online refresh vs manual save through the view model and editor callback; Agent saves infer online when the package/source changes. No-op refreshes do not create entries.
- [ ] Test whole-package restoration after cleanup/restart, metadata preservation, API-equivalent saves, failed sync/history write rollback, no-op refresh, metadata-only saves, stale concurrent writes.
- [ ] Run new tests plus `test/features/library/agent_resource_synchronizer_test.dart` and `library_view_model_test.dart` (exit 0).

### Task 3: comparison engine

Files: create `lib/features/library/domain/skill_version_diff.dart`, `test/features/library/skill_version_diff_test.dart`.

- [ ] Compare sorted union of package paths, always overlaying the separately stored document as SKILL.md, including for document-only Skills and edits; include synthetic name/source metadata only when changed; classify additions/deletions/modifications, binary and executable flags. Use bounded line comparison with a deterministic large-file fallback; preserve trailing newline information.
- [ ] Test arbitrary/reversed/nonadjacent endpoints, unchanged versions, text insert/delete/replace, empty files, binary, permissions, metadata, large input.
- [ ] Run diff tests (exit 0).

### Task 4: history dialog and entry point

Files: create `lib/features/library/ui/skill_version_history_dialog.dart`; modify `library_screen.dart`, `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`; create `test/features/library/skill_version_history_dialog_test.dart`.

- [ ] Add Version history to Skill detail header only when backing store supports history. Confirm unsaved edits before opening and reset editor after restoration.
- [ ] Provide history list, source/time/current marker, accessible from/to selectors, file changes and selectable line diff. Default previous -> latest. For a single version preview the document; for no history show an empty state. Use existing desktop dialog/buttons, readable density, muted surfaces and +/- diff signs.
- [ ] Adapt at narrow widths using stacked selectors/list and scrollable diff. Disable close and restore during restoration. Name the target revision in restore confirmation; show loading/error/retry without dismissing on failure.
- [ ] Generate localizations; run widget tests including selection of two nonadjacent versions and narrow layout. Render actual widgets to PNG at desktop and narrow sizes and inspect both.

### Task 5: final validation and delivery

- [ ] Run formatting, `flutter analyze --no-pub`, relevant library tests, and wider tests when required by changed boundaries.
- [ ] Review final diff against spec, request independent code review, repair actionable issues and rerun affected checks.
- [ ] Update this checklist and commit scoped changes on `codex/skill-version-history`. Keep unrelated worktrees intact. Report exact tests and any unverified runtime acceptance. No release or installation requested.

Commands use `T:/workspace/dingdong/.tooling/flutter-sdk-3.44.7/bin/flutter.bat` with PowerShell login disabled so the profile cannot change the working directory. If pub get cannot create plugin symlinks, run unit/widget checks with existing generated package configuration and report any native-build limitation.
