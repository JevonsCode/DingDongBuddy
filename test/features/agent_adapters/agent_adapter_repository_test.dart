import 'dart:io';

import 'package:dingdong/features/agent_adapters/data/agent_adapter_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'merges user overrides and keeps current plus two prior versions',
    () async {
      final Directory temporary = Directory.systemTemp.createTempSync(
        'dingdong-agent-adapters-',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      var tick = 0;
      final AgentAdapterRepository repository = AgentAdapterRepository(
        userDirectory: Directory('${temporary.path}/adapters'),
        historyDirectory: Directory('${temporary.path}/history'),
        homeDirectory: temporary.path,
        loadBuiltIns: () async => <String, String>{'codex': _codex},
        now: () => DateTime.utc(2026, 7, 23, 10, tick++),
      );

      final AgentAdapterEntry builtIn =
          (await repository.load()).entries.single;
      expect(builtIn.origin, AgentAdapterOrigin.builtIn);

      await repository.save(
        _codex.replaceFirst('Codex', 'Codex One'),
        existing: builtIn,
      );
      final AgentAdapterEntry first = (await repository.load()).entries.single;
      await repository.save(
        _codex.replaceFirst('Codex', 'Codex Two'),
        existing: first,
      );
      final AgentAdapterEntry second = (await repository.load()).entries.single;
      await repository.save(
        _codex.replaceFirst('Codex', 'Codex Three'),
        existing: second,
      );

      final AgentAdapterEntry customized =
          (await repository.load()).entries.single;
      final List<AgentAdapterRevision> history = await repository.historyFor(
        customized,
      );
      expect(customized.origin, AgentAdapterOrigin.customized);
      expect(customized.displayName, 'Codex Three');
      expect(history, hasLength(3));
      expect(history[0].document, contains('Codex Three'));
      expect(history[1].document, contains('Codex Two'));
      expect(history[2].document, contains('Codex One'));
    },
  );

  test('does not overwrite an external edit from a stale view', () async {
    final Directory temporary = Directory.systemTemp.createTempSync(
      'dingdong-agent-adapters-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    final AgentAdapterRepository repository = AgentAdapterRepository(
      userDirectory: Directory('${temporary.path}/adapters'),
      historyDirectory: Directory('${temporary.path}/history'),
      homeDirectory: temporary.path,
      loadBuiltIns: () async => <String, String>{'codex': _codex},
    );
    final AgentAdapterEntry builtIn = (await repository.load()).entries.single;
    await repository.save(
      _codex.replaceFirst('Codex', 'Codex One'),
      existing: builtIn,
    );
    final AgentAdapterEntry stale = (await repository.load()).entries.single;
    await stale.userFile!.writeAsString(
      _codex.replaceFirst('Codex', 'Codex External'),
      flush: true,
    );

    expect(
      repository.save(
        _codex.replaceFirst('Codex', 'Codex UI'),
        existing: stale,
      ),
      throwsStateError,
    );
    expect(await stale.userFile!.readAsString(), contains('Codex External'));
  });

  test('concurrent saves from one stale view allow only one winner', () async {
    final Directory temporary = Directory.systemTemp.createTempSync(
      'dingdong-agent-adapters-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));
    final AgentAdapterRepository repository = AgentAdapterRepository(
      userDirectory: Directory('${temporary.path}/adapters'),
      historyDirectory: Directory('${temporary.path}/history'),
      homeDirectory: temporary.path,
      loadBuiltIns: () async => <String, String>{'codex': _codex},
    );
    final AgentAdapterEntry builtIn = (await repository.load()).entries.single;
    await repository.save(
      _codex.replaceFirst('Codex', 'Codex Existing'),
      existing: builtIn,
    );
    final AgentAdapterEntry stale = (await repository.load()).entries.single;

    Future<Object?> capture(Future<void> operation) async {
      try {
        await operation;
        return null;
      } on Object catch (error) {
        return error;
      }
    }

    final List<Object?> outcomes = await Future.wait(<Future<Object?>>[
      capture(
        repository.save(
          _codex.replaceFirst('Codex', 'Codex First'),
          existing: stale,
        ),
      ),
      capture(
        repository.save(
          _codex.replaceFirst('Codex', 'Codex Second'),
          existing: stale,
        ),
      ),
    ]);

    expect(outcomes.where((Object? value) => value == null), hasLength(1));
    expect(
      outcomes.whereType<StateError>(),
      hasLength(1),
      reason: 'The loser must report a stale Adapter instead of an I/O race.',
    );
    final AgentAdapterCatalog catalog = await repository.load();
    expect(catalog.entries.single.isValid, isTrue);
    expect(
      catalog.entries.single.displayName,
      anyOf('Codex First', 'Codex Second'),
    );
  });

  test(
    'external invalid edits remain visible and block effective loading',
    () async {
      final Directory temporary = Directory.systemTemp.createTempSync(
        'dingdong-agent-adapters-',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      final Directory adapters = Directory('${temporary.path}/adapters')
        ..createSync();
      File('${adapters.path}/codex.yaml').writeAsStringSync('invalid: [');
      final AgentAdapterRepository repository = AgentAdapterRepository(
        userDirectory: adapters,
        historyDirectory: Directory('${temporary.path}/history'),
        homeDirectory: temporary.path,
        loadBuiltIns: () async => <String, String>{'codex': _codex},
      );

      final AgentAdapterEntry entry = (await repository.load()).entries.single;

      expect(entry.origin, AgentAdapterOrigin.customized);
      expect(entry.error, isNotNull);
      expect(entry.document, 'invalid: [');
      expect(repository.loadEffectiveAdapters(), throwsFormatException);
    },
  );

  test(
    'paths outside home and symlinks escaping home remain visible as invalid',
    () async {
      final Directory temporary = Directory.systemTemp.createTempSync(
        'dingdong-agent-adapters-',
      );
      addTearDown(() => temporary.deleteSync(recursive: true));
      final Directory home = Directory('${temporary.path}/home')..createSync();
      final Directory outside = Directory('${temporary.path}/outside')
        ..createSync();
      await Link('${home.path}/escaped').create(outside.path);
      final Directory adapters = Directory('${temporary.path}/adapters')
        ..createSync();
      final AgentAdapterRepository repository = AgentAdapterRepository(
        userDirectory: adapters,
        historyDirectory: Directory('${temporary.path}/history'),
        homeDirectory: home.path,
        loadBuiltIns: () async => <String, String>{},
      );

      await File('${adapters.path}/absolute.yaml').writeAsString('''
schemaVersion: 1
id: absolute
displayName: Absolute
detect:
  directory: ${outside.path}
''');
      await File('${adapters.path}/symlink.yaml').writeAsString('''
schemaVersion: 1
id: symlink
displayName: Symlink
detect:
  directory: ~/escaped
''');

      final AgentAdapterCatalog catalog = await repository.load();

      expect(catalog.entries, hasLength(2));
      expect(
        catalog.entries.map((AgentAdapterEntry entry) => entry.isValid),
        everyElement(isFalse),
      );
      expect(
        catalog.entries.map((AgentAdapterEntry entry) => entry.error),
        everyElement(contains('inside')),
      );
      expect(repository.loadEffectiveAdapters(), throwsFormatException);
    },
  );
}

const String _codex = '''
schemaVersion: 1
id: codex
displayName: Codex
detect:
  directory: ~/.codex
skills:
  global: ~/.agents/skills
  project: .agents/skills
mcp:
  file: ~/.codex/config.toml
  format: codex-toml
''';
