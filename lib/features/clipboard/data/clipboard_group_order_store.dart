import 'dart:convert';
import 'dart:io';

/// Durable ordering for user-created clipboard groups.
abstract interface class ClipboardGroupOrderStore {
  List<String> load();

  void save(List<String> groups);
}

final class FileClipboardGroupOrderStore implements ClipboardGroupOrderStore {
  FileClipboardGroupOrderStore(this.file);

  final File file;

  @override
  List<String> load() {
    if (!file.existsSync()) {
      return const <String>[];
    }
    try {
      final Object? decoded = jsonDecode(file.readAsStringSync());
      if (decoded is! Map<String, Object?> ||
          decoded['version'] != 1 ||
          decoded['groups'] is! List<Object?>) {
        return const <String>[];
      }
      return List<String>.unmodifiable(
        _uniqueGroups(
          (decoded['groups']! as List<Object?>).whereType<String>(),
        ),
      );
    } on Object {
      return const <String>[];
    }
  }

  @override
  void save(List<String> groups) {
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'version': 1,
        'groups': _uniqueGroups(groups),
      }),
      flush: true,
    );
  }
}

final class InMemoryClipboardGroupOrderStore
    implements ClipboardGroupOrderStore {
  InMemoryClipboardGroupOrderStore([List<String> initial = const <String>[]])
    : _groups = _uniqueGroups(initial);

  List<String> _groups;

  @override
  List<String> load() => List<String>.unmodifiable(_groups);

  @override
  void save(List<String> groups) {
    _groups = _uniqueGroups(groups);
  }
}

List<String> _uniqueGroups(Iterable<String> values) {
  final Set<String> seen = <String>{};
  return values
      .map((String value) => value.trim())
      .where(
        (String value) => value.isNotEmpty && seen.add(value.toLowerCase()),
      )
      .toList(growable: false);
}
