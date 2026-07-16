import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/library/domain/trigger_group.dart';

/// Reads and atomically replaces DingDong's trigger-group JSON.
final class TriggerGroupFileService {
  TriggerGroupFileService(this.file);

  final File file;

  Future<List<TriggerGroup>> readGroups() async {
    if (!await file.exists()) {
      return const <TriggerGroup>[];
    }
    final String contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return const <TriggerGroup>[];
    }
    final List<Object?> decoded = jsonDecode(contents) as List<Object?>;
    return List<TriggerGroup>.unmodifiable(
      decoded.map(
        (Object? value) => TriggerGroup.fromJson(value as Map<String, Object?>),
      ),
    );
  }

  Future<void> writeAtomically(List<TriggerGroup> groups) async {
    await file.parent.create(recursive: true);
    final File temporary = File('${file.path}.tmp');
    final File backup = File('${file.path}.bak');
    final String contents = const JsonEncoder.withIndent(
      '  ',
    ).convert(groups.map((TriggerGroup group) => group.toJson()).toList());
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
}
