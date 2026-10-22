import 'dart:convert';

import 'package:dingdong/core/models/resource.dart';

enum SkillVersionSource { initial, manual, online, restored }

/// Immutable history entry. The snapshot is stored once by its content hash.
final class SkillVersion {
  const SkillVersion({
    required this.number,
    required this.createdAt,
    required this.source,
    required this.snapshotId,
    this.restoredFrom,
  });

  factory SkillVersion.fromJson(Map<String, Object?> json) => SkillVersion(
    number: json['number'] as int,
    createdAt: DateTime.parse(json['createdAt'] as String),
    source: SkillVersionSource.values.byName(json['source'] as String),
    snapshotId: json['snapshotId'] as String,
    restoredFrom: json['restoredFrom'] as int?,
  );

  final int number;
  final DateTime createdAt;
  final SkillVersionSource source;
  final String snapshotId;
  final int? restoredFrom;

  Map<String, Object?> toJson() => <String, Object?>{
    'number': number,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'source': source.name,
    'snapshotId': snapshotId,
    if (restoredFrom != null) 'restoredFrom': restoredFrom,
  };
}

final class SkillVersionFile {
  SkillVersionFile({required List<int> bytes, this.executable = false})
    : bytes = List<int>.unmodifiable(bytes);

  factory SkillVersionFile.text(String text) =>
      SkillVersionFile(bytes: utf8.encode(text));

  factory SkillVersionFile.fromJson(Map<String, Object?> json) =>
      SkillVersionFile(
        bytes: base64Decode(json['data'] as String),
        executable: json['executable'] as bool,
      );

  final List<int> bytes;
  final bool executable;

  String? get text {
    if (bytes.contains(0)) return null;
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return null;
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'data': base64Encode(bytes),
    'executable': executable,
  };
}

/// Only content is versioned; Agent settings and usage stay on the resource.
final class SkillSnapshot {
  SkillSnapshot({
    required this.title,
    required this.document,
    required this.sourceUrl,
    required Map<String, SkillVersionFile> files,
    List<String> directories = const <String>[],
    required this.hasPackage,
  }) : files = Map<String, SkillVersionFile>.unmodifiable(files),
       directories = List<String>.unmodifiable(directories);

  factory SkillSnapshot.fromJson(Map<String, Object?> json) => SkillSnapshot(
    title: json['title'] as String,
    document: json['document'] as String,
    sourceUrl: json['sourceUrl'] as String?,
    files: (json['files'] as Map<String, Object?>).map(
      (String key, Object? value) => MapEntry(
        key,
        SkillVersionFile.fromJson(value as Map<String, Object?>),
      ),
    ),
    directories: (json['directories'] as List<Object?>).cast<String>(),
    hasPackage: json['hasPackage'] as bool,
  );

  final String title;
  final String document;
  final String? sourceUrl;
  final Map<String, SkillVersionFile> files;
  final List<String> directories;
  final bool hasPackage;

  Map<String, Object?> toJson() {
    final List<String> names = files.keys.toList()..sort();
    final List<String> folders = directories.toList()..sort();
    return <String, Object?>{
      'title': title,
      'document': document,
      'sourceUrl': sourceUrl,
      'hasPackage': hasPackage,
      'directories': folders,
      'files': <String, Object?>{
        for (final String name in names) name: files[name]!.toJson(),
      },
    };
  }
}

/// Internal persistence capability shared by UI and Agent resource mutations.
abstract interface class SkillVersionStore {
  Future<List<SkillVersion>> loadSkillVersions(String resourceId);
  Future<SkillSnapshot> loadSkillSnapshot(String snapshotId);
  Future<void> restoreSkillVersion(String resourceId, int version);
  Future<void> saveWithSkillVersionSource(
    List<Resource> resources, {
    required SkillVersionSource source,
  });
}
