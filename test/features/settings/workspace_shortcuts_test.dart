import 'package:dingdong/features/settings/domain/workspace_shortcuts.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('safe workspace defaults use platform-specific modifiers', () {
    expect(WorkspaceShortcuts.defaultToday.label(TargetPlatform.macOS), '⌃ Q');
    expect(
      WorkspaceShortcuts.defaultToday.label(TargetPlatform.windows),
      'Alt Q',
    );
  });

  test('custom workspace shortcuts round-trip through preferences', () {
    const WorkspaceShortcuts shortcuts = WorkspaceShortcuts(
      today: WorkspaceShortcut(key: 'T', primary: true, shift: true),
      library: WorkspaceShortcut(key: 'L', secondary: true),
      clipboard: WorkspaceShortcut(key: 'C', alt: true),
    );

    expect(
      WorkspaceShortcuts.parse(
        shortcuts.encode(),
        platform: TargetPlatform.macOS,
      ),
      shortcuts,
    );
  });

  test('duplicate persisted shortcuts fall back to safe defaults', () {
    const WorkspaceShortcuts shortcuts = WorkspaceShortcuts(
      today: WorkspaceShortcut(key: 'T', primary: true),
      library: WorkspaceShortcut(key: 'T', primary: true),
      clipboard: WorkspaceShortcut(key: 'C', primary: true),
    );

    expect(
      WorkspaceShortcuts.parse(
        shortcuts.encode(),
        platform: TargetPlatform.macOS,
      ),
      WorkspaceShortcuts.defaultValue,
    );
  });
}
