import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
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
import 'package:flutter/widgets.dart' show Locale;
import 'package:path/path.dart' as path;

// Protocol, transfer, Agent, and persistence concerns are private parts of the
// controller library; the public DeviceLinkController API remains centralized.
part 'device_link_agent_sync.dart';
part 'device_link_file_transfer.dart';
part 'device_link_persistence.dart';
part 'device_link_session_protocol.dart';
part 'device_link_support.dart';

const int deviceLinkMaximumFileBytes = 25 * 1024 * 1024;
const int deviceLinkMaximumTextBytes = 128 * 1024;
const int deviceLinkAgentRunningLimit = 25;
const int deviceLinkAgentHistoryLimit = 40;
const int deviceLinkMaximumConcurrentFileUploads = 3;
const int _fileChunkBytes = 32 * 1024;
const Duration _incomingFileUploadIdleTimeout = Duration(minutes: 5);

typedef AgentStateProvider =
    ({List<AgentActivity> activities, List<AgentTaskRun> activeRuns})
    Function();
typedef AgentSeenCallback = void Function(List<String> activityIds);

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
    AgentSeenCallback? onAgentSeen,
    DingDongLocalizations Function()? localizations,
  }) => DeviceLinkController._(
    store: store,
    clipboardStore: clipboardStore,
    transferDirectory: transferDirectory,
    pwaBaseUrl: pwaBaseUrl,
    relayBaseUrl: relayBaseUrl,
    sessionFactory: sessionFactory,
    onClipboardReceived: onClipboardReceived,
    agentStateProvider: agentStateProvider,
    onAgentSeen: onAgentSeen,
    localizations: localizations,
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
    this._onAgentSeen,
    DingDongLocalizations Function()? localizations,
  }) : _localizations =
           localizations ??
           (() => lookupDingDongLocalizations(const Locale('en')));

  final DeviceLinkStore _store;
  final ClipboardStore _clipboardStore;
  final Directory _transferDirectory;
  final Uri? _pwaBaseUrl;
  final Uri? _relayBaseUrl;
  final DeviceLinkSessionFactory _sessionFactory;
  final VoidCallback? onClipboardReceived;
  final AgentStateProvider? _agentStateProvider;
  final AgentSeenCallback? _onAgentSeen;
  final DingDongLocalizations Function() _localizations;
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
    _localDevice = document?.localDevice ?? _newLocalIdentity(_localizations());
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
    final bool needsUserAttention =
        request.notificationKind == AgentNotificationKind.attention;
    for (final LinkedDevice device in _devices) {
      final Map<String, Object?> message = <String, Object?>{
        'type': 'agent.completed',
        'id': notificationId,
        'activityId': activity.id,
        'title': needsUserAttention
            ? _localizations().agentNeedsYourAttention
            : _localizations().agentCompleted,
        'source': activity.source,
        'summary': activity.message,
        'detail': request.detail ?? activity.detail ?? activity.message,
        'notificationKind': request.notificationKind.apiValue,
        'needsUserAttention': needsUserAttention,
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

  /// Gives private controller parts a safe notification boundary without
  /// calling ChangeNotifier's protected member from extension code.
  void _notifyIfActive() {
    if (!_disposed) notifyListeners();
  }

  Future<void> shutdown() async {
    final List<String> rooms = _sessionsByRoom.keys.toList(growable: false);
    for (final String room in rooms) {
      await _removeSession(room);
    }
    final List<String> transferKeys = _incomingFiles.keys.toList(
      growable: false,
    );
    for (final String key in transferKeys) {
      await _discardIncomingFileUpload(key);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(shutdown());
    super.dispose();
  }
}
