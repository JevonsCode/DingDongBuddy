import 'dart:convert';

import 'package:cryptography/cryptography.dart';

/// Stores only bounded manifests, not Prompt/Skill bodies or conversation text.
/// A caller's knownHash acknowledges retained context; merely sharing a session
/// id is deliberately insufficient to suppress any content.
final class BridgeSnapshotCache {
  BridgeSnapshotCache({this.capacity = 64, this.maximumResources = 512});

  final int capacity;
  final int maximumResources;
  final _snapshots = <String, _Snapshot>{};

  Future<Map<String, Object?>?> rememberAndDiff({
    required String scope,
    required String hash,
    required String knownHash,
    required Map<String, Object?> active,
  }) async {
    final previous = _snapshots['$scope:$knownHash'];
    final versions = <String, Map<String, String>>{};
    var count = 0;
    for (final entry in active.entries) {
      final items = (entry.value! as List).cast<Map<String, Object?>>();
      count += items.length;
      if (count > maximumResources) return null;
      versions[entry.key] = {
        for (final item in items)
          item['id']! as String: await bridgeContentVersion(item),
      };
    }
    if (capacity > 0) {
      final key = '$scope:$hash';
      _snapshots.remove(key);
      _snapshots[key] = _Snapshot(versions);
      while (_snapshots.length > capacity) {
        _snapshots.remove(_snapshots.keys.first);
      }
    }
    if (previous == null) return null;
    final upsert = <String, Object?>{};
    final remove = <String, Object?>{};
    final order = <String, Object?>{};
    for (final kind in {...previous.versions.keys, ...versions.keys}) {
      final oldItems = previous.versions[kind] ?? <String, String>{};
      final newItems = versions[kind] ?? <String, String>{};
      final changed = ((active[kind] as List?) ?? const [])
          .cast<Map<String, Object?>>()
          .where((item) => oldItems[item['id']] != newItems[item['id']])
          .toList();
      final removed = oldItems.keys
          .where((id) => !newItems.containsKey(id))
          .toList();
      if (changed.isNotEmpty) upsert[kind] = changed;
      if (removed.isNotEmpty) remove[kind] = removed;
      if (jsonEncode(oldItems.keys.toList()) !=
          jsonEncode(newItems.keys.toList())) {
        order[kind] = newItems.keys.toList();
      }
    }
    return {'upsert': upsert, 'remove': remove, 'order': order};
  }
}

final class _Snapshot {
  const _Snapshot(this.versions);
  final Map<String, Map<String, String>> versions;
}

Future<String> bridgeContentVersion(Object value) async {
  final digest = await Sha256().hash(utf8.encode(jsonEncode(value)));
  return digest.bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
}
