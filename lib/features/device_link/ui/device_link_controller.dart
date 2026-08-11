import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_task_run.dart';
import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_classifier.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_share_gateway.dart';
import 'package:dingdong/features/device_link/data/device_link_session.dart';
import 'package:dingdong/features/device_link/data/device_link_store.dart';
import 'package:dingdong/features/device_link/data/secure_message_codec.dart';
import 'package:dingdong/features/device_link/domain/device_link_management.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;

const int deviceLinkMaximumFileBytes = 25 * 1024 * 1024;
const int deviceLinkMaximumTextBytes = 128 * 1024;
const int deviceLinkAgentRunningLimit = 25;
const int deviceLinkAgentHistoryLimit = 40;
const int _fileChunkBytes = 32 * 1024;

typedef AgentStateProvider =
    ({List<AgentActivity> activities, List<AgentTaskRun> activeRuns})
    Function();

final class DeviceLinkTextTooLargeException implements Exception {
  const DeviceLinkTextTooLargeException({
    required this.actualBytes,
    this.maximumBytes = deviceLinkMaximumTextBytes,
  });

  final int actualBytes;
  final int maximumBytes;

  @override
  String toString() =>
      'DeviceLinkTextTooLargeException: text is $actualBytes bytes; maximum '
      'is $maximumBytes bytes.';
}

final class DeviceLinkController extends ChangeNotifier
    implements DeviceLinkManagement {
  factory DeviceLinkController({
    required DeviceLinkStore store,
    required ClipboardStore clipboardStore,
    required Directory transferDirectory,
    required Uri? pwaBaseUrl,
    required Uri? relayBaseUrl,
    DeviceLinkSessionFactory sessionFactory = createDeviceLinkSession,
    VoidCallback? onClipboardReceived,
    AgentStateProvider? agentStateProvider,
  }) => DeviceLinkController._(
    store: store,
    clipboardStore: clipboardStore,
    transferDirectory: transferDirectory,
    pwaBaseUrl: pwaBaseUrl,
    relayBaseUrl: relayBaseUrl,
    sessionFactory: sessionFactory,
    onClipboardReceived: onClipboardReceived,
    agentStateProvider: agentStateProvider,
  );

  DeviceLinkController._({
    required this._store,
    required this._clipboardStore,
    required this._transferDirectory,
    required this._pwaBaseUrl,
    required this._relayBaseUrl,
    required this._sessionFactory,
    this.onClipboardReceived,
    this._agentStateProvider,
  });

  final DeviceLinkStore _store;
  final ClipboardStore _clipboardStore;
  final Directory _transferDirectory;
  final Uri? _pwaBaseUrl;
  final Uri? _relayBaseUrl;
  final DeviceLinkSessionFactory _sessionFactory;
  final VoidCallback? onClipboardReceived;
  final AgentStateProvider? _agentStateProvider;
  final Map<String, _ManagedDeviceSession> _sessionsByRoom =
      <String, _ManagedDeviceSession>{};
  final Map<String, DeviceConnectionStatus> _statuses =
      <String, DeviceConnectionStatus>{};
  final Map<String, _IncomingFileUpload> _incomingFiles =
      <String, _IncomingFileUpload>{};

  late LocalDeviceIdentity _localDevice;
  List<LinkedDevice> _devices = const <LinkedDevice>[];
  PendingDevicePairing? _pendingPairing;
  DeviceConnectionStatus _pairingStatus = DeviceConnectionStatus.disconnected;
  ClipboardRecord? _pendingShare;
  int _shareRequestRevision = 0;
  bool _started = false;
  bool _disposed = false;
  Future<void> _agentSyncTail = Future<void>.value();

  @override
  LocalDeviceIdentity get localDevice => _localDevice;
  @override
  List<LinkedDevice> get devices => List<LinkedDevice>.unmodifiable(_devices);
  @override
  PendingDevicePairing? get pendingPairing => _pendingPairing;
  @override
  DeviceConnectionStatus get pairingStatus => _pairingStatus;
  ClipboardRecord? get pendingShare => _pendingShare;
  int get shareRequestRevision => _shareRequestRevision;
  @override
  bool get canPair => _pwaBaseUrl != null && _relayBaseUrl != null;

  @override
  DeviceConnectionStatus statusOf(String deviceId) =>
      _statuses[deviceId] ?? DeviceConnectionStatus.disconnected;

  @override
  bool isConnected(String deviceId) =>
      statusOf(deviceId) == DeviceConnectionStatus.connected;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    final DeviceLinkDocument? document = await _store.load();
    _localDevice = document?.localDevice ?? _newLocalIdentity();
    _devices = List<LinkedDevice>.unmodifiable(
      document?.devices ?? const <LinkedDevice>[],
    );
    if (document == null) await _persist();
    for (final LinkedDevice device in _devices) {
      _statuses[device.id] = DeviceConnectionStatus.disconnected;
      if (!device.manuallyDisconnected && _relayBaseUrl != null) {
        _attachSession(device.room, deviceId: device.id);
      }
    }
    notifyListeners();
  }

  @override
  Future<PendingDevicePairing?> beginPairing() async {
    if (!canPair) return null;
    await cancelPairing();
    final DevicePairingPayload payload = DevicePairingPayload(
      room: _randomToken(18),
      secret: _randomToken(32),
      hostId: _localDevice.id,
      hostName: _localDevice.name,
      relayUrl: _relayBaseUrl!,
    );
    _pendingPairing = PendingDevicePairing(
      payload: payload,
      url: _pwaBaseUrl!.replace(fragment: 'pair=${payload.encode()}'),
      createdAt: DateTime.now().toUtc(),
    );
    _pairingStatus = DeviceConnectionStatus.connecting;
    _attachSession(payload.room);
    notifyListeners();
    return _pendingPairing;
  }

  @override
  Future<void> cancelPairing() async {
    final PendingDevicePairing? pairing = _pendingPairing;
    _pendingPairing = null;
    _pairingStatus = DeviceConnectionStatus.disconnected;
    if (pairing != null) {
      await _removeSession(pairing.payload.room);
    }
    if (!_disposed) notifyListeners();
  }

  void requestShare(ClipboardRecord record) {
    _pendingShare = record;
    _shareRequestRevision += 1;
    notifyListeners();
  }

  void clearPendingShare() {
    if (_pendingShare == null) return;
    _pendingShare = null;
    notifyListeners();
  }

  Future<void> shareRecord(ClipboardRecord record, String deviceId) async {
    await _sendClipboardRecord(record, deviceId, manual: true);
  }

  Future<void> _sendClipboardRecord(
    ClipboardRecord record,
    String deviceId, {
    required bool manual,
  }) async {
    final Map<String, Object?> payload = _recordPayload(record);
    final _ManagedDeviceSession managed = _sessionForDevice(deviceId);
    await managed.handle.send(<String, Object?>{
      'type': 'clipboard.upsert',
      'manual': manual,
      'item': payload,
    });
    await _rememberSharedClipboardItem(deviceId, record.id);
  }

  Future<void> handleLocalClipboard(ClipboardRecord record) async {
    if (record.sensitive) return;
    for (final LinkedDevice device in _devices) {
      if (!device.autoSendClipboard || !isConnected(device.id)) continue;
      if (record.updatedAt.isBefore(device.pairedAt)) continue;
      if (record.tags.contains('device-origin:${device.id}')) continue;
      try {
        await _sendClipboardRecord(record, device.id, manual: false);
      } on Object {
        // A disconnect between capture and send will update through the
        // session state; the local clipboard capture remains successful.
      }
    }
  }

  Future<void> sendAgentCompleted(
    DingRequest request, {
    required AgentActivity activity,
    required String notificationId,
  }) async {
    for (final LinkedDevice device in _devices) {
      final Map<String, Object?> message = <String, Object?>{
        'type': 'agent.completed',
        'id': notificationId,
        'activityId': activity.id,
        'title': 'Agent 完成啦',
        'source': activity.source,
        'summary': activity.message,
        'detail': request.detail ?? activity.detail ?? activity.message,
        'unseen': activity.unseen,
        if (activity.task != null) 'task': activity.task,
        if (activity.startedAt != null)
          'startedAt': activity.startedAt!.toUtc().toIso8601String(),
        'completedAt': activity.completedAt.toUtc().toIso8601String(),
        'vibrate': device.vibrationEnabled,
        if (activity.conversationTarget?.workspacePath != null)
          'workspacePath': activity.conversationTarget!.workspacePath,
        if (activity.conversationTarget?.conversationId != null)
          'conversationId': activity.conversationTarget!.conversationId,
      };
      if (isConnected(device.id)) {
        try {
          await _sessionForDevice(device.id).handle.send(message);
        } on Object {
          // The encrypted Web Push below is the background fallback.
        }
      }
      if (!device.receiveAgentNotifications) continue;
      try {
        await _sendPush(device, message);
      } on Object catch (error, stackTrace) {
        debugPrint('DingDong Web Push failed for ${device.id}: $error');
        debugPrintStack(stackTrace: stackTrace);
        // The desktop notification remains durable locally if Web Push is not
        // configured yet or the phone revoked its subscription.
      }
    }
  }

  Future<void> _sendPush(
    LinkedDevice device,
    Map<String, Object?> message,
  ) async {
    final Uri? relay = _relayBaseUrl;
    if (relay == null) return;
    final SecureMessageCodec codec = SecureMessageCodec.fromBase64Url(
      device.secret,
    );
    final SecretKey secretKey = SecretKey(
      base64Url.decode(base64Url.normalize(device.secret)),
    );
    final Mac tokenMac = await Hmac.sha256().calculateMac(
      utf8.encode('dingdong-push-v1'),
      secretKey: secretKey,
    );
    final String token = base64Url.encode(tokenMac.bytes).replaceAll('=', '');
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final ({Map<String, Object?> message, String envelope}) push =
          await _sealCompactAgentPush(codec, message);
      final HttpClientRequest request = await client.postUrl(
        _relayApiUri(relay, 'v1/push/${device.room}'),
      );
      request.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(
        jsonEncode(<String, Object?>{
          'envelope': push.envelope,
          'messageId': push.message['id'],
        }),
      );
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final String responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 8));
      final Object? decoded = responseBody.isEmpty
          ? null
          : jsonDecode(responseBody);
      final bool accepted =
          decoded is Map<String, Object?> && decoded['accepted'] == true;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          !accepted) {
        final Object? reason = decoded is Map<String, Object?>
            ? decoded['reason'] ?? decoded['error']
            : null;
        throw HttpException(
          'Push provider did not accept the message '
          '(${response.statusCode}${reason == null ? '' : ', $reason'})',
        );
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<({Map<String, Object?> message, String envelope})>
  _sealCompactAgentPush(
    SecureMessageCodec codec,
    Map<String, Object?> message,
  ) async {
    var titleBytes = 120;
    var sourceBytes = 120;
    var summaryBytes = 480;
    var detailBytes = 1300;
    for (var attempt = 0; attempt < 20; attempt += 1) {
      final Map<String, Object?> compact = _compactAgentPush(
        message,
        titleBytes: titleBytes,
        sourceBytes: sourceBytes,
        summaryBytes: summaryBytes,
        detailBytes: detailBytes,
      );
      final String envelope = await codec.seal(compact);
      if (utf8.encode(envelope).length <= 3500) {
        return (message: compact, envelope: envelope);
      }
      if (detailBytes > 160) {
        detailBytes = max(160, (detailBytes * 0.7).floor());
      } else if (summaryBytes > 120) {
        summaryBytes = max(120, (summaryBytes * 0.7).floor());
      } else if (sourceBytes > 48) {
        sourceBytes = max(48, (sourceBytes * 0.7).floor());
      } else if (titleBytes > 48) {
        titleBytes = max(48, (titleBytes * 0.7).floor());
      } else {
        break;
      }
    }
    throw const FormatException('Agent notification exceeds push envelope');
  }

  Map<String, Object?> _compactAgentPush(
    Map<String, Object?> message, {
    required int titleBytes,
    required int sourceBytes,
    required int summaryBytes,
    required int detailBytes,
  }) => <String, Object?>{
    'type': 'agent.completed',
    'id': message['id'],
    'activityId': message['activityId'],
    'title': _truncateUtf8(message['title'], titleBytes),
    'source': _truncateUtf8(message['source'], sourceBytes),
    'summary': _truncateUtf8(message['summary'], summaryBytes),
    'detail': _truncateUtf8(message['detail'], detailBytes),
    if (message['task'] != null)
      'task': _truncateUtf8(message['task'], summaryBytes),
    if (message['workspacePath'] != null)
      'workspacePath': _truncateUtf8(message['workspacePath'], 512),
    'unseen': message['unseen'] != false,
    if (message['startedAt'] != null) 'startedAt': message['startedAt'],
    'completedAt': message['completedAt'],
    'vibrate': message['vibrate'] != false,
  };

  /// Broadcasts the authoritative in-app Agent state immediately. This does
  /// not alter or retract any system notification already shown by the phone.
  Future<void> syncAgentState() {
    if (_agentStateProvider == null) {
      return Future<void>.value();
    }
    final Future<void> next = _agentSyncTail.then(
      (_) => _broadcastAgentState(),
    );
    _agentSyncTail = next;
    return next;
  }

  Future<void> _broadcastAgentState() async {
    for (final LinkedDevice device in _devices) {
      if (!isConnected(device.id)) continue;
      try {
        await _sendAgentState(_sessionForDevice(device.id));
      } on Object {
        // A reconnect receives the same authoritative snapshot after hello.
      }
    }
  }

  Future<void> _sendAgentState(_ManagedDeviceSession managed) async {
    final AgentStateProvider? provider = _agentStateProvider;
    if (provider == null) return;
    final snapshot = provider();
    await managed.handle.send(<String, Object?>{
      'type': 'agent.state',
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'running': snapshot.activeRuns
          .take(deviceLinkAgentRunningLimit)
          .map(_agentRunPayload)
          .toList(growable: false),
      'completed': snapshot.activities
          .take(deviceLinkAgentHistoryLimit)
          .map(_agentActivityPayload)
          .toList(growable: false),
    });
  }

  Map<String, Object?> _agentRunPayload(AgentTaskRun run) => <String, Object?>{
    'id': run.id,
    'source': _truncateUtf8(run.source, 96),
    'task': _truncateUtf8(run.task, 600),
    'startedAt': run.startedAt.toUtc().toIso8601String(),
    if (run.conversationTarget?.workspacePath != null)
      'workspacePath': _truncateUtf8(
        run.conversationTarget!.workspacePath,
        320,
      ),
  };

  Map<String, Object?> _agentActivityPayload(AgentActivity activity) =>
      <String, Object?>{
        'id': activity.id,
        'activityId': activity.id,
        'title': 'Agent 完成啦',
        'source': _truncateUtf8(activity.source, 96),
        'summary': _truncateUtf8(activity.message, 480),
        'detail': _truncateUtf8(activity.detail ?? activity.message, 1200),
        'unseen': activity.unseen,
        if (activity.task != null) 'task': _truncateUtf8(activity.task, 480),
        if (activity.startedAt != null)
          'startedAt': activity.startedAt!.toUtc().toIso8601String(),
        'completedAt': activity.completedAt.toUtc().toIso8601String(),
        if (activity.conversationTarget?.workspacePath != null)
          'workspacePath': _truncateUtf8(
            activity.conversationTarget!.workspacePath,
            320,
          ),
      };

  String _truncateUtf8(Object? value, int maximumBytes) {
    final String text = (value ?? '').toString();
    if (utf8.encode(text).length <= maximumBytes) return text;
    const String suffix = '…';
    final int contentBudget = maximumBytes - utf8.encode(suffix).length;
    final StringBuffer result = StringBuffer();
    var bytes = 0;
    for (final int rune in text.runes) {
      final String character = String.fromCharCode(rune);
      final int characterBytes = utf8.encode(character).length;
      if (bytes + characterBytes > contentBudget) break;
      result.write(character);
      bytes += characterBytes;
    }
    return '${result.toString()}$suffix';
  }

  @override
  Future<void> setAutoSendClipboard(String deviceId, bool value) async {
    await _updateDevice(
      deviceId,
      (LinkedDevice device) => device.copyWith(autoSendClipboard: value),
    );
  }

  @override
  Future<void> setAgentNotifications(String deviceId, bool value) async {
    await _updateDevice(
      deviceId,
      (LinkedDevice device) =>
          device.copyWith(receiveAgentNotifications: value),
    );
  }

  @override
  Future<void> disconnect(String deviceId) async {
    final LinkedDevice device = _device(deviceId);
    await _removeSession(device.room);
    _statuses[deviceId] = DeviceConnectionStatus.disconnected;
    await _updateDevice(
      deviceId,
      (LinkedDevice value) => value.copyWith(manuallyDisconnected: true),
    );
  }

  @override
  Future<void> reconnect(String deviceId) async {
    if (_relayBaseUrl == null) return;
    final LinkedDevice device = _device(deviceId);
    await _updateDevice(
      deviceId,
      (LinkedDevice value) => value.copyWith(manuallyDisconnected: false),
    );
    final _ManagedDeviceSession? session = _sessionsByRoom[device.room];
    if (session != null) {
      unawaited(session.handle.connect());
      return;
    }
    _attachSession(device.room, deviceId: device.id);
  }

  @override
  Future<void> deleteDevice(String deviceId) async {
    final LinkedDevice device = _device(deviceId);
    await _removeSession(device.room);
    _statuses.remove(deviceId);
    _devices = List<LinkedDevice>.unmodifiable(
      _devices.where((LinkedDevice value) => value.id != deviceId),
    );
    await _persist();
    notifyListeners();
  }

  void _attachSession(String room, {String? deviceId}) {
    final Uri? relayBaseUrl = _relayBaseUrl;
    if (_sessionsByRoom.containsKey(room) || relayBaseUrl == null) return;
    final String secret = deviceId == null
        ? _pendingPairing!.payload.secret
        : _device(deviceId).secret;
    final DeviceLinkSessionHandle handle = _sessionFactory(
      relayUrl: relayBaseUrl,
      room: room,
      secret: secret,
    );
    final _ManagedDeviceSession managed = _ManagedDeviceSession(
      handle: handle,
      room: room,
      deviceId: deviceId,
    );
    _sessionsByRoom[room] = managed;
    managed.subscription = handle.events.listen((DeviceLinkSessionEvent event) {
      managed.processing = managed.processing
          .then((_) => _handleSessionEvent(managed, event))
          .catchError((Object error, StackTrace stackTrace) {
            debugPrint('DingDong device message was rejected: $error');
            debugPrintStack(stackTrace: stackTrace);
          });
    });
    unawaited(handle.connect());
  }

  Future<void> _handleSessionEvent(
    _ManagedDeviceSession managed,
    DeviceLinkSessionEvent event,
  ) async {
    if (event is DeviceLinkStatusEvent) {
      final String? deviceId = managed.deviceId;
      if (deviceId == null) {
        _pairingStatus = event.status;
      } else {
        _statuses[deviceId] = event.status;
        if (event.status == DeviceConnectionStatus.connected) {
          final LinkedDevice device = _device(deviceId);
          await _replaceDevice(
            device.copyWith(lastSeenAt: DateTime.now().toUtc()),
          );
        }
      }
      if (!_disposed) notifyListeners();
      return;
    }
    if (event is DeviceLinkMessageEvent) {
      await _handleDeviceMessage(managed, event.message);
    }
  }

  Future<void> _handleDeviceMessage(
    _ManagedDeviceSession managed,
    Map<String, Object?> message,
  ) async {
    final String? type = message['type'] as String?;
    if (type == 'hello') {
      await _handleHello(managed, message);
      return;
    }
    final String? deviceId = managed.deviceId;
    if (deviceId == null) return;
    final LinkedDevice device = _device(deviceId);
    switch (type) {
      case 'clipboard.create':
        await _receiveText(managed, device, message);
      case 'file.start':
        _beginFileUpload(device, message);
      case 'file.chunk':
        _receiveFileChunk(device, message);
      case 'file.end':
        await _finishFileUpload(device, message);
      case 'file.request':
        await _sendRequestedFile(managed, message['itemId'] as String? ?? '');
      case 'settings.update':
        final Object? vibration = message['vibrationEnabled'];
        final Object? agentNotifications = message['agentNotificationsEnabled'];
        if (vibration is bool || agentNotifications is bool) {
          await _replaceDevice(
            device.copyWith(
              vibrationEnabled: vibration is bool ? vibration : null,
              receiveAgentNotifications: agentNotifications is bool
                  ? agentNotifications
                  : null,
            ),
          );
        }
    }
  }

  Future<void> _handleHello(
    _ManagedDeviceSession managed,
    Map<String, Object?> message,
  ) async {
    final Map<String, Object?> remote = Map<String, Object?>.from(
      message['device']! as Map,
    );
    final String remoteId = (remote['id'] as String? ?? '').trim();
    if (remoteId.isEmpty) return;
    LinkedDevice? device = _devices.cast<LinkedDevice?>().firstWhere(
      (LinkedDevice? value) => value?.id == remoteId,
      orElse: () => null,
    );
    if (device == null) {
      final PendingDevicePairing? pairing = _pendingPairing;
      if (pairing == null || pairing.payload.room != managed.room) return;
      device = LinkedDevice(
        id: remoteId,
        name: (remote['name'] as String? ?? '移动设备').trim(),
        kind: LinkedDeviceKind.parse(remote['kind']),
        platform: remote['platform'] as String? ?? '',
        room: pairing.payload.room,
        secret: pairing.payload.secret,
        autoSendClipboard: false,
        receiveAgentNotifications:
            message['agentNotificationsEnabled'] != false,
        vibrationEnabled: message['vibrationEnabled'] != false,
        manuallyDisconnected: false,
        pairedAt: DateTime.now().toUtc(),
        sharedClipboardItemIds: const <String>[],
        lastSeenAt: DateTime.now().toUtc(),
      );
      _devices = List<LinkedDevice>.unmodifiable(<LinkedDevice>[
        ..._devices,
        device,
      ]);
      managed.deviceId = remoteId;
      _statuses[remoteId] = DeviceConnectionStatus.connected;
      _pendingPairing = null;
      _pairingStatus = DeviceConnectionStatus.connected;
      await _persist();
    } else {
      final PendingDevicePairing? pairing = _pendingPairing;
      final bool replacingExistingPair =
          pairing != null && pairing.payload.room == managed.room;
      final String previousRoom = device.room;
      managed.deviceId = remoteId;
      device = device.copyWith(
        name: (remote['name'] as String?)?.trim(),
        kind: LinkedDeviceKind.parse(remote['kind']),
        platform: remote['platform'] as String?,
        room: replacingExistingPair ? pairing.payload.room : null,
        secret: replacingExistingPair ? pairing.payload.secret : null,
        vibrationEnabled: message['vibrationEnabled'] is bool
            ? message['vibrationEnabled']! as bool
            : null,
        manuallyDisconnected: replacingExistingPair ? false : null,
        pairedAt: replacingExistingPair ? DateTime.now().toUtc() : null,
        lastSeenAt: DateTime.now().toUtc(),
      );
      await _replaceDevice(device);
      if (replacingExistingPair) {
        _pendingPairing = null;
        _pairingStatus = DeviceConnectionStatus.connected;
        _statuses[remoteId] = DeviceConnectionStatus.connected;
        if (previousRoom != managed.room) {
          await _removeSession(previousRoom);
        }
      }
    }
    await managed.handle.send(<String, Object?>{
      'type': 'welcome',
      'host': <String, Object?>{..._localDevice.toJson(), 'kind': 'computer'},
      'permissions': <String, Object?>{
        'autoSendClipboard': device.autoSendClipboard,
        'receiveAgentNotifications': device.receiveAgentNotifications,
      },
    });
    await _sendSnapshot(managed);
    if (!_disposed) notifyListeners();
  }

  Future<void> _sendSnapshot(_ManagedDeviceSession managed) async {
    final String? deviceId = managed.deviceId;
    final LinkedDevice? device = deviceId == null ? null : _device(deviceId);
    final List<String> allowedIds =
        device?.sharedClipboardItemIds ?? const <String>[];
    final Map<String, ClipboardRecord> recordsById = <String, ClipboardRecord>{
      for (final ClipboardRecord record in _clipboardStore.list(
        limit: 5000,
        includeProtectedBeyondLimit: true,
      ))
        record.id: record,
    };
    final List<ClipboardRecord> records = allowedIds
        .map((String id) => recordsById[id])
        .whereType<ClipboardRecord>()
        .take(deviceLinkClipboardHistoryLimit)
        .toList(growable: false);
    await managed.handle.send(<String, Object?>{
      'type': 'clipboard.snapshot',
      'items': const <Object?>[],
    });
    for (final ClipboardRecord record in records.reversed) {
      try {
        await managed.handle.send(<String, Object?>{
          'type': 'clipboard.upsert',
          'manual': false,
          'snapshot': true,
          'item': _recordPayload(record),
        });
      } on DeviceLinkTextTooLargeException catch (error) {
        debugPrint(
          'DingDong skipped oversized clipboard snapshot item '
          '${record.id}: $error',
        );
      } on DeviceLinkFrameTooLargeException catch (error) {
        debugPrint(
          'DingDong skipped clipboard snapshot frame ${record.id}: $error',
        );
      }
    }
    await _sendAgentState(managed);
  }

  Future<void> _rememberSharedClipboardItem(
    String deviceId,
    String recordId,
  ) async {
    final LinkedDevice device = _device(deviceId);
    final List<String> ids = <String>[
      recordId,
      ...device.sharedClipboardItemIds.where((String id) => id != recordId),
    ].take(deviceLinkClipboardHistoryLimit).toList(growable: false);
    await _replaceDevice(device.copyWith(sharedClipboardItemIds: ids));
  }

  Map<String, Object?> _recordPayload(ClipboardRecord record) {
    final File? file = _firstExistingFile(record);
    final bool fileBacked = file != null;
    if (!record.sensitive && !fileBacked) {
      final int contentBytes = utf8.encode(record.content).length;
      if (contentBytes > deviceLinkMaximumTextBytes) {
        throw DeviceLinkTextTooLargeException(actualBytes: contentBytes);
      }
    }
    return <String, Object?>{
      'id': record.id,
      'title': record.title,
      'kind': record.kind.name,
      'sensitive': record.sensitive,
      'createdAt': record.createdAt.toUtc().toIso8601String(),
      'updatedAt': record.updatedAt.toUtc().toIso8601String(),
      'sources': record.sources,
      if (!record.sensitive && !fileBacked) 'content': record.content,
      if (fileBacked) ...<String, Object?>{
        'fileName': path.basename(file.path),
        'fileSize': file.lengthSync(),
        'downloadable': file.lengthSync() <= deviceLinkMaximumFileBytes,
      },
    };
  }

  Future<void> _receiveText(
    _ManagedDeviceSession managed,
    LinkedDevice device,
    Map<String, Object?> message,
  ) async {
    final String content = (message['content'] as String? ?? '').trim();
    if (content.isEmpty) return;
    final int contentBytes = utf8.encode(content).length;
    if (contentBytes > deviceLinkMaximumTextBytes) {
      await managed.handle.send(<String, Object?>{
        'type': 'request.rejected',
        'requestType': 'clipboard.create',
        if (message['requestId'] is String)
          'requestId': message['requestId']! as String,
        'code': 'text_too_large',
        'maximumBytes': deviceLinkMaximumTextBytes,
      });
      return;
    }
    final ClipboardClassification classification = ClipboardClassifier.classify(
      content,
    );
    final DateTime now = DateTime.now().toUtc();
    final ClipboardRecord record = ClipboardRecord(
      id: 'DEVICE-${now.microsecondsSinceEpoch}-${_randomToken(6)}',
      group: classification.group,
      title: (message['title'] as String?)?.trim().isNotEmpty == true
          ? (message['title']! as String).trim()
          : classification.title,
      content: content,
      tags: <String>[...classification.tags, 'device-origin:${device.id}'],
      source: '来自 ${device.name}',
      pinned: false,
      enabled: true,
      activation: 'taskMatch',
      createdAt: now,
      updatedAt: now,
    );
    _clipboardStore.save(record);
    onClipboardReceived?.call();
  }

  void _beginFileUpload(LinkedDevice device, Map<String, Object?> message) {
    final String transferId = message['transferId'] as String? ?? '';
    final int size = (message['size'] as num?)?.toInt() ?? -1;
    if (transferId.isEmpty || size < 0 || size > deviceLinkMaximumFileBytes) {
      return;
    }
    _incomingFiles[transferId] = _IncomingFileUpload(
      deviceId: device.id,
      name: sanitizeDeviceLinkFileName(message['name'] as String? ?? '共享文件'),
      expectedBytes: size,
    );
  }

  void _receiveFileChunk(LinkedDevice device, Map<String, Object?> message) {
    final String transferId = message['transferId'] as String? ?? '';
    final _IncomingFileUpload? upload = _incomingFiles[transferId];
    if (upload == null || upload.deviceId != device.id) return;
    final int index = (message['index'] as num?)?.toInt() ?? -1;
    final String data = message['data'] as String? ?? '';
    if (index < 0 || data.isEmpty || upload.chunks.containsKey(index)) return;
    final Uint8List bytes = base64Decode(data);
    if (upload.receivedBytes + bytes.length > upload.expectedBytes) {
      _incomingFiles.remove(transferId);
      return;
    }
    upload.chunks[index] = bytes;
    upload.receivedBytes += bytes.length;
  }

  Future<void> _finishFileUpload(
    LinkedDevice device,
    Map<String, Object?> message,
  ) async {
    final String transferId = message['transferId'] as String? ?? '';
    final _IncomingFileUpload? upload = _incomingFiles.remove(transferId);
    if (upload == null ||
        upload.deviceId != device.id ||
        upload.receivedBytes != upload.expectedBytes) {
      return;
    }
    await _transferDirectory.create(recursive: true);
    final String outputName =
        '${DateTime.now().millisecondsSinceEpoch}-${upload.name}';
    final File output = File(path.join(_transferDirectory.path, outputName));
    final IOSink sink = output.openWrite();
    try {
      final List<int> indices = upload.chunks.keys.toList()..sort();
      for (final int index in indices) {
        sink.add(upload.chunks[index]!);
      }
    } finally {
      await sink.close();
    }
    final DateTime now = DateTime.now().toUtc();
    _clipboardStore.save(
      ClipboardRecord(
        id: 'DEVICE-FILE-${now.microsecondsSinceEpoch}-${_randomToken(6)}',
        group: '',
        title: upload.name,
        content: output.path,
        tags: <String>[
          'clipboard',
          'file',
          'file-url',
          'device-origin:${device.id}',
        ],
        source: '来自 ${device.name}',
        pinned: false,
        enabled: true,
        activation: 'taskMatch',
        createdAt: now,
        updatedAt: now,
      ),
    );
    onClipboardReceived?.call();
  }

  Future<void> _sendRequestedFile(
    _ManagedDeviceSession managed,
    String itemId,
  ) async {
    final String? deviceId = managed.deviceId;
    if (deviceId == null ||
        !_device(deviceId).sharedClipboardItemIds.contains(itemId)) {
      return;
    }
    ClipboardRecord? record;
    for (final ClipboardRecord candidate in _clipboardStore.list(
      limit: 5000,
      includeProtectedBeyondLimit: true,
    )) {
      if (candidate.id == itemId) {
        record = candidate;
        break;
      }
    }
    final File? file = record == null ? null : _firstExistingFile(record);
    if (file == null || file.lengthSync() > deviceLinkMaximumFileBytes) return;
    final String transferId = 'download-${_randomToken(12)}';
    await managed.handle.send(<String, Object?>{
      'type': 'file.start',
      'transferId': transferId,
      'itemId': record!.id,
      'name': path.basename(file.path),
      'size': file.lengthSync(),
    });
    final RandomAccessFile input = await file.open();
    var index = 0;
    try {
      while (true) {
        final Uint8List chunk = await input.read(_fileChunkBytes);
        if (chunk.isEmpty) break;
        await managed.handle.send(<String, Object?>{
          'type': 'file.chunk',
          'transferId': transferId,
          'index': index,
          'data': base64Encode(chunk),
        });
        index += 1;
        if (index % 16 == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 8));
        }
      }
    } finally {
      await input.close();
    }
    await managed.handle.send(<String, Object?>{
      'type': 'file.end',
      'transferId': transferId,
      'itemId': record.id,
    });
  }

  Future<void> _updateDevice(
    String deviceId,
    LinkedDevice Function(LinkedDevice device) update,
  ) async {
    await _replaceDevice(update(_device(deviceId)));
  }

  Future<void> _replaceDevice(LinkedDevice next) async {
    _devices = List<LinkedDevice>.unmodifiable(
      _devices.map(
        (LinkedDevice device) => device.id == next.id ? next : device,
      ),
    );
    await _persist();
    if (!_disposed) notifyListeners();
  }

  LinkedDevice _device(String id) =>
      _devices.firstWhere((LinkedDevice device) => device.id == id);

  _ManagedDeviceSession _sessionForDevice(String deviceId) {
    final LinkedDevice device = _device(deviceId);
    final _ManagedDeviceSession? session = _sessionsByRoom[device.room];
    if (session == null || !session.handle.connected) {
      throw StateError('The selected device is offline.');
    }
    return session;
  }

  Future<void> _removeSession(String room) async {
    final _ManagedDeviceSession? session = _sessionsByRoom.remove(room);
    if (session == null) return;
    await session.subscription?.cancel();
    await session.handle.close();
  }

  Future<void> _persist() => _store.save(
    DeviceLinkDocument(localDevice: _localDevice, devices: _devices),
  );

  Future<void> shutdown() async {
    final List<String> rooms = _sessionsByRoom.keys.toList(growable: false);
    for (final String room in rooms) {
      await _removeSession(room);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(shutdown());
    super.dispose();
  }
}

final class DeviceClipboardShareGateway implements ClipboardShareGateway {
  const DeviceClipboardShareGateway(this.controller);

  final DeviceLinkController controller;

  @override
  Future<void> share(ClipboardRecord record) async {
    controller.requestShare(record);
  }
}

final class _ManagedDeviceSession {
  _ManagedDeviceSession({
    required this.handle,
    required this.room,
    required this.deviceId,
  });

  final DeviceLinkSessionHandle handle;
  final String room;
  String? deviceId;
  StreamSubscription<DeviceLinkSessionEvent>? subscription;
  Future<void> processing = Future<void>.value();
}

final class _IncomingFileUpload {
  _IncomingFileUpload({
    required this.deviceId,
    required this.name,
    required this.expectedBytes,
  });

  final String deviceId;
  final String name;
  final int expectedBytes;
  final Map<int, Uint8List> chunks = <int, Uint8List>{};
  int receivedBytes = 0;
}

LocalDeviceIdentity _newLocalIdentity() {
  final String name = Platform.localHostname.trim();
  return LocalDeviceIdentity(
    id: 'desktop-${_randomToken(12)}',
    name: name.isEmpty ? 'DingDong 电脑' : name,
    platform: Platform.operatingSystem,
  );
}

String _randomToken(int bytes) {
  final Random random = Random.secure();
  return base64Url
      .encode(List<int>.generate(bytes, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}

File? _firstExistingFile(ClipboardRecord record) {
  for (final String value in record.filePaths) {
    final File file = File(value);
    if (file.existsSync()) return file;
  }
  return null;
}

String sanitizeDeviceLinkFileName(String value) {
  const String fallback = '共享文件';
  final List<String> segments = value.trim().split(RegExp(r'[/\\]+'));
  String base = (segments.isEmpty ? '' : segments.last)
      .replaceAll(RegExp(r'[\x00-\x1f<>:"/\\|?*]'), '_')
      .replaceFirst(RegExp(r'[ .]+$'), '');
  if (base.isEmpty || base == '.' || base == '..') base = fallback;
  final String deviceStem = base
      .split('.')
      .first
      .replaceFirst(RegExp(r'[ .]+$'), '');
  if (RegExp(
    r'^(?:con|prn|aux|nul|clock\$|conin\$|conout\$|com[1-9¹²³]|lpt[1-9¹²³])$',
    caseSensitive: false,
  ).hasMatch(deviceStem)) {
    base = '_$base';
  }
  return _truncateDeviceLinkFileName(base, maximumBytes: 180);
}

String _truncateDeviceLinkFileName(String value, {required int maximumBytes}) {
  if (utf8.encode(value).length <= maximumBytes) return value;
  final int dot = value.lastIndexOf('.');
  final String extension = dot > 0 ? value.substring(dot) : '';
  final bool preserveExtension =
      extension.isNotEmpty && utf8.encode(extension).length <= 32;
  final String stem = preserveExtension ? value.substring(0, dot) : value;
  final int stemBudget =
      maximumBytes - (preserveExtension ? utf8.encode(extension).length : 0);
  final StringBuffer truncated = StringBuffer();
  var bytes = 0;
  for (final int rune in stem.runes) {
    final String character = String.fromCharCode(rune);
    final int characterBytes = utf8.encode(character).length;
    if (bytes + characterBytes > stemBudget) break;
    truncated.write(character);
    bytes += characterBytes;
  }
  return '${truncated.toString()}${preserveExtension ? extension : ''}';
}

Uri _relayApiUri(Uri base, String path) {
  final String basePath = base.path == '/' ? '' : base.path;
  return base.replace(path: '$basePath/$path', query: '', fragment: '');
}
