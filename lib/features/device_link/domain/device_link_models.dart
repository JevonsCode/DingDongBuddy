import 'dart:convert';

enum LinkedDeviceKind {
  computer,
  phone;

  static LinkedDeviceKind parse(Object? value) => switch (value) {
    'computer' => LinkedDeviceKind.computer,
    _ => LinkedDeviceKind.phone,
  };
}

enum DeviceConnectionStatus { connecting, connected, disconnected, error }

const int deviceLinkClipboardHistoryLimit = 50;

final class LocalDeviceIdentity {
  const LocalDeviceIdentity({
    required this.id,
    required this.name,
    required this.platform,
  });

  factory LocalDeviceIdentity.fromJson(Map<String, Object?> json) {
    return LocalDeviceIdentity(
      id: json['id']! as String,
      name: json['name']! as String,
      platform: json['platform']! as String,
    );
  }

  final String id;
  final String name;
  final String platform;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'platform': platform,
  };
}

/// A trusted endpoint. Clipboard and file content never live in this record.
final class LinkedDevice {
  const LinkedDevice({
    required this.id,
    required this.name,
    required this.kind,
    required this.platform,
    required this.room,
    required this.secret,
    required this.autoSendClipboard,
    required this.receiveAgentNotifications,
    required this.vibrationEnabled,
    required this.manuallyDisconnected,
    required this.pairedAt,
    this.sharedClipboardItemIds = const <String>[],
    this.lastSeenAt,
  });

  factory LinkedDevice.fromJson(Map<String, Object?> json) {
    return LinkedDevice(
      id: json['id']! as String,
      name: json['name']! as String,
      kind: LinkedDeviceKind.parse(json['kind']),
      platform: json['platform'] as String? ?? '',
      room: json['room']! as String,
      secret: json['secret']! as String,
      autoSendClipboard: json['autoSendClipboard'] == true,
      receiveAgentNotifications: json['receiveAgentNotifications'] != false,
      vibrationEnabled: json['vibrationEnabled'] != false,
      manuallyDisconnected: json['manuallyDisconnected'] == true,
      pairedAt: DateTime.parse(json['pairedAt']! as String).toUtc(),
      sharedClipboardItemIds: _boundedStringList(
        json['sharedClipboardItemIds'],
        limit: deviceLinkClipboardHistoryLimit,
      ),
      lastSeenAt: json['lastSeenAt'] is String
          ? DateTime.parse(json['lastSeenAt']! as String).toUtc()
          : null,
    );
  }

  final String id;
  final String name;
  final LinkedDeviceKind kind;
  final String platform;

  /// Opaque relay rendezvous id. It is not derived from user information.
  final String room;

  /// Base64url-encoded 256-bit pairing key scanned through the QR fragment.
  final String secret;
  final bool autoSendClipboard;
  final bool receiveAgentNotifications;
  final bool vibrationEnabled;
  final bool manuallyDisconnected;
  final DateTime pairedAt;

  /// A bounded authorization ledger for clipboard records actually delivered
  /// to this device. Content remains exclusively in the host clipboard store.
  final List<String> sharedClipboardItemIds;
  final DateTime? lastSeenAt;

  LinkedDevice copyWith({
    String? name,
    LinkedDeviceKind? kind,
    String? platform,
    String? room,
    String? secret,
    bool? autoSendClipboard,
    bool? receiveAgentNotifications,
    bool? vibrationEnabled,
    bool? manuallyDisconnected,
    DateTime? pairedAt,
    List<String>? sharedClipboardItemIds,
    DateTime? lastSeenAt,
  }) {
    return LinkedDevice(
      id: id,
      name: name ?? this.name,
      kind: kind ?? this.kind,
      platform: platform ?? this.platform,
      room: room ?? this.room,
      secret: secret ?? this.secret,
      autoSendClipboard: autoSendClipboard ?? this.autoSendClipboard,
      receiveAgentNotifications:
          receiveAgentNotifications ?? this.receiveAgentNotifications,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      manuallyDisconnected: manuallyDisconnected ?? this.manuallyDisconnected,
      pairedAt: pairedAt ?? this.pairedAt,
      sharedClipboardItemIds:
          sharedClipboardItemIds ?? this.sharedClipboardItemIds,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'kind': kind.name,
    'platform': platform,
    'room': room,
    'secret': secret,
    'autoSendClipboard': autoSendClipboard,
    'receiveAgentNotifications': receiveAgentNotifications,
    'vibrationEnabled': vibrationEnabled,
    'manuallyDisconnected': manuallyDisconnected,
    'pairedAt': pairedAt.toUtc().toIso8601String(),
    'sharedClipboardItemIds': sharedClipboardItemIds,
    if (lastSeenAt != null) 'lastSeenAt': lastSeenAt!.toUtc().toIso8601String(),
  };
}

List<String> _boundedStringList(Object? value, {required int limit}) {
  if (value is! List) return const <String>[];
  final Set<String> seen = <String>{};
  final List<String> result = <String>[];
  for (final Object? candidate in value) {
    if (candidate is! String) continue;
    final String normalized = candidate.trim();
    if (normalized.isEmpty || !seen.add(normalized)) continue;
    result.add(normalized);
    if (result.length == limit) break;
  }
  return List<String>.unmodifiable(result);
}

final class DeviceLinkDocument {
  const DeviceLinkDocument({required this.localDevice, required this.devices});

  factory DeviceLinkDocument.fromJson(Map<String, Object?> json) {
    final Object? rawDevices = json['devices'];
    return DeviceLinkDocument(
      localDevice: LocalDeviceIdentity.fromJson(
        Map<String, Object?>.from(json['localDevice']! as Map),
      ),
      devices: rawDevices is List<Object?>
          ? rawDevices
                .whereType<Map>()
                .map(
                  (Map value) =>
                      LinkedDevice.fromJson(Map<String, Object?>.from(value)),
                )
                .toList(growable: false)
          : const <LinkedDevice>[],
    );
  }

  final LocalDeviceIdentity localDevice;
  final List<LinkedDevice> devices;

  Map<String, Object?> toJson() => <String, Object?>{
    'version': 1,
    'localDevice': localDevice.toJson(),
    'devices': devices.map((LinkedDevice value) => value.toJson()).toList(),
  };
}

/// QR payload. The secret is kept in the URL fragment so it is not sent to
/// the PWA host as part of the HTTP request.
final class DevicePairingPayload {
  const DevicePairingPayload({
    required this.room,
    required this.secret,
    required this.hostId,
    required this.hostName,
    required this.relayUrl,
  });

  factory DevicePairingPayload.decode(String value) {
    final String normalized = base64Url.normalize(value);
    final Map<String, Object?> json = Map<String, Object?>.from(
      jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map,
    );
    if (json['v'] != 1) {
      throw const FormatException('Unsupported pairing payload version.');
    }
    return DevicePairingPayload(
      room: json['room']! as String,
      secret: json['secret']! as String,
      hostId: json['hostId']! as String,
      hostName: json['hostName']! as String,
      relayUrl: Uri.parse(json['relay']! as String),
    );
  }

  factory DevicePairingPayload.fromJson(Map<String, Object?> json) {
    return DevicePairingPayload(
      room: json['room']! as String,
      secret: json['secret']! as String,
      hostId: json['hostId']! as String,
      hostName: json['hostName']! as String,
      relayUrl: Uri.parse(json['relay']! as String),
    );
  }

  final String room;
  final String secret;
  final String hostId;
  final String hostName;
  final Uri relayUrl;

  Map<String, Object?> toJson() => <String, Object?>{
    'room': room,
    'secret': secret,
    'hostId': hostId,
    'hostName': hostName,
    'relay': relayUrl.toString(),
  };

  String encode() => base64Url
      .encode(
        utf8.encode(
          jsonEncode(<String, Object?>{
            'v': 1,
            'room': room,
            'secret': secret,
            'hostId': hostId,
            'hostName': hostName,
            'relay': relayUrl.toString(),
          }),
        ),
      )
      .replaceAll('=', '');
}

final class PendingDevicePairing {
  const PendingDevicePairing({
    required this.payload,
    required this.url,
    required this.createdAt,
  });

  factory PendingDevicePairing.fromJson(Map<String, Object?> json) {
    return PendingDevicePairing(
      payload: DevicePairingPayload.fromJson(
        Map<String, Object?>.from(json['payload']! as Map),
      ),
      url: Uri.parse(json['url']! as String),
      createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
    );
  }

  final DevicePairingPayload payload;
  final Uri url;
  final DateTime createdAt;

  Map<String, Object?> toJson() => <String, Object?>{
    'payload': payload.toJson(),
    'url': url.toString(),
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}
