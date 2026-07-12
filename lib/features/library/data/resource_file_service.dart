import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';

/// Reads and atomically replaces DingDong's legacy-compatible resource JSON.
final class ResourceFileService {
  ResourceFileService(this.file);

  final File file;

  Future<List<Resource>> readResources() async {
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
    await file.parent.create(recursive: true);
    final File temporary = File('${file.path}.tmp');
    final File backup = File('${file.path}.bak');
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
}
