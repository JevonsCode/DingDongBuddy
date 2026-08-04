import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop UI uses shared replacements for native-looking controls', () {
    final RegExp forbidden = RegExp(
      r'\b(?:AlertDialog|SimpleDialog|DropdownButton|PopupMenuButton|Checkbox|Switch|ExpansionTile|SegmentedButton|Slider)\s*(?:<[^>]+>)?\s*\(',
    );
    final List<String> violations = <String>[];

    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('core/widgets/desktop_dialog.dart')) continue;
      if (entity.path.endsWith('core/widgets/desktop_slider.dart')) continue;
      final List<String> lines = entity.readAsLinesSync();
      for (int index = 0; index < lines.length; index++) {
        if (forbidden.hasMatch(lines[index])) {
          violations.add('${entity.path}:${index + 1}: ${lines[index].trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Use a shared DingDong desktop component instead of a raw native-looking control:\n${violations.join('\n')}',
    );
  });

  test('feature surfaces use shared DingDong controls', () {
    final RegExp forbidden = RegExp(
      r'\b(?:TextField|TextFormField|FilledButton|OutlinedButton|TextButton|IconButton|FilterChip)\s*(?:<[^>]+>)?\s*(?:\.|\()',
    );
    final List<String> violations = <String>[];

    for (final FileSystemEntity entity in Directory(
      'lib/features',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final List<String> lines = entity.readAsLinesSync();
      for (int index = 0; index < lines.length; index++) {
        if (forbidden.hasMatch(lines[index])) {
          violations.add('${entity.path}:${index + 1}: ${lines[index].trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Feature surfaces must use shared DingDong desktop controls:\n${violations.join('\n')}',
    );
  });

  test('native control constructors stay inside shared desktop wrappers', () {
    final RegExp forbidden = RegExp(
      r'\b(?:TextField|TextFormField|FilledButton|OutlinedButton|TextButton|IconButton|FilterChip|Slider)\s*(?:<[^>]+>)?\s*\(',
    );
    const Set<String> allowedFiles = <String>{
      'lib/core/widgets/desktop_action_button.dart',
      'lib/core/widgets/desktop_icon_button.dart',
      'lib/core/widgets/desktop_input_field.dart',
      'lib/core/widgets/desktop_slider.dart',
    };
    final List<String> violations = <String>[];

    for (final FileSystemEntity entity in Directory(
      'lib',
    ).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (allowedFiles.contains(entity.path)) continue;
      final List<String> lines = entity.readAsLinesSync();
      for (int index = 0; index < lines.length; index++) {
        if (forbidden.hasMatch(lines[index])) {
          violations.add('${entity.path}:${index + 1}: ${lines[index].trim()}');
        }
      }
    }

    expect(
      violations,
      isEmpty,
      reason:
          'Native control constructors must stay inside shared desktop wrappers:\n${violations.join('\n')}',
    );
  });
}
