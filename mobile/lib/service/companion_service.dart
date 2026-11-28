import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show setEquals;
import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';

import '../link/agent_event.dart';
import '../link/companion_engine.dart';
import '../link/companion_store.dart';

const String _serviceIconMetaData = 'com.dingdongbuddy.companion.SERVICE_ICON';

Future<File> companionStoreFile() async =>
    File('${(await getApplicationSupportDirectory()).path}/companion.json');

/// Shared by the UI (to start the service) and boot restarts, which reuse the
/// options the plugin persisted on the last start.
void initCompanionService() {
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      // Created natively in CompanionChannels.kt with importance MIN.
      channelId: 'relay_connection_v1',
      channelName: '连接状态',
      channelImportance: NotificationChannelImportance.MIN,
      priority: NotificationPriority.MIN,
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      // A one-minute watchdog: Android may hold the reconnect timer while
      // the CPU sleeps, and the tick reconnects a peer whose retry is late.
      eventAction: ForegroundTaskEventAction.repeat(60 * 1000),
      autoRunOnBoot: true,
      autoRunOnMyPackageReplaced: true,
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );
}

Future<void> startCompanionService() async {
  if (await FlutterForegroundTask.isRunningService) return;
  await FlutterForegroundTask.startService(
    serviceId: 7,
    serviceTypes: <ForegroundServiceTypes>[ForegroundServiceTypes.specialUse],
    notificationTitle: 'DingDong',
    notificationText: '正在连接电脑…',
    notificationIcon: const NotificationIcon(
      metaDataName: _serviceIconMetaData,
    ),
    callback: companionServiceEntryPoint,
  );
}

@pragma('vm:entry-point')
void companionServiceEntryPoint() {
  FlutterForegroundTask.setTaskHandler(CompanionTaskHandler());
}

/// Runs in the foreground service's own isolate and engine, so reminders keep
/// arriving after the UI is closed.
final class CompanionTaskHandler extends TaskHandler {
  CompanionEngine? _engine;
  StreamSubscription<List<ConnectivityResult>>? _connectivity;
  String? _summary;
  final List<Object> _early = <Object>[];

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    final CompanionStore store = await CompanionStore.load(
      await companionStoreFile(),
    );
    final _LocalAgentNotifier notifier = _LocalAgentNotifier();
    await notifier.initialize();
    final CompanionEngine engine = CompanionEngine(
      store: store,
      notifier: notifier,
      downloadDirectory: Directory(
        '${(await getTemporaryDirectory()).path}/downloads',
      ),
      emit: FlutterForegroundTask.sendDataToMain,
      onSummary: _updateSummary,
      onEmpty: () => unawaited(FlutterForegroundTask.stopService()),
    );
    _engine = engine;
    engine.start();
    Set<ConnectivityResult>? previous;
    _connectivity = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      final Set<ConnectivityResult> current = results
          .where((ConnectivityResult r) => r != ConnectivityResult.none)
          .toSet();
      final Set<ConnectivityResult>? before = previous;
      previous = current;
      if (current.isEmpty) return;
      if (before == null || before.isEmpty) {
        engine.networkAvailable();
      } else if (!setEquals(before, current)) {
        // Wi-Fi ↔ mobile data: the old socket's route is gone.
        engine.networkChanged();
      }
    });
    for (final Object data in _early) {
      onReceiveData(data);
    }
    _early.clear();
  }

  void _updateSummary(String summary) {
    if (summary == _summary) return;
    _summary = summary;
    unawaited(
      FlutterForegroundTask.updateService(
        notificationTitle: 'DingDong',
        notificationText: summary,
      ),
    );
  }

  int _ticks = 0;

  @override
  void onRepeatEvent(DateTime timestamp) {
    _ticks += 1;
    // Sparse evidence of whether Android lets the watchdog run.
    if (_ticks % 5 == 1) {
      debugPrint('DingDongWatchdog tick $_ticks at $timestamp');
    }
    _engine?.tick();
  }

  @override
  void onReceiveData(Object data) {
    final CompanionEngine? engine = _engine;
    if (engine == null) {
      // Commands sent while onStart is still loading the store.
      _early.add(data);
      return;
    }
    if (data is Map) {
      unawaited(engine.handleCommand(Map<String, Object?>.from(data)));
    }
  }

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _connectivity?.cancel();
    await _engine?.dispose();
  }
}

final class _LocalAgentNotifier implements AgentNotifier {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
      ),
    );
  }

  @override
  Future<void> show(AgentEvent event, {required String hostName}) async {
    final bool attention = event.needsAttention;
    // A reminder that arrives long after it was sent is shown, labelled with
    // its delay, on a quiet channel instead of ringing as if it were new.
    final bool late = event.isLate;
    final String channelId = late ? lateChannelId : event.kind.channelId;
    final String title = event.notificationTitleFrom(hostName);
    final String body = late
        ? '延迟 ${AgentEvent.formatDelay(event.deliveryDelay!)} · ${event.notificationBody}'
        : event.notificationBody;
    final DateTime? completedAt = event.completedAt;
    await _plugin.show(
      id: event.id.hashCode,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          // Channels (sound, vibration, importance) are owned by
          // CompanionChannels.kt; these values only matter if it is missing.
          channelId,
          late
              ? '延迟送达的提醒'
              : attention
              ? 'Agent 需要你处理'
              : 'Agent 完成',
          importance: late
              ? Importance.low
              : attention
              ? Importance.high
              : Importance.defaultImportance,
          priority: late
              ? Priority.low
              : attention
              ? Priority.high
              : Priority.defaultPriority,
          category: attention
              ? AndroidNotificationCategory.reminder
              : AndroidNotificationCategory.status,
          icon: 'ic_notification',
          // Expanded, the notification shows the Agent's whole message.
          styleInformation: BigTextStyleInformation(
            event.notificationDetail(),
            contentTitle: title,
            summaryText: attention ? '需要你处理' : '已完成',
          ),
          when: completedAt?.millisecondsSinceEpoch,
          showWhen: completedAt != null,
          autoCancel: true,
        ),
      ),
      payload: 'agent',
    );
    final Duration? delay = event.deliveryDelay;
    debugPrint(
      'DingDongAgent posted id=${event.id} kind=${event.kind.name} '
      'channel=$channelId late=$late '
      'sentAt=${event.sentAt?.toIso8601String()} '
      'receivedAt=${event.receivedAt?.toIso8601String()} '
      'postedAt=${DateTime.now().toUtc().toIso8601String()} '
      'delayMs=${delay?.inMilliseconds}',
    );
  }

  @override
  Future<void> showMissed(
    List<AgentEvent> events, {
    required String hostName,
  }) async {
    if (events.isEmpty) return;
    final int attention = events
        .where((AgentEvent e) => e.needsAttention)
        .length;
    final String title = attention > 0
        ? '离线期间有 $attention 条需要你处理 · $hostName'
        : '离线期间有 ${events.length} 条 Agent 完成 · $hostName';
    final String lines = <String>[
      for (final AgentEvent event in events.take(8))
        '${event.needsAttention ? '需要你处理' : '已完成'} · ${event.source.isEmpty ? 'Agent' : event.source}'
            ' · ${event.timingLine()}\n${event.notificationBody}',
      if (events.length > 8) '还有 ${events.length - 8} 条，打开 DingDong 查看',
    ].join('\n\n');
    await _plugin.show(
      id: 'missed:$hostName'.hashCode,
      title: title,
      body: events.first.notificationBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          lateChannelId,
          '延迟送达的提醒',
          importance: Importance.low,
          priority: Priority.low,
          icon: 'ic_notification',
          styleInformation: BigTextStyleInformation(
            lines,
            contentTitle: title,
            summaryText: '连接恢复后补发',
          ),
          autoCancel: true,
        ),
      ),
      payload: 'agent',
    );
    debugPrint(
      'DingDongAgent missed host=$hostName count=${events.length} '
      'ids=${events.map((AgentEvent e) => e.id).join(',')} '
      'postedAt=${DateTime.now().toUtc().toIso8601String()}',
    );
  }
}

/// Quiet channel for reminders that arrived late or were missed offline;
/// created in CompanionChannels.kt.
const String lateChannelId = 'agent_late_v1';
