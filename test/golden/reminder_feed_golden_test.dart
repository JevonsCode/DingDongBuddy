@Tags(['golden'])
library;

import 'dart:convert';
import 'dart:io';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/widgets/desktop_date_range_picker.dart';
import 'package:dingdong/features/activity/data/agent_activity_store.dart';
import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/activity/ui/agent_activity_manager_screen.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';
import 'package:dingdong/features/settings/domain/tray_reminder_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUpAll(() async {
    final config =
        jsonDecode(await File('.dart_tool/package_config.json').readAsString())
            as Map;
    final sdk = Uri.parse('${config['flutterRoot']}/');
    for (final family in ['Roboto', '.AppleSystemUIFont', 'Segoe UI']) {
      final font = FontLoader(family);
      for (final face in [
        'Roboto-Regular.ttf',
        'Roboto-Medium.ttf',
        'Roboto-Bold.ttf',
      ]) {
        font.addFont(
          File.fromUri(
            sdk.resolve('bin/cache/artifacts/material_fonts/$face'),
          ).readAsBytes().then(ByteData.sublistView),
        );
      }
      await font.load();
    }
    await (FontLoader('MaterialIcons')..addFont(
          File.fromUri(
            sdk.resolve(
              'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
            ),
          ).readAsBytes().then(ByteData.sublistView),
        ))
        .load();
  });
  for (final dark in [false, true]) {
    testWidgets('reminder borders and desktop feed ${dark ? 'dark' : 'light'}', (
      tester,
    ) async {
      // Synthetic fixtures for visual review; these are not user notifications.
      final now = DateTime(2026, 10, 27, 12);
      final profiles = [
        const ReminderProfile(
          id: 'completion',
          name: 'Complete',
          color: TrayNotificationColor.purple,
        ),
        const ReminderProfile(
          id: 'next-review',
          name: 'Review request',
          description: 'Ask for the remaining review input.',
          temporary: true,
          color: TrayNotificationColor.green,
          sound: 'dingDeep',
        ),
        const ReminderProfile(
          id: 'attention',
          name: 'Needs input',
          color: TrayNotificationColor.pink,
        ),
      ];
      final controller = ActivityController(
        store: InMemoryAgentActivityStore(
          AgentActivityHistory(
            activities: [
              for (var i = 0; i < 32; i++)
                AgentActivity(
                  id: 'fixture-$i',
                  source: i.isEven ? 'Codex' : 'Claude Code',
                  message: i % 3 == 1
                      ? 'Please review the remaining details.'
                      : 'The requested changes are ready.',
                  completedAt: now.subtract(Duration(minutes: i * 7)),
                  unseen: false,
                  repeatCount: i == 0 ? 54 : i % 3 + 1,
                  reminder: profiles[i % 3],
                  pinned: i == 0,
                ),
            ],
          ),
        ),
        now: () => now,
      )..load();
      addTearDown(controller.dispose);
      final launcher = _Launcher();
      addTearDown(launcher.dispose);
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1120, 720);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark
              ? AppTheme.desktopPanelDark()
              : AppTheme.desktopPanelLight(),
          localizationsDelegates: DingDongLocalizations.localizationsDelegates,
          supportedLocales: DingDongLocalizations.supportedLocales,
          home: Scaffold(
            body: AgentActivityManagerScreen(
              controller: controller,
              conversationLauncher: launcher,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/agent_feed_manager_${dark ? 'dark' : 'light'}.png',
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark
              ? AppTheme.desktopPanelDark()
              : AppTheme.desktopPanelLight(),
          localizationsDelegates: DingDongLocalizations.localizationsDelegates,
          supportedLocales: DingDongLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDesktopDateRangePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: now,
                  initialRange: DateTimeRange(
                    start: DateTime(2026, 9, 20),
                    end: DateTime(2026, 10, 9),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          'goldens/desktop_date_range_${dark ? 'dark' : 'light'}.png',
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      controller.clear();
    });
  }
}

final class _Launcher extends ChangeNotifier
    implements AgentConversationLauncher {
  @override
  bool canOpen(AgentConversationTarget target) => false;
  @override
  bool isSubagent(AgentConversationTarget target) => false;
  @override
  Future<void> open(AgentConversationTarget target) async {}
}
