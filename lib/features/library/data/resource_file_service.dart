import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/files/safe_managed_file.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/serialization/strict_json.dart';

/// Reads and atomically replaces DingDong's resource JSON.
final class ResourceFileService {
  ResourceFileService(this.file) : _managed = SafeManagedFile(file);

  final File file;
  final SafeManagedFile _managed;

  Future<T> exclusive<T>(Future<T> Function() action) =>
      _managed.exclusive(action);

  Future<List<Resource>> readResources() => exclusive(_readResourcesUnlocked);

  Future<List<Resource>> _readResourcesUnlocked() async {
    final ManagedFileSnapshot snapshot = await _managed.snapshot();
    if (!snapshot.exists || snapshot.contents.trim().isEmpty) {
      return const <Resource>[];
    }
    final List<Object?> decoded =
        decodeStrictJson(snapshot.contents) as List<Object?>;
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
    final String contents = const JsonEncoder.withIndent(
      '  ',
    ).convert(resources.map((Resource resource) => resource.toJson()).toList());
    await _managed.update(
      (_) => contents,
      validate: (String value) => decodeStrictJson(value) as List<Object?>,
    );
  }
}
