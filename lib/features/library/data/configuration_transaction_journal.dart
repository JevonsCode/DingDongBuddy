import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/files/safe_managed_file.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/serialization/strict_json.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';

enum ConfigurationTransactionMode { commit, rollback }

final class ConfigurationTransactionRecord {
  ConfigurationTransactionRecord({
    required this.mode,
    required this.resourceFilePath,
    required this.triggerGroupFilePath,
    required List<Resource> previousResources,
    required List<Resource> proposedResources,
    required List<TriggerGroup> previousGroups,
    required List<TriggerGroup> proposedGroups,
  }) : previousResources = List<Resource>.unmodifiable(previousResources),
       proposedResources = List<Resource>.unmodifiable(proposedResources),
       previousGroups = List<TriggerGroup>.unmodifiable(previousGroups),
       proposedGroups = List<TriggerGroup>.unmodifiable(proposedGroups);

  factory ConfigurationTransactionRecord.fromJson(Map<String, Object?> json) {
    if (json['schemaVersion'] != 1) {
      throw const FormatException(
        'Unsupported DingDong configuration transaction schema.',
      );
    }
    return ConfigurationTransactionRecord(
      mode: ConfigurationTransactionMode.values.byName(json['mode']! as String),
      resourceFilePath: json['resourceFilePath']! as String,
      triggerGroupFilePath: json['triggerGroupFilePath']! as String,
      previousResources: _resources(json['previousResources']),
      proposedResources: _resources(json['proposedResources']),
      previousGroups: _groups(json['previousGroups']),
      proposedGroups: _groups(json['proposedGroups']),
    );
  }

  final ConfigurationTransactionMode mode;
  final String resourceFilePath;
  final String triggerGroupFilePath;
  final List<Resource> previousResources;
  final List<Resource> proposedResources;
  final List<TriggerGroup> previousGroups;
  final List<TriggerGroup> proposedGroups;

  ConfigurationTransactionRecord copyWith({
    ConfigurationTransactionMode? mode,
  }) => ConfigurationTransactionRecord(
    mode: mode ?? this.mode,
    resourceFilePath: resourceFilePath,
    triggerGroupFilePath: triggerGroupFilePath,
    previousResources: previousResources,
    proposedResources: proposedResources,
    previousGroups: previousGroups,
    proposedGroups: proposedGroups,
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': 1,
    'mode': mode.name,
    'resourceFilePath': resourceFilePath,
    'triggerGroupFilePath': triggerGroupFilePath,
    'previousResources': previousResources
        .map((Resource resource) => resource.toJson())
        .toList(growable: false),
    'proposedResources': proposedResources
        .map((Resource resource) => resource.toJson())
        .toList(growable: false),
    'previousGroups': previousGroups
        .map((TriggerGroup group) => group.toJson())
        .toList(growable: false),
    'proposedGroups': proposedGroups
        .map((TriggerGroup group) => group.toJson())
        .toList(growable: false),
  };
}

/// Durable intent for the only DingDong workflow that updates the resource
/// library and trigger-group library as one logical operation.
final class ConfigurationTransactionJournal {
  ConfigurationTransactionJournal(File file)
    : _managed = SafeManagedFile(file, newFileMode: 0x180);

  final SafeManagedFile _managed;

  Future<ConfigurationTransactionRecord?> read() async {
    final ManagedFileSnapshot snapshot = await _managed.snapshot();
    if (!snapshot.exists || snapshot.contents.trim().isEmpty) {
      return null;
    }
    return _decode(snapshot.contents);
  }

  Future<void> write(ConfigurationTransactionRecord record) async {
    final String contents =
        '${const JsonEncoder.withIndent('  ').convert(record.toJson())}\n';
    await _managed.update(
      (_) => contents,
      validate: (String value) => _decode(value),
    );
  }

  Future<void> clear() async {
    final ManagedFileSnapshot snapshot = await _managed.snapshot();
    if (snapshot.exists) {
      await _managed.deleteIfUnchanged(snapshot);
    }
  }

  ConfigurationTransactionRecord _decode(String contents) {
    try {
      return ConfigurationTransactionRecord.fromJson(
        Map<String, Object?>.from(decodeStrictJson(contents)! as Map),
      );
    } on FormatException {
      rethrow;
    } on Object catch (error) {
      throw FormatException(
        'Invalid DingDong configuration transaction journal: $error',
      );
    }
  }
}

List<Resource> _resources(Object? value) => (value! as List<Object?>)
    .map(
      (Object? item) =>
          Resource.fromJson(Map<String, Object?>.from(item! as Map)),
    )
    .toList(growable: false);

List<TriggerGroup> _groups(Object? value) => (value! as List<Object?>)
    .map(
      (Object? item) =>
          TriggerGroup.fromJson(Map<String, Object?>.from(item! as Map)),
    )
    .toList(growable: false);
