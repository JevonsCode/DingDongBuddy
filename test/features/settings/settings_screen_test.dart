import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';
import 'package:dingdong/features/settings/domain/sound_preview_gateway.dart';
import 'package:dingdong/features/settings/ui/global_hot_key_recorder.dart';
import 'package:dingdong/features/settings/ui/release_settings_section.dart';
import 'package:dingdong/features/settings/ui/settings_screen.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void testWidgetsOnPlatform(
  String description,
  TargetPlatform platform,
  WidgetTesterCallback callback,
) {
  testWidgets(description, (WidgetTester tester) async {
    debugDefaultTargetPlatformOverride = platform;
    try {
      await callback(tester);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

void main() {
  testWidgets('version destination scrolls directly to release settings', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(620, 560);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final SettingsNavigationController navigation =
        SettingsNavigationController(
          initialDestination: SettingsWindowDestination.version,
        );
    addTearDown(navigation.dispose);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          viewModel: model,
          navigationController: navigation,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Rect releaseBounds = tester.getRect(
      find.byType(ReleaseSettingsSection),
    );
    expect(releaseBounds.top, lessThan(560));
    expect(releaseBounds.bottom, greaterThan(0));
  });

  testWidgets('opening settings immediately checks the latest release', (
    WidgetTester tester,
  ) async {
    final _CountingReleaseSource source = _CountingReleaseSource();
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
      releaseMetadataSource: source,
    );

    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(viewModel: model)),
    );
    await tester.pumpAndSettle();

    expect(source.fetchCount, 1);
    expect(find.text('0.10.0'), findsOneWidget);
  });

  testWidgets('default workspace uses the Dynamic product name', (
    WidgetTester tester,
  ) async {
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
    );
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(viewModel: model)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dynamic'), findsOneWidget);
    expect(find.text('Today'), findsNothing);
  });

  testWidgetsOnPlatform(
    'settings expose appearance, monitoring, retention, and API controls',
    TargetPlatform.macOS,
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 820);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(backend),
      );

      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(viewModel: model)),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('settings-theme-mode')), findsOneWidget);
      expect(find.byKey(const Key('settings-language')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-launch-at-startup')),
        findsOneWidget,
      );
      expect(find.byType(GlobalHotKeyRecorder), findsOneWidget);
      expect(find.byType(WorkspaceShortcutRecorder), findsNWidgets(3));
      expect(find.byKey(const Key('settings-global-hot-key')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-workspace-shortcut-today')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-workspace-shortcut-library')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-workspace-shortcut-clipboard')),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Dynamic workspace shortcut, ⌃ Q'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings-hide-dock-icon')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-anonymous-telemetry')),
        findsNothing,
      );
      expect(find.byKey(const Key('settings-opacity')), findsOneWidget);
      expect(find.byKey(const Key('settings-density')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-default-workspace')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-clipboard-monitoring')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-agent-clipboard-content')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings-retention-items')), findsOneWidget);
      expect(find.byKey(const Key('settings-retention-days')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-agent-activity-remember')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-agent-activity-items')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('settings-agent-activity-hours')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('settings-api-port')), findsOneWidget);
      expect(find.byKey(const Key('settings-sound')), findsOneWidget);
      expect(
        find.byKey(const Key('settings-tray-notification-color')),
        findsOneWidget,
      );
      for (final String color in <String>[
        'orange',
        'pink',
        'blue',
        'green',
        'purple',
      ]) {
        expect(
          find.byKey(Key('settings-tray-notification-color-$color')),
          findsOneWidget,
        );
      }
      expect(find.byKey(const Key('settings-clear-usage')), findsOneWidget);
      expect(find.byKey(const Key('settings-refresh-usage')), findsNothing);

      await tester.tap(find.byKey(const Key('settings-hide-dock-icon')));
      await tester.pumpAndSettle();
      expect(backend.values['dingdong.macos.hideDockIcon'], isTrue);

      await tester.ensureVisible(
        find.byKey(const Key('settings-clipboard-monitoring')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-clipboard-monitoring')));
      await tester.pumpAndSettle();
      expect(backend.values['dingdong.clipboard.monitoring'], isTrue);
      await tester.ensureVisible(
        find.byKey(const Key('settings-agent-clipboard-content')),
      );
      await tester.tap(
        find.byKey(const Key('settings-agent-clipboard-content')),
      );
      await tester.pumpAndSettle();
      expect(backend.values['dingdong.agentApi.allowClipboardContent'], isTrue);

      await tester.ensureVisible(find.text('Dark'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(backend.values['dingdong.panel.themeMode'], 'dark');

      final Finder purple = find.byKey(
        const Key('settings-tray-notification-color-purple'),
      );
      await tester.ensureVisible(purple);
      await tester.pumpAndSettle();
      await tester.tap(purple);
      await tester.pumpAndSettle();
      expect(backend.values['dingdong.macos.trayNotificationColor'], 'purple');
    },
  );

  testWidgetsOnPlatform(
    'global shortcut recorder saves a custom Command shortcut',
    TargetPlatform.macOS,
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 820);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(backend),
      );
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(viewModel: model)),
      );
      await tester.pumpAndSettle();

      final Finder recorder = find.byKey(const Key('settings-global-hot-key'));
      await tester.ensureVisible(recorder);
      await tester.tap(recorder);
      await tester.pump();
      expect(find.text('Press a shortcut…'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pumpAndSettle();

      expect(
        GlobalHotKey.parse(backend.values['dingdong.shortcut.openClipboard']),
        const GlobalHotKey(key: 'K', primary: true, shift: false),
      );
      expect(find.text('⌘K'), findsOneWidget);
    },
  );

  testWidgetsOnPlatform(
    'workspace shortcut recorder persists a custom local shortcut',
    TargetPlatform.macOS,
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 980);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(backend),
      );
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(viewModel: model)),
      );
      await tester.pumpAndSettle();

      final Finder recorder = find.byKey(
        const Key('settings-workspace-shortcut-today'),
      );
      await tester.ensureVisible(recorder);
      await tester.tap(recorder);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyT);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyT);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.text('⌃ T'), findsOneWidget);
      expect(
        WorkspaceShortcuts.parse(
          backend.values['dingdong.shortcut.workspaces'],
          platform: TargetPlatform.macOS,
        ).today,
        const WorkspaceShortcut(key: 'T', secondary: true),
      );
    },
  );

  testWidgetsOnPlatform(
    'workspace shortcut recorder rejects a duplicate shortcut',
    TargetPlatform.macOS,
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1000, 980);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(MemoryPreferencesBackend()),
      );
      await tester.pumpWidget(
        MaterialApp(home: SettingsScreen(viewModel: model)),
      );
      await tester.pumpAndSettle();

      final Finder recorder = find.byKey(
        const Key('settings-workspace-shortcut-today'),
      );
      await tester.ensureVisible(recorder);
      await tester.tap(recorder);
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('settings-workspace-shortcut-today-validation')),
        findsOneWidget,
      );
      expect(find.text('⌃ Q'), findsOneWidget);
    },
  );

  testWidgets('retention fields persist edits without requiring Return', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 820);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend(
      <String, Object>{
        'dingdong.clipboard.maxItems': 1000,
        'dingdong.clipboard.maxAgeDays': 90,
      },
    );
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(backend),
    );
    addTearDown(model.dispose);
    await tester.pumpWidget(
      MaterialApp(home: SettingsScreen(viewModel: model)),
    );
    await tester.pumpAndSettle();

    final Finder itemsField = find.descendant(
      of: find.byKey(const Key('settings-retention-items')),
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(itemsField);
    await tester.enterText(itemsField, '5000');
    await tester.pumpAndSettle();

    final Finder daysField = find.descendant(
      of: find.byKey(const Key('settings-retention-days')),
      matching: find.byType(TextFormField),
    );
    await tester.ensureVisible(daysField);
    await tester.enterText(daysField, '190');
    await tester.pumpAndSettle();

    expect(backend.values['dingdong.clipboard.maxItems'], 5000);
    expect(backend.values['dingdong.clipboard.maxAgeDays'], 190);

    final SettingsViewModel reopened = SettingsViewModel(
      SettingsRepository(backend),
    );
    addTearDown(reopened.dispose);
    await reopened.load();

    expect(reopened.settings.clipboardMaxItems, 5000);
    expect(reopened.settings.clipboardMaxAgeDays, 190);
  });

  testWidgets('sound picker keeps the DingDong family and supports preview', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 820);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
    );
    final _RecordingSoundPreview preview = _RecordingSoundPreview();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(viewModel: model, soundPreviewGateway: preview),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const Key('settings-sound')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-sound')));
    await tester.pumpAndSettle();

    expect(find.text('DingDong Classic'), findsWidgets);
    expect(find.text('DingDong Soft'), findsOneWidget);
    expect(find.text('DingDong Bright'), findsOneWidget);
    expect(find.text('DingDong Crisp'), findsOneWidget);
    expect(find.text('DingDong Wood'), findsNothing);
    expect(find.text('DingDong Deep'), findsOneWidget);
    expect(find.text('Joy'), findsNothing);
    expect(find.text('Candy'), findsNothing);

    await tester.tap(find.text('DingDong Crisp'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-preview-sound')));
    await tester.pump();

    expect(preview.sounds, <String>['dingCrisp']);
  });

  testWidgets('changed local port reveals an adjacent restart action', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1000, 820);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final SettingsViewModel model = SettingsViewModel(
      SettingsRepository(MemoryPreferencesBackend()),
    );
    int restartCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsScreen(
          viewModel: model,
          onRestartApplication: () async => restartCount += 1,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings-restart')), findsNothing);

    await model.setApiPort(2444);
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('settings-restart')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('settings-restart')));
    await tester.pump();

    expect(restartCount, 1);
  });
}

final class _RecordingSoundPreview implements SoundPreviewGateway {
  final List<String> sounds = <String>[];

  @override
  Future<void> preview({required String sound, String? customSoundPath}) async {
    sounds.add(sound);
  }
}

final class _CountingReleaseSource implements ReleaseMetadataSource {
  int fetchCount = 0;

  @override
  Future<ReleaseMetadata> fetch() async {
    fetchCount += 1;
    return ReleaseMetadata(
      app: 'DingDong',
      latestVersion: '0.10.0',
      website: Uri.parse('https://example.com'),
      releasePage: Uri.parse('https://example.com/releases/0.10.0'),
    );
  }
}
