import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dingdong_link_protocol/dingdong_link_protocol.dart';

import 'agent_event.dart';

/// A paired computer plus this phone's per-computer preferences.
final class PairingRecord {
  PairingRecord({
    required this.payload,
    required this.hostName,
    this.agentNotificationsEnabled = true,
    this.vibrationEnabled = true,
    this.manualDisconnect = false,
  });

  final DevicePairingPayload payload;
  String hostName;
  bool agentNotificationsEnabled;
  bool vibrationEnabled;
  bool manualDisconnect;

  String get room => payload.room;

  static PairingRecord? fromJson(Object? value) {
    if (value is! Map) return null;
    try {
      final DevicePairingPayload payload = DevicePairingPayload.fromJson(
        Map<String, Object?>.from(value['pair']! as Map),
      );
      return PairingRecord(
        payload: payload,
        hostName: value['hostName'] is String
            ? value['hostName']! as String
            : payload.hostName,
        agentNotificationsEnabled: value['agentNotificationsEnabled'] != false,
        vibrationEnabled: value['vibrationEnabled'] != false,
        manualDisconnect: value['manualDisconnect'] == true,
      );
    } on Object {
      return null;
    }
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'pair': payload.toJson(),
    'hostName': hostName,
    'agentNotificationsEnabled': agentNotificationsEnabled,
    'vibrationEnabled': vibrationEnabled,
    'manualDisconnect': manualDisconnect,
  };
}

/// Everything the background isolate keeps across restarts. Only that
/// isolate writes the file; the UI reads it solely to decide whether the
/// service should be running.
///
/// Prototype note: pairing secrets live in this app-private file (excluded
/// from backup by data_extraction_rules.xml). A release should wrap them
/// with an Android Keystore key.
final class CompanionStore {
  CompanionStore(this.file);

  final File file;

  String deviceId = _randomId();
  String? deviceName;
  String? activeRoom;
  final List<PairingRecord> pairings = <PairingRecord>[];
  final Map<String, List<AgentEvent>> agentEvents =
      <String, List<AgentEvent>>{};
  final List<String> notifiedIds = <String>[];

  static const int maximumEventsPerComputer = 50;
  static const int maximumNotifiedIds = 300;

  static Future<CompanionStore> load(File file) async {
    final CompanionStore store = CompanionStore(file);
    if (!await file.exists()) return store;
    try {
      final Object? json = jsonDecode(await file.readAsString());
      if (json is! Map) return store;
      if (json['deviceId'] is String) {
        store.deviceId = json['deviceId']! as String;
      }
      if (json['deviceName'] is String) {
        store.deviceName = json['deviceName']! as String;
      }
      if (json['activeRoom'] is String) {
        store.activeRoom = json['activeRoom']! as String;
      }
      for (final Object? value
          in json['pairings'] as List? ?? const <Object?>[]) {
        final PairingRecord? record = PairingRecord.fromJson(value);
        if (record != null) store.pairings.add(record);
      }
      final Object? events = json['agentEvents'];
      if (events is Map) {
        for (final MapEntry<Object?, Object?> entry in events.entries) {
          if (entry.key is! String || entry.value is! List) continue;
          store.agentEvents[entry.key! as String] = <AgentEvent>[
            for (final Object? value in entry.value! as List)
              if (value is Map)
                ?AgentEvent.parse(Map<String, Object?>.from(value)),
          ];
        }
      }
      for (final Object? id
          in json['notifiedIds'] as List? ?? const <Object?>[]) {
        if (id is String) store.notifiedIds.add(id);
      }
    } on Object {
      // A damaged file starts a fresh store rather than crashing the service.
    }
    return store;
  }

  /// Number of saved pairings, read without keeping a store around.
  static Future<int> pairingCount(File file) async =>
      (await load(file)).pairings.length;

  PairingRecord? pairing(String room) {
    for (final PairingRecord record in pairings) {
      if (record.room == room) return record;
    }
    return null;
  }

  /// Returns true the first time an Agent message id is seen.
  bool markNotified(String id) {
    if (notifiedIds.contains(id)) return false;
    notifiedIds.add(id);
    if (notifiedIds.length > maximumNotifiedIds) {
      notifiedIds.removeRange(0, notifiedIds.length - maximumNotifiedIds);
    }
    return true;
  }

  Future<void> save() async {
    await file.parent.create(recursive: true);
    final File temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      jsonEncode(<String, Object?>{
        'version': 1,
        'deviceId': deviceId,
        'deviceName': deviceName,
        'activeRoom': activeRoom,
        'pairings': <Object?>[
          for (final PairingRecord p in pairings) p.toJson(),
        ],
        'agentEvents': <String, Object?>{
          for (final MapEntry<String, List<AgentEvent>> entry
              in agentEvents.entries)
            entry.key: <Object?>[
              for (final AgentEvent event in entry.value.take(
                maximumEventsPerComputer,
              ))
                event.toJson(),
            ],
        },
        'notifiedIds': notifiedIds,
      }),
      flush: true,
    );
    await temporary.rename(file.path);
  }

  static String _randomId() {
    final Random random = Random.secure();
    String hex(int count) => List<String>.generate(
      count,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    return '${hex(4)}-${hex(2)}-${hex(2)}-${hex(2)}-${hex(6)}';
  }
}
