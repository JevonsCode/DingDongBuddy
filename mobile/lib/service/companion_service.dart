import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
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
      eventAction: ForegroundTaskEventAction.nothing(),
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
    _connectivity = Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      if (results.any((ConnectivityResult r) => r != ConnectivityResult.none)) {
        engine.networkAvailable();
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

  @override
  void onRepeatEvent(DateTime timestamp) {}

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
    await _plugin.show(
      id: event.id.hashCode,
      title: event.notificationTitleFrom(hostName),
      body: event.notificationBody,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          // Channels (sound, vibration, importance) are owned by
          // CompanionChannels.kt; these values only matter if it is missing.
          event.kind.channelId,
          attention ? 'Agent 需要你处理' : 'Agent 完成',
          importance: attention
              ? Importance.high
              : Importance.defaultImportance,
          priority: attention ? Priority.high : Priority.defaultPriority,
          category: attention
              ? AndroidNotificationCategory.reminder
              : AndroidNotificationCategory.status,
          icon: 'ic_notification',
          styleInformation: BigTextStyleInformation(event.notificationBody),
          autoCancel: true,
        ),
      ),
      payload: 'agent',
    );
  }
}
