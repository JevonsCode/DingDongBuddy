import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';

/// Reads and atomically replaces DingDong's resource JSON.
final class ResourceFileService {
  ResourceFileService(this.file);

  final File file;

  static final Object _lockZoneKey = Object();
  static final Map<String, Future<void>> _barriers = <String, Future<void>>{};

  Future<T> exclusive<T>(Future<T> Function() action) async {
    final String key = file.absolute.path;
    final Set<String> held =
        Zone.current[_lockZoneKey] as Set<String>? ?? const <String>{};
    if (held.contains(key)) {
      return action();
    }
    final Future<void> previous = _barriers[key] ?? Future<void>.value();
    final Completer<void> gate = Completer<void>();
    _barriers[key] = gate.future;
    await previous;
    await file.parent.create(recursive: true);
    final RandomAccessFile lock = await File(
      '${file.path}.lock',
    ).open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
      return await runZoned(
        action,
        zoneValues: <Object, Object>{
          _lockZoneKey: <String>{...held, key},
        },
      );
    } finally {
      try {
        await lock.unlock();
      } finally {
        await lock.close();
        gate.complete();
        if (identical(_barriers[key], gate.future)) {
          unawaited(_barriers.remove(key));
        }
      }
    }
  }

  Future<List<Resource>> readResources() => exclusive(_readResourcesUnlocked);

  Future<List<Resource>> _readResourcesUnlocked() async {
    await _restoreInterruptedWrite();
    if (!await file.exists()) {
      return const <Resource>[];
    }
    final String contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return const <Resource>[];
    }
    final List<Object?> decoded = jsonDecode(contents) as List<Object?>;
    return List<Resource>.unmodifiable(
      decoded.map(
        (Object? value) => Resource.fromJson(value as Map<String, Object?>),
      ),
    );
  }

  Future<void> writeAtomically(List<Resource> resources) async {
    await exclusive(() => _writeAtomicallyUnlocked(resources));
  }

  Future<void> _writeAtomicallyUnlocked(List<Resource> resources) async {
    await file.parent.create(recursive: true);
    final String nonce = DateTime.now().microsecondsSinceEpoch.toString();
    final File temporary = File('${file.path}.$nonce.tmp');
    final File backup = File('${file.path}.$nonce.bak');
    final String contents = const JsonEncoder.withIndent(
      '  ',
    ).convert(resources.map((Resource resource) => resource.toJson()).toList());
    await temporary.writeAsString(contents, flush: true);

    final bool hadOriginal = await file.exists();
    try {
      if (await backup.exists()) {
        await backup.delete();
      }
      if (hadOriginal) {
        await file.rename(backup.path);
      }
      await temporary.rename(file.path);
      if (await backup.exists()) {
        await backup.delete();
      }
    } on Object {
      if (!await file.exists() && await backup.exists()) {
        await backup.rename(file.path);
      }
      if (await temporary.exists()) {
        await temporary.delete();
      }
      rethrow;
    }
  }

  Future<void> _restoreInterruptedWrite() async {
    if (await file.exists() || !await file.parent.exists()) {
      return;
    }
    final String prefix = '${file.path}.';
    final List<File> backups = await file.parent
        .list(followLinks: false)
        .where(
          (FileSystemEntity entity) =>
              entity is File &&
              entity.path.startsWith(prefix) &&
              entity.path.endsWith('.bak'),
        )
        .cast<File>()
        .toList();
    if (backups.isEmpty) {
      return;
    }
    backups.sort(
      (File left, File right) =>
          right.lastModifiedSync().compareTo(left.lastModifiedSync()),
    );
    await backups.first.rename(file.path);
  }
}
