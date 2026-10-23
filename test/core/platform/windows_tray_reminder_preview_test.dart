import 'dart:io';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/windows_tray_reminder_preview.dart';
import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';
import 'package:dingdong/features/settings/domain/tray_reminder_style.dart';
import 'package:dingdong/platform/plugin_desktop_shell_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tray_manager/tray_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final strings = lookupDingDongLocalizations(const Locale('zh'));
  const profiles = [
    ReminderProfile(id: 'attention', name: 'attention'),
    ReminderProfile(id: 'completion', name: 'completion'),
    ReminderProfile(
      id: 'review',
      name: '代码审查',
      color: TrayNotificationColor.blue,
    ),
  ];

  test(
    'Windows color previews preserve real attention counts when cleared',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final calls = <MethodCall>[];
      const channel = MethodChannel('tray_manager');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final gateway = PluginDesktopShellGateway(developmentBuild: true);
      await gateway.previewReminderColor(TrayNotificationColor.blue);
      final icon =
          calls.lastWhere((c) => c.method == 'setIcon').arguments
              as Map<Object?, Object?>;
      expect(icon['badgeColorRgb'], TrayNotificationColor.blue.rgbValue);
      expect(icon['iconPath'], endsWith('tray_icon_adaptive_unread.ico'));
      expect(calls.lastWhere((c) => c.method == 'setToolTip').arguments, {
        'toolTip': '',
      });
      await gateway.markUnread(kind: AgentNotificationKind.attention);
      final mixed =
          calls.lastWhere((c) => c.method == 'setReminderPreview').arguments
              as Map<Object?, Object?>;
      expect(mixed['totalCount'], 2);
      await gateway.previewReminderColor(null);
      final cleared =
          calls.lastWhere((c) => c.method == 'setReminderPreview').arguments
              as Map<Object?, Object?>;
      expect(cleared['totalCount'], 1);
      expect(cleared['rows'], hasLength(1));
    },
    skip: !Platform.isWindows,
  );

  test(
    'hover snapshot shows exact mixed counts and preserves unknown history',
    () {
      final preview = WindowsTrayReminderPreview(
        unreadCount: 8,
        needsInput: true,
        strings: strings,
        profiles: profiles,
        counts: {'attention': 3, 'completion': 2, 'review': null},
      );
      expect(preview.title, '轮到你啦');
      expect(preview.totalCount, 8);
      expect(preview.rows.map((r) => r['name']), ['等待你的确认', '统一完成提醒', '代码审查']);
      expect(preview.rows.map((r) => r['count']), [3, 2, null]);
      expect(
        preview.rows.last['colorRgb'],
        TrayNotificationColor.blue.rgbValue,
      );
      expect(preview.rows.last.containsKey('count'), isFalse);
      expect(preview.tooltip(strings), contains('代码审查 · ?'));
      expect(preview.tooltip(strings), startsWith('DingDong · 8 条未读内容'));
    },
  );

  test(
    'zero and large counts stay bounded, with localized completion state',
    () {
      for (final locale in ['en', 'es', 'zh']) {
        final localized = lookupDingDongLocalizations(Locale(locale));
        final preview = WindowsTrayReminderPreview(
          unreadCount: 1005,
          needsInput: false,
          strings: localized,
          profiles: profiles,
          counts: {'attention': 1005, 'completion': -1},
        );
        expect(preview.totalCount, 999);
        expect(preview.rows.first['count'], 999);
        expect(preview.rows[1]['count'], 0);
        expect(preview.title, localized.trayBuddyReady);
      }
      final empty = WindowsTrayReminderPreview(
        unreadCount: -1,
        needsInput: false,
        strings: strings,
        profiles: const [],
        counts: const {},
      );
      expect(empty.totalCount, 0);
      expect(empty.tooltip(strings), 'DingDong');
    },
  );

  test(
    'long Unicode names cannot displace total or overflow native tooltip',
    () {
      final preview = WindowsTrayReminderPreview(
        unreadCount: 5,
        needsInput: true,
        strings: strings,
        profiles: [
          for (var i = 0; i < 6; i++)
            ReminderProfile(id: '$i', name: '审查 🐥' * 12),
        ],
        counts: const {},
      );
      final tooltip = preview.tooltip(strings);
      expect(tooltip.length, lessThan(128));
      expect(tooltip, startsWith('DingDong · 5'));
      expect(preview.rows, hasLength(6));
    },
  );

  test(
    'Windows bridge sends clear and unknown-count snapshots without reads',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      final calls = <MethodCall>[];
      const channel = MethodChannel('tray_manager');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call);
            return true;
          });
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      await trayManager.setReminderPreview(
        title: '轮到你啦',
        subtitle: '条提醒待查看',
        footer: '点击打开 DingDong',
        totalCount: 8,
        rows: const [
          {'name': '历史提醒', 'colorRgb': 0x112233},
        ],
      );
      await trayManager.setReminderPreview(
        title: '',
        subtitle: '',
        footer: '',
        totalCount: 0,
      );
      expect(calls.map((c) => c.method), [
        'setReminderPreview',
        'setReminderPreview',
      ]);
      final first = calls.first.arguments as Map<Object?, Object?>;
      final last = calls.last.arguments as Map<Object?, Object?>;
      expect(first['rows'], [
        {'name': '历史提醒', 'colorRgb': 0x112233},
      ]);
      expect(last['totalCount'], 0);
      expect(last['rows'], isEmpty);
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      await trayManager.setReminderPreview(
        title: '',
        subtitle: '',
        footer: '',
        totalCount: 1,
      );
      expect(calls, hasLength(2));
    },
  );
}
