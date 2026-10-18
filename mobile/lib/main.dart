import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'ui/companion_controller.dart';
import 'ui/home_screen.dart';
import 'ui/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Port between this UI isolate and the service isolate that owns sockets.
  FlutterForegroundTask.initCommunicationPort();
  final GlobalKey<HomeScreenState> home = GlobalKey<HomeScreenState>();
  final FlutterLocalNotificationsPlugin notifications =
      FlutterLocalNotificationsPlugin();
  await notifications.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('ic_notification'),
    ),
    // Tapping an Agent reminder while the app is open shows the Agent tab.
    onDidReceiveNotificationResponse: (NotificationResponse response) {
      if (response.payload == 'agent') home.currentState?.showAgentTab();
    },
  );
  final NotificationAppLaunchDetails? launch = await notifications
      .getNotificationAppLaunchDetails();
  final bool openedFromReminder =
      launch?.didNotificationLaunchApp == true &&
      launch?.notificationResponse?.payload == 'agent';
  final CompanionController controller = CompanionController();
  unawaited(controller.start());
  runApp(
    DingDongApp(
      controller: controller,
      home: home,
      initialTab: openedFromReminder ? 1 : 0,
    ),
  );
}

class DingDongApp extends StatelessWidget {
  const DingDongApp({
    super.key,
    required this.controller,
    required this.home,
    this.initialTab = 0,
  });

  final CompanionController controller;
  final GlobalKey<HomeScreenState> home;
  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DingDong',
      debugShowCheckedModeBanner: false,
      theme: dingTheme(Brightness.light),
      darkTheme: dingTheme(Brightness.dark),
      // WithForegroundTask keeps the service alive when the user leaves via
      // the back button instead of minimising.
      home: WithForegroundTask(
        child: HomeScreen(
          key: home,
          controller: controller,
          initialTab: initialTab,
        ),
      ),
    );
  }
}
