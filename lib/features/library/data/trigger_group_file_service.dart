import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/files/safe_managed_file.dart';
import 'package:dingdong/core/serialization/strict_json.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';

/// Reads and atomically replaces DingDong's trigger-group JSON.
final class TriggerGroupFileService {
  TriggerGroupFileService(this.file) : _managed = SafeManagedFile(file);

  final File file;
  final SafeManagedFile _managed;

  Future<T> exclusive<T>(Future<T> Function() action) =>
      _managed.exclusive(action);

  Future<List<TriggerGroup>> readGroups() => exclusive(() async {
    final ManagedFileSnapshot snapshot = await _managed.snapshot();
    if (!snapshot.exists || snapshot.contents.trim().isEmpty) {
      return const <TriggerGroup>[];
    }
    final List<Object?> decoded =
        decodeStrictJson(snapshot.contents) as List<Object?>;
    return List<TriggerGroup>.unmodifiable(
      decoded.map(
        (Object? value) => TriggerGroup.fromJson(value as Map<String, Object?>),
      ),
    );
  });

  Future<void> writeAtomically(List<TriggerGroup> groups) =>
      exclusive(() async {
        final String contents = const JsonEncoder.withIndent(
          '  ',
        ).convert(groups.map((TriggerGroup group) => group.toJson()).toList());
        await _managed.update(
          (_) => contents,
          validate: (String value) => decodeStrictJson(value) as List<Object?>,
        );
      });
}
