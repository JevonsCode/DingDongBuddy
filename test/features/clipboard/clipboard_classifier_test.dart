import 'package:dingdong/features/clipboard/domain/clipboard_classifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'secret-like assignments are classified as sensitive before other kinds',
    () {
      final ClipboardClassification result = ClipboardClassifier.classify(
        'token=abcdefghijklmnopqrstuvwx',
      );

      expect(result.group, isEmpty);
      expect(result.title, 'API key or token');
      expect(result.tags, <String>[
        'clipboard',
        'sensitive',
        'secret',
        'api-key',
      ]);
    },
  );

  test('HTTP links are classified with a searchable domain tag', () {
    final ClipboardClassification result = ClipboardClassifier.classify(
      'https://docs.flutter.dev/perf/best-practices',
    );

    expect(result.group, isEmpty);
    expect(result.title, 'https://docs.flutter.dev/perf/best-practices');
    expect(result.tags, <String>[
      'clipboard',
      'url',
      'domain:docs.flutter.dev',
    ]);
  });

  test('JSON objects are titled from sorted top-level keys', () {
    final ClipboardClassification result = ClipboardClassifier.classify(
      '{"z":1,"alpha":2,"middle":3,"ignored":4}',
    );

    expect(result.group, isEmpty);
    expect(result.title, '{"z":1,"alpha":2,"middle":3,"ignored":4}');
    expect(result.tags, <String>['clipboard', 'text', 'json', 'structured']);
  });

  test('known shell commands keep the command name as a tag', () {
    final ClipboardClassification result = ClipboardClassifier.classify(
      'flutter test --coverage',
    );

    expect(result.group, isEmpty);
    expect(result.title, 'flutter test --coverage');
    expect(result.tags, <String>['clipboard', 'text', 'command', 'flutter']);
  });

  test('source snippets are grouped as code with a language tag', () {
    final ClipboardClassification result = ClipboardClassifier.classify(
      'import SwiftUI\nstruct ContentView: View {}',
    );

    expect(result.group, isEmpty);
    expect(result.title, 'import SwiftUI');
    expect(result.tags, <String>['clipboard', 'text', 'code', 'swift']);
  });

  test('email addresses are classified before path and plain text', () {
    final ClipboardClassification result = ClipboardClassifier.classify(
      'agent@example.com',
    );

    expect(result.group, isEmpty);
    expect(result.title, 'agent@example.com');
    expect(result.tags, <String>['clipboard', 'text', 'email']);
  });

  test('absolute and relative filesystem paths remain path records', () {
    final ClipboardClassification result = ClipboardClassifier.classify(
      '/Users/example/project/README.md',
    );

    expect(result.group, isEmpty);
    expect(result.title, '/Users/example/project/README.md');
    expect(result.tags, <String>['clipboard', 'text', 'path']);
  });

  test('private keys and provider credentials are always sensitive', () {
    final Map<String, String> cases = <String, String>{
      '-----BEGIN ' 'PRIVATE KEY-----\nmaterial': 'private-key',
      'AKIA' 'ABCDEFGHIJKLMNOP': 'aws-key',
      'ghp_' 'abcdefghijklmnopqrstuvwxyz123456': 'github-token',
    };

    for (final MapEntry<String, String> entry in cases.entries) {
      final ClipboardClassification result = ClipboardClassifier.classify(
        entry.key,
      );
      expect(result.group, isEmpty);
      expect(result.tags, contains(entry.value));
    }
  });
}
