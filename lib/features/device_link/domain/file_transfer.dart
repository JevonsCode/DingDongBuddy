import 'package:flutter/foundation.dart';

const int relayFileLimit = 25 * 1024 * 1024;
const int transferChunkBytes = 32 * 1024;

class FileTransfer {
  factory FileTransfer.fromJson(Map<String, Object?> json) => FileTransfer(
    id: json['id']! as String,
    deviceId: json['deviceId']! as String,
    name: json['name']! as String,
    size: json['size']! as int,
    sending: json['sending'] == true,
    itemId: json['itemId'] as String?,
    status: json['status']! as String,
    bytes: json['bytes']! as int,
    detail: json['detail'] as String? ?? '',
    lan: json['lan'] == true,
    deviceName: json['deviceName'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
    finishedAt: DateTime.tryParse(json['finishedAt'] as String? ?? ''),
    archived: json['archived'] == true,
  )..bytesPerSecond = (json['bytesPerSecond'] as num?)?.toDouble() ?? 0;
  FileTransfer({
    required this.id,
    required this.deviceId,
    required this.name,
    required this.size,
    required this.sending,
    this.itemId,
    this.status = 'preparing',
    this.bytes = 0,
    this.detail = '',
    this.lan = false,
    this.deviceName,
    DateTime? createdAt,
    this.finishedAt,
    this.archived = false,
  }) : createdAt = createdAt ?? DateTime.now().toUtc();
  final String id, deviceId, name;
  final int size;
  final bool sending;
  final String? itemId;
  final String? deviceName;
  final DateTime createdAt;
  DateTime? finishedAt;
  bool archived;
  String status, detail;
  int bytes;
  bool lan;
  double bytesPerSecond = 0;
  int _sampleBytes = 0;
  DateTime _sampleAt = DateTime.now();
  bool get terminal =>
      archived || const ['completed', 'cancelled', 'sent'].contains(status);
  double get progress =>
      size == 0 ? (status == 'completed' ? 1 : 0) : (bytes / size).clamp(0, 1);
  void advance(int value) {
    final now = DateTime.now();
    final milliseconds = now.difference(_sampleAt).inMilliseconds;
    if (value < bytes) bytesPerSecond = 0;
    if (milliseconds >= 400) {
      final speed = (value - _sampleBytes).clamp(0, size) * 1000 / milliseconds;
      bytesPerSecond = bytesPerSecond == 0
          ? speed
          : bytesPerSecond * .65 + speed * .35;
      _sampleBytes = value;
      _sampleAt = now;
    }
    bytes = value;
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'name': name,
    'size': size,
    'sending': sending,
    'itemId': itemId,
    'status': status,
    'bytes': bytes,
    'detail': detail,
    'lan': lan,
    'bytesPerSecond': bytesPerSecond,
    'deviceName': deviceName,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'finishedAt': finishedAt?.toUtc().toIso8601String(),
    'archived': archived,
  };
}

abstract interface class FileTransferManagement implements Listenable {
  List<FileTransfer> get fileTransfers;
  Future<void> controlFileTransfer(String id, String deviceId, String action);
}
