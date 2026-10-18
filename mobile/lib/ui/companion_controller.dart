import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../link/companion_store.dart';
import '../service/companion_service.dart';

/// Read-only view of one paired computer, rebuilt from service snapshots.
final class ComputerView {
  ComputerView(this.json);

  final Map<String, Object?> json;

  String get room => json['room']! as String;
  String get hostName => json['hostName'] as String? ?? 'DingDong 电脑';
  String get state => json['state'] as String? ?? 'offline';
  bool get connected => state == 'connected';
  bool get connecting => state == 'connecting';
  bool get replaced => state == 'replaced';
  bool get manualDisconnect => json['manualDisconnect'] == true;
  bool get agentNotificationsEnabled =>
      json['agentNotificationsEnabled'] != false;
  bool get vibrationEnabled => json['vibrationEnabled'] != false;
  bool get sending => json['sending'] == true;
  DateTime? get lastSyncAt =>
      DateTime.tryParse(json['lastSyncAt'] as String? ?? '')?.toLocal();
  Set<String> get pendingFiles => <String>{
    for (final Object? id in json['pendingFiles'] as List? ?? const <Object?>[])
      if (id is String) id,
  };
  List<Map<String, Object?>> _list(String key) => <Map<String, Object?>>[
    for (final Object? value in json[key] as List? ?? const <Object?>[])
      if (value is Map) Map<String, Object?>.from(value),
  ];
  List<Map<String, Object?>> get items => _list('items');
  List<Map<String, Object?>> get runs => _list('runs');
  List<Map<String, Object?>> get events => _list('events');
  int get unseenCount =>
      events.where((Map<String, Object?> e) => e['unseen'] != false).length;
}

/// UI-side half of the companion. The service isolate owns all state; this
/// forwards commands and keeps the latest snapshot for the widgets.
final class CompanionController extends ChangeNotifier {
  CompanionController();

  static const MethodChannel native = MethodChannel('dingdong/native');

  bool booting = true;
  String deviceName = '';
  String? activeRoom;
  List<ComputerView> computers = <ComputerView>[];
  String? pendingPairLink;
  ({String name, int sent, int size})? progress;
  bool notificationsGranted = true;
  bool batteryUnrestricted = true;
  bool isXiaomi = false;

  final StreamController<String> _toasts = StreamController<String>.broadcast();
  final StreamController<void> _sent = StreamController<void>.broadcast();
  Stream<String> get toasts => _toasts.stream;
  Stream<void> get sentEvents => _sent.stream;

  final List<Map<String, Object?>> _queued = <Map<String, Object?>>[];
  bool _serviceReady = false;

  ComputerView? get active {
    for (final ComputerView computer in computers) {
      if (computer.room == activeRoom) return computer;
    }
    return computers.isEmpty ? null : computers.first;
  }

  Future<void> start() async {
    FlutterForegroundTask.addTaskDataCallback(_onData);
    initCompanionService();
    native.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'launchText' && call.arguments is String) {
        offerPairLink(call.arguments as String);
      }
    });
    isXiaomi = await native.invokeMethod<bool>('isXiaomi') ?? false;
    deviceName = await native.invokeMethod<String>('deviceName') ?? '';
    await refreshPermissions();
    final String? launch = await native.invokeMethod<String>('takeLaunchText');
    if (await FlutterForegroundTask.isRunningService) {
      // The reply snapshot marks the service ready and flushes the queue.
      FlutterForegroundTask.sendDataToTask(<String, Object?>{
        'cmd': 'snapshot',
      });
    } else if (await CompanionStore.pairingCount(await companionStoreFile()) >
        0) {
      await _ensureService();
    } else {
      booting = false;
      notifyListeners();
    }
    if (launch != null) offerPairLink(launch);
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onData);
    unawaited(_toasts.close());
    unawaited(_sent.close());
    super.dispose();
  }

  Future<void> refreshPermissions() async {
    notificationsGranted =
        await FlutterForegroundTask.checkNotificationPermission() ==
            NotificationPermission.granted &&
        (await native.invokeMethod<bool>('notificationsEnabled') ?? true);
    batteryUnrestricted =
        await native.invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
        true;
    notifyListeners();
  }

  /// Shows the pairing confirmation for a scanned, pasted or opened link.
  void offerPairLink(String text) {
    pendingPairLink = text;
    notifyListeners();
  }

  void cancelPairing() {
    pendingPairLink = null;
    notifyListeners();
  }

  Future<void> confirmPairing(String name) async {
    final String? link = pendingPairLink;
    if (link == null) return;
    pendingPairLink = null;
    if (name.trim().isNotEmpty) deviceName = name.trim();
    notifyListeners();
    await _ensureService();
    send(<String, Object?>{
      'cmd': 'pair',
      'link': link,
      'deviceName': deviceName,
    });
    await enableNotifications();
  }

  Future<void> enableNotifications() async {
    if (await FlutterForegroundTask.checkNotificationPermission() !=
        NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    } else if (!(await native.invokeMethod<bool>('notificationsEnabled') ??
        true)) {
      await native.invokeMethod<bool>('openNotificationSettings');
    }
    await refreshPermissions();
  }

  /// Starts the service if needed. Commands stay queued until its first
  /// snapshot proves the task isolate is listening.
  Future<void> _ensureService() async {
    if (await FlutterForegroundTask.isRunningService) return;
    _serviceReady = false;
    await startCompanionService();
  }

  void send(Map<String, Object?> command) {
    if (!_serviceReady) {
      _queued.add(command);
      return;
    }
    FlutterForegroundTask.sendDataToTask(command);
  }

  void sendForActive(String cmd, [Map<String, Object?> extra = const {}]) {
    final ComputerView? computer = active;
    if (computer == null) return;
    send(<String, Object?>{'cmd': cmd, 'room': computer.room, ...extra});
  }

  void select(String room) {
    activeRoom = room;
    notifyListeners();
    send(<String, Object?>{'cmd': 'select', 'room': room});
  }

  Future<void> copyItem(String itemId) async =>
      sendForActive('copy', <String, Object?>{'itemId': itemId});

  void _onData(Object data) {
    if (data is! Map) return;
    final Map<String, Object?> event = Map<String, Object?>.from(data);
    switch (event['kind']) {
      case 'snapshot':
        _serviceReady = true;
        for (final Map<String, Object?> command in _queued) {
          FlutterForegroundTask.sendDataToTask(command);
        }
        _queued.clear();
        booting = false;
        final String? name = event['deviceName'] as String?;
        if (name != null && name.isNotEmpty) deviceName = name;
        computers = <ComputerView>[
          for (final Object? value
              in event['computers'] as List? ?? const <Object?>[])
            if (value is Map) ComputerView(Map<String, Object?>.from(value)),
        ];
        final String? room = event['activeRoom'] as String?;
        if (computers.every((ComputerView c) => c.room != activeRoom)) {
          activeRoom = room;
        }
        notifyListeners();
      case 'toast':
        _toasts.add(event['text'] as String? ?? '');
      case 'sent':
        _sent.add(null);
      case 'progress':
        progress = event['size'] is int
            ? (
                name: event['name'] as String? ?? '',
                sent: event['sent'] as int? ?? 0,
                size: event['size']! as int,
              )
            : null;
        notifyListeners();
      case 'copy':
        unawaited(
          Clipboard.setData(
            ClipboardData(text: event['content'] as String? ?? ''),
          ),
        );
        _toasts.add('已复制');
      case 'downloaded':
        unawaited(_saveDownload(event));
    }
  }

  Future<void> _saveDownload(Map<String, Object?> event) async {
    try {
      final String? where = await native.invokeMethod<String>(
        'saveToDownloads',
        <String, Object?>{
          'path': event['path'],
          'name': event['name'],
          'mime': event['mime'],
        },
      );
      _toasts.add('已保存到 ${where ?? '下载'}');
    } on PlatformException catch (error) {
      _toasts.add('保存失败：${error.message ?? error.code}');
    }
  }
}
