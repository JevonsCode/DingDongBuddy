import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dingdong_link_protocol/dingdong_link_protocol.dart';

import 'agent_event.dart';
import 'clipboard_item.dart';
import 'companion_store.dart';
import 'relay_peer.dart';

/// Posts Agent reminders; implemented with flutter_local_notifications in
/// the service isolate and with a recorder in tests.
abstract interface class AgentNotifier {
  Future<void> show(AgentEvent event, {required String hostName});
}

/// Limits shared with the PWA and the desktop (`docs/app/app.js`,
/// `device_link_controller.dart`).
const int maximumTextBytes = 128 * 1024;
const int maximumFileBytes = 25 * 1024 * 1024;
const int fileChunkBytes = 32 * 1024;
const Duration fileRequestTimeout = Duration(seconds: 30);

final class _ComputerSession {
  _ComputerSession(this.record);

  final PairingRecord record;
  RelayPeer? peer;
  LinkState state = LinkState.offline;
  final List<ClipboardItem> items = <ClipboardItem>[];
  List<AgentRun> runs = <AgentRun>[];
  DateTime? lastSyncAt;
  bool sending = false;
  final Map<String, _Download> downloads = <String, _Download>{};
  final Set<String> pendingFileRequests = <String>{};

  /// The desktop answers a request it cannot serve with nothing at all, so a
  /// request that never starts is cleared after [fileRequestTimeout].
  final Map<String, Timer> fileRequestTimers = <String, Timer>{};
}

final class _Download {
  _Download({
    required this.itemId,
    required this.name,
    required this.size,
    required this.mime,
    required this.file,
    required this.sink,
  });

  final String? itemId;
  final String name;
  final int size;
  final String mime;
  final File file;
  final IOSink sink;
  int received = 0;
  int nextIndex = 0;
}

/// The single owner of relay sockets, state and reminders. It runs inside
/// the foreground-service isolate; the UI isolate only renders [snapshot]s
/// and sends commands to [handleCommand].
final class CompanionEngine {
  CompanionEngine({
    required this.store,
    required this.notifier,
    required this.downloadDirectory,
    required this._emit,
    this._onSummary,
    this._onEmpty,
    this._connector = connectIoSocket,
    this._defaultDeviceName = 'Android 手机',
  });

  final CompanionStore store;
  final AgentNotifier notifier;
  final Directory downloadDirectory;
  final void Function(Map<String, Object?> event) _emit;
  final void Function(String summary)? _onSummary;

  /// Called when no computer is paired any more, so the service can stop.
  final void Function()? _onEmpty;
  final LinkSocketConnector _connector;
  final String _defaultDeviceName;
  final Map<String, _ComputerSession> _sessions = <String, _ComputerSession>{};
  final Random _random = Random.secure();
  Timer? _snapshotTimer;

  String get deviceName => store.deviceName ?? _defaultDeviceName;

  void start() {
    for (final PairingRecord record in store.pairings) {
      _attach(record);
    }
    _publish();
  }

  Future<void> dispose() async {
    _snapshotTimer?.cancel();
    for (final _ComputerSession session in _sessions.values) {
      _cancelFileRequests(session);
      await session.peer?.close();
    }
    // A stop right after an event must not drop its queued save.
    await store.flush();
  }

  void _cancelFileRequests(_ComputerSession session) {
    for (final Timer timer in session.fileRequestTimers.values) {
      timer.cancel();
    }
    session.fileRequestTimers.clear();
  }

  bool get hasPairings => store.pairings.isNotEmpty;

  /// Called when Android reports a usable network again.
  void networkAvailable() {
    for (final _ComputerSession session in _sessions.values) {
      session.peer?.networkAvailable();
    }
  }

  void _attach(PairingRecord record) {
    final _ComputerSession session = _ComputerSession(record);
    _sessions[record.room] = session;
    if (!record.manualDisconnect) _connect(session);
  }

  void _connect(_ComputerSession session) {
    final PairingRecord record = session.record;
    final RelayPeer peer = RelayPeer(
      pairing: record.payload,
      connector: _connector,
      hello: () => <String, Object?>{
        'type': 'hello',
        'device': <String, Object?>{
          'id': store.deviceId,
          'name': deviceName,
          'kind': 'phone',
          'platform': 'android',
        },
        'vibrationEnabled': record.vibrationEnabled,
        'agentNotificationsEnabled': record.agentNotificationsEnabled,
      },
      settings: () => <String, Object?>{
        'vibrationEnabled': record.vibrationEnabled,
        'agentNotificationsEnabled': record.agentNotificationsEnabled,
      },
      onState: (LinkState state) => _stateChanged(session, state),
      onMessage: (Map<String, Object?> message) =>
          _handleMessage(session, message),
    );
    session.peer = peer;
    peer.connect();
  }

  void _stateChanged(_ComputerSession session, LinkState state) {
    session.state = state;
    if (state != LinkState.connected) {
      // Like the PWA: the computer's clipboard is not cached while offline.
      session.items.clear();
      session.runs = <AgentRun>[];
      session.lastSyncAt = null;
      session.pendingFileRequests.clear();
      _cancelFileRequests(session);
      for (final _Download download in session.downloads.values) {
        unawaited(_discard(download));
      }
      session.downloads.clear();
    }
    _publish();
  }

  Future<void> _handleMessage(
    _ComputerSession session,
    Map<String, Object?> message,
  ) async {
    switch (message['type']) {
      case 'welcome':
        final Object? host = message['host'];
        if (host is Map) {
          bool changed = false;
          final Object? rawName = host['name'];
          if (rawName is String) {
            final String name = rawName.trim();
            if (name.isNotEmpty && name != session.record.hostName) {
              session.record.hostName = name.length > 80
                  ? name.substring(0, 80)
                  : name;
              changed = true;
            }
          }
          // Computers send Dart's Platform.operatingSystem, e.g. "windows".
          final Object? platform = host['platform'];
          if (platform is String &&
              _platformPattern.hasMatch(platform) &&
              platform != session.record.hostPlatform) {
            session.record.hostPlatform = platform;
            changed = true;
          }
          if (changed) await store.save();
        }
      case 'clipboard.snapshot':
        session.items.clear();
        for (final Object? value
            in message['items'] as List? ?? const <Object?>[]) {
          final ClipboardItem? item = ClipboardItem.parse(value);
          if (item != null) session.items.add(item);
        }
        session.lastSyncAt = DateTime.now();
      case 'clipboard.upsert':
        final ClipboardItem? item = ClipboardItem.parse(message['item']);
        if (item == null) return;
        session.items.removeWhere((ClipboardItem e) => e.id == item.id);
        session.items.insert(0, item);
        if (session.items.length > 50) session.items.removeLast();
        session.lastSyncAt = DateTime.now();
        if (message['manual'] == true && message['snapshot'] != true) {
          _toast('收到“${session.record.hostName}”发来的内容');
        }
      case 'request.rejected':
        _toast(
          message['code'] == 'text_too_large'
              ? '文字超过 128 KB，请改为选择文件发送'
              : '电脑拒绝了这次请求',
        );
      case 'agent.completed':
        await _receiveAgentEvent(session, message);
      case 'agent.state':
        _receiveAgentState(session, message);
      case 'file.start':
        await _beginDownload(session, message);
      case 'file.chunk':
        await _downloadChunk(session, message);
      case 'file.end':
        await _finishDownload(session, message);
    }
    _publish();
  }

  Future<void> _receiveAgentEvent(
    _ComputerSession session,
    Map<String, Object?> message,
  ) async {
    final AgentEvent? event = AgentEvent.parse(message);
    if (event == null) return;
    final List<AgentEvent> events = store.agentEvents.putIfAbsent(
      session.record.room,
      () => <AgentEvent>[],
    );
    events.removeWhere((AgentEvent e) => e.seenKey == event.seenKey);
    events.insert(0, event);
    _trimEvents(events);
    final bool firstTime = store.markNotified(event.id);
    await store.save();
    if (firstTime &&
        !event.silent &&
        session.record.agentNotificationsEnabled &&
        store.alertsFor(event.kind)) {
      await notifier.show(event, hostName: session.record.hostName);
    }
  }

  void _receiveAgentState(
    _ComputerSession session,
    Map<String, Object?> message,
  ) {
    session.runs = <AgentRun>[
      for (final Object? value
          in message['running'] as List? ?? const <Object?>[])
        ?AgentRun.parse(value),
    ];
    final List<AgentEvent> completed = <AgentEvent>[
      for (final Object? value
          in message['completed'] as List? ?? const <Object?>[])
        if (value is Map) ?AgentEvent.parse(Map<String, Object?>.from(value)),
    ];
    // Like the PWA, the desktop's list replaces the history (it is
    // authoritative for what exists and what was seen). History never posts
    // notifications.
    final List<AgentEvent> history = completed
      ..sort(
        (AgentEvent a, AgentEvent b) => (b.completedAt ?? DateTime(0))
            .compareTo(a.completedAt ?? DateTime(0)),
      );
    _trimEvents(history);
    store.agentEvents[session.record.room] = history;
    // Don't mark these as notified: the desktop broadcasts agent.state
    // (already listing a new activity) just before agent.completed with the
    // same id, and that reminder must still alert.
    unawaited(store.save());
  }

  void _trimEvents(List<AgentEvent> events) {
    if (events.length > CompanionStore.maximumEventsPerComputer) {
      events.removeRange(
        CompanionStore.maximumEventsPerComputer,
        events.length,
      );
    }
  }

  // ---- Commands from the UI isolate ----

  Future<void> handleCommand(Map<String, Object?> command) async {
    final String? room = command['room'] as String?;
    final _ComputerSession? session = room == null ? null : _sessions[room];
    try {
      switch (command['cmd']) {
        case 'snapshot':
          _publish(immediate: true);
        case 'pair':
          await _pair(
            command['link']! as String,
            command['deviceName'] as String?,
          );
        case 'select':
          if (session != null) {
            store.activeRoom = room;
            await store.save();
          }
        case 'remove':
          if (session != null) await _remove(session);
        case 'disconnect':
          if (session != null) {
            session.record.manualDisconnect = true;
            await store.save();
            await session.peer?.close();
            session.peer = null;
            _stateChanged(session, LinkState.disconnected);
          }
        case 'reconnect':
          if (session != null) {
            session.record.manualDisconnect = false;
            await store.save();
            final RelayPeer? peer = session.peer;
            if (peer == null) {
              _connect(session);
            } else {
              peer.nudge();
            }
          }
        case 'settings':
          if (session != null) await _updateSettings(session, command);
        case 'alerts':
          await _updateAlerts(command);
        case 'sendText':
          if (session != null) {
            await _sendText(session, command['text']! as String);
          }
        case 'sendFile':
          if (session != null) {
            await _sendFile(
              session,
              File(command['path']! as String),
              command['name']! as String,
              command['mime'] as String? ?? 'application/octet-stream',
            );
          }
        case 'requestFile':
          if (session != null) {
            await _requestFile(session, command['itemId']! as String);
          }
        case 'copy':
          if (session != null) _copy(session, command['itemId']! as String);
        case 'markSeen':
          if (session != null) {
            await _markSeen(session, (command['ids']! as List).cast<String>());
          }
        case 'test':
          await notifier.show(
            _testEvent(
              command['kind'] == 'attention'
                  ? AgentKind.attention
                  : AgentKind.completion,
            ),
            hostName: '本机测试',
          );
      }
    } on FormatException {
      _toast('这不是有效的 DingDong 连接链接，请重新复制');
    } on Object catch (error) {
      _toast(error is StateError ? error.message : '操作失败：$error');
    }
    _publish(immediate: true);
    if (store.pairings.isEmpty &&
        (command['cmd'] == 'remove' || command['cmd'] == 'pair')) {
      _onEmpty?.call();
    }
  }

  Future<void> _pair(String link, String? name) async {
    final DevicePairingPayload payload = DevicePairingPayload.parseInput(link);
    if (name != null && name.trim().isNotEmpty) {
      final String trimmed = name.trim();
      store.deviceName = trimmed.length > 32
          ? trimmed.substring(0, 32)
          : trimmed;
    }
    final _ComputerSession? existing = _sessions[payload.room];
    if (existing != null) await _remove(existing, save: false);
    // One room per computer: a re-scan from the same desktop replaces it.
    for (final _ComputerSession other in _sessions.values.toList()) {
      if (other.record.payload.hostId == payload.hostId) {
        await _remove(other, save: false);
      }
    }
    final PairingRecord record = PairingRecord(
      payload: payload,
      hostName: payload.hostName,
    );
    store.pairings.add(record);
    store.activeRoom = record.room;
    await store.save();
    _attach(record);
  }

  Future<void> _remove(_ComputerSession session, {bool save = true}) async {
    _sessions.remove(session.record.room);
    _cancelFileRequests(session);
    await session.peer?.close();
    store.pairings.removeWhere(
      (PairingRecord p) => p.room == session.record.room,
    );
    store.agentEvents.remove(session.record.room);
    if (store.activeRoom == session.record.room) {
      store.activeRoom = store.pairings.isEmpty
          ? null
          : store.pairings.first.room;
    }
    if (save) await store.save();
  }

  Future<void> _updateSettings(
    _ComputerSession session,
    Map<String, Object?> command,
  ) async {
    final Object? agent = command['agentNotificationsEnabled'];
    final Object? vibration = command['vibrationEnabled'];
    if (agent is bool) session.record.agentNotificationsEnabled = agent;
    if (vibration is bool) session.record.vibrationEnabled = vibration;
    await store.save();
    if (session.peer?.isConnected == true) {
      await session.peer!.send(<String, Object?>{
        'type': 'settings.update',
        'agentNotificationsEnabled': session.record.agentNotificationsEnabled,
        'vibrationEnabled': session.record.vibrationEnabled,
        'transportPreference': 'serviceRelay',
      });
    }
  }

  Future<void> _updateAlerts(Map<String, Object?> command) async {
    final Object? enabled = command['enabled'];
    final Object? completion = command['completion'];
    final Object? attention = command['attention'];
    if (enabled is bool) store.alertsEnabled = enabled;
    if (completion is bool) store.completionAlertsEnabled = completion;
    if (attention is bool) store.attentionAlertsEnabled = attention;
    await store.save();
  }

  RelayPeer _connectedPeer(_ComputerSession session) {
    final RelayPeer? peer = session.peer;
    if (peer == null || !peer.isConnected) {
      throw StateError('电脑离线，暂时不能发送');
    }
    return peer;
  }

  Future<void> _sendText(_ComputerSession session, String text) async {
    final RelayPeer peer = _connectedPeer(session);
    if (text.trim().isEmpty) return;
    if (utf8.encode(text).length > maximumTextBytes) {
      throw StateError('文字超过 128 KB，请改为选择文件发送');
    }
    session.sending = true;
    _publish(immediate: true);
    try {
      await peer.send(<String, Object?>{
        'type': 'clipboard.create',
        'requestId': 'clipboard-${_token()}',
        'content': text,
      });
      _emit(<String, Object?>{'kind': 'sent', 'room': session.record.room});
      _toast('内容已发送到 ${session.record.hostName}');
    } finally {
      session.sending = false;
    }
  }

  Future<void> _sendFile(
    _ComputerSession session,
    File file,
    String name,
    String mime,
  ) async {
    final RelayPeer peer = _connectedPeer(session);
    final int size = await file.length();
    if (size > maximumFileBytes) throw StateError('文件超过 25 MB');
    final String transferId = 'upload-${_token()}';
    session.sending = true;
    _publish(immediate: true);
    try {
      await peer.send(<String, Object?>{
        'type': 'file.start',
        'transferId': transferId,
        'name': name,
        'size': size,
        'mime': mime,
      });
      int index = 0;
      int sent = 0;
      final RandomAccessFile reader = await file.open();
      try {
        while (sent < size) {
          final List<int> chunk = await reader.read(fileChunkBytes);
          if (chunk.isEmpty) break;
          await peer.send(<String, Object?>{
            'type': 'file.chunk',
            'transferId': transferId,
            'index': index,
            'data': base64Encode(chunk),
          });
          index += 1;
          sent += chunk.length;
          _emit(<String, Object?>{
            'kind': 'progress',
            'room': session.record.room,
            'name': name,
            'sent': sent,
            'size': size,
          });
          // Let the socket drain; dart:io has no bufferedAmount.
          await Future<void>.delayed(Duration.zero);
        }
      } finally {
        await reader.close();
      }
      await peer.send(<String, Object?>{
        'type': 'file.end',
        'transferId': transferId,
      });
      _emit(<String, Object?>{'kind': 'sent', 'room': session.record.room});
      _toast('文件已发送到 ${session.record.hostName}');
    } finally {
      session.sending = false;
      _emit(<String, Object?>{'kind': 'progress', 'room': session.record.room});
    }
  }

  Future<void> _requestFile(_ComputerSession session, String itemId) async {
    final RelayPeer peer = _connectedPeer(session);
    session.pendingFileRequests.add(itemId);
    session.fileRequestTimers.remove(itemId)?.cancel();
    session.fileRequestTimers[itemId] = Timer(fileRequestTimeout, () {
      session.fileRequestTimers.remove(itemId);
      if (session.pendingFileRequests.remove(itemId)) {
        _toast('电脑没有发送这个文件，请稍后重试');
        _publish();
      }
    });
    _publish(immediate: true);
    try {
      await peer.send(<String, Object?>{
        'type': 'file.request',
        'itemId': itemId,
      });
    } on Object {
      session.pendingFileRequests.remove(itemId);
      session.fileRequestTimers.remove(itemId)?.cancel();
      rethrow;
    }
  }

  Future<void> _beginDownload(
    _ComputerSession session,
    Map<String, Object?> message,
  ) async {
    final Object? transferId = message['transferId'];
    final Object? size = message['size'];
    if (transferId is! String ||
        size is! int ||
        size < 0 ||
        size > maximumFileBytes) {
      return;
    }
    // A repeated start for the same transfer restarts it, like the desktop.
    final _Download? previous = session.downloads.remove(transferId);
    if (previous != null) await _discard(previous);
    final Object? itemId = message['itemId'];
    if (itemId is String) session.fileRequestTimers.remove(itemId)?.cancel();
    await downloadDirectory.create(recursive: true);
    final String name = _safeName(
      message['name'] is String ? message['name']! as String : '文件',
    );
    final File file = File(
      '${downloadDirectory.path}${Platform.pathSeparator}${_token()}.part',
    );
    session.downloads[transferId] = _Download(
      itemId: message['itemId'] as String?,
      name: name,
      size: size,
      mime: message['mime'] is String
          ? message['mime']! as String
          : 'application/octet-stream',
      file: file,
      sink: file.openWrite(),
    );
  }

  Future<void> _downloadChunk(
    _ComputerSession session,
    Map<String, Object?> message,
  ) async {
    final _Download? download = session.downloads[message['transferId']];
    if (download == null) return;
    final Object? data = message['data'];
    if (message['index'] != download.nextIndex || data is! String) {
      session.downloads.remove(message['transferId']);
      await _discard(download);
      _toast('下载中断，请重试');
      return;
    }
    final List<int> bytes = base64Decode(data);
    if (download.received + bytes.length > download.size) {
      session.downloads.remove(message['transferId']);
      await _discard(download);
      return;
    }
    download.sink.add(bytes);
    download.received += bytes.length;
    download.nextIndex += 1;
  }

  Future<void> _finishDownload(
    _ComputerSession session,
    Map<String, Object?> message,
  ) async {
    final _Download? download = session.downloads.remove(message['transferId']);
    if (download == null) return;
    await download.sink.close();
    session.pendingFileRequests.remove(download.itemId);
    if (download.received != download.size) {
      await download.file.delete();
      _toast('文件不完整，请重新下载');
      return;
    }
    _emit(<String, Object?>{
      'kind': 'downloaded',
      'room': session.record.room,
      'itemId': download.itemId,
      'path': download.file.path,
      'name': download.name,
      'mime': download.mime,
    });
  }

  Future<void> _discard(_Download download) async {
    try {
      await download.sink.close();
      if (await download.file.exists()) await download.file.delete();
    } on Object {
      // Best effort; the cache directory is cleared by the system.
    }
  }

  void _copy(_ComputerSession session, String itemId) {
    for (final ClipboardItem item in session.items) {
      if (item.id == itemId && item.content != null && !item.sensitive) {
        _emit(<String, Object?>{
          'kind': 'copy',
          'itemId': itemId,
          'content': item.content,
        });
        return;
      }
    }
    _toast('内容不可用');
  }

  Future<void> _markSeen(_ComputerSession session, List<String> keys) async {
    if (keys.isEmpty) return;
    final List<AgentEvent> events =
        store.agentEvents[session.record.room] ?? <AgentEvent>[];
    for (int index = 0; index < events.length; index += 1) {
      if (keys.contains(events[index].seenKey)) {
        events[index] = events[index].copyWith(unseen: false);
      }
    }
    await store.save();
    final RelayPeer? peer = session.peer;
    if (peer != null && peer.isConnected) {
      await peer.send(<String, Object?>{
        'type': 'agent.seen',
        'activityIds': keys.take(50).toList(),
      });
    }
  }

  AgentEvent _testEvent(AgentKind kind) => AgentEvent(
    id: 'test-${DateTime.now().microsecondsSinceEpoch}',
    activityId: null,
    kind: kind,
    silent: false,
    title: kind == AgentKind.attention ? 'Agent 需要你处理' : 'Agent 完成啦',
    source: 'DingDong',
    summary: kind == AgentKind.attention
        ? '测试：Agent 正在等待你的确认。'
        : '测试：本轮任务已经完成。',
    detail: '',
    task: '',
    unseen: true,
    startedAt: null,
    completedAt: DateTime.now(),
    workspacePath: null,
  );

  // ---- Snapshots ----

  void _toast(String text) =>
      _emit(<String, Object?>{'kind': 'toast', 'text': text});

  /// Coalesces bursts (a clipboard snapshot is many upserts) into one UI
  /// update.
  void _publish({bool immediate = false}) {
    if (immediate) {
      _snapshotTimer?.cancel();
      _snapshotTimer = null;
      _emit(snapshot());
      _onSummary?.call(_summary());
      return;
    }
    _snapshotTimer ??= Timer(const Duration(milliseconds: 60), () {
      _snapshotTimer = null;
      _emit(snapshot());
      _onSummary?.call(_summary());
    });
  }

  String _summary() {
    final int total = _sessions.length;
    final int online = _sessions.values
        .where((_ComputerSession s) => s.state == LinkState.connected)
        .length;
    if (total == 0) return '未连接电脑';
    if (online == total) {
      return total == 1
          ? '已连接“${_sessions.values.first.record.hostName}”，Agent 提醒实时送达'
          : '已连接 $online 台电脑，Agent 提醒实时送达';
    }
    if (online > 0) return '已连接 $online / $total 台电脑';
    return '等待电脑上线…';
  }

  Map<String, Object?> snapshot() => <String, Object?>{
    'kind': 'snapshot',
    'deviceName': deviceName,
    'activeRoom': store.activeRoom,
    'alerts': store.alertsJson(),
    'computers': <Object?>[
      for (final PairingRecord record in store.pairings)
        if (_sessions[record.room] case final _ComputerSession session)
          <String, Object?>{
            'room': record.room,
            'hostName': record.hostName,
            'hostPlatform': record.hostPlatform,
            'state': session.state.name,
            'manualDisconnect': record.manualDisconnect,
            'agentNotificationsEnabled': record.agentNotificationsEnabled,
            'vibrationEnabled': record.vibrationEnabled,
            'sending': session.sending,
            'lastSyncAt': session.lastSyncAt?.toUtc().toIso8601String(),
            'pendingFiles': session.pendingFileRequests.toList(),
            'items': <Object?>[
              for (final ClipboardItem item in session.items) item.toSnapshot(),
            ],
            'runs': <Object?>[
              for (final AgentRun run in session.runs) run.toJson(),
            ],
            'events': <Object?>[
              for (final AgentEvent event
                  in store.agentEvents[record.room] ?? const <AgentEvent>[])
                event.toJson(),
            ],
          },
    ],
  };

  static final RegExp _platformPattern = RegExp(r'^[a-z0-9-]{1,32}$');

  String _token() => List<String>.generate(
    12,
    (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();

  static String _safeName(String name) {
    final String cleaned = name
        .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
        .trim();
    if (cleaned.isEmpty || cleaned == '.' || cleaned == '..') return '文件';
    return cleaned.length > 120
        ? cleaned.substring(cleaned.length - 120)
        : cleaned;
  }
}
