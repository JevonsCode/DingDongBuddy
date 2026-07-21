import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/library/ui/resource_manager_app.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('resource manager paints its localized first frame', (
    WidgetTester tester,
  ) async {
    const MethodChannel channels = MethodChannel(
      'mixin.one/desktop_multi_window/channels',
    );
    final TestDefaultBinaryMessenger messenger =
        tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channels, (_) async => null);
    addTearDown(() {
      messenger.setMockMethodCallHandler(channels, null);
    });

    final LibraryViewModel library = LibraryViewModel(InMemoryResourceStore());
    await library.load();
    final ClipboardViewModel clipboard = ClipboardViewModel(
      InMemoryClipboardStore(),
    )..load();
    final ActivityController activity = ActivityController(
      idGenerator: () => 'manager-agent',
      now: () => DateTime.utc(2026, 7, 21, 10),
    )..record(source: 'Codex', message: 'Read-only result');

    await tester.pumpWidget(
      ResourceManagerApp(
        viewModel: library,
        clipboardViewModel: clipboard,
        activityController: activity,
        settings: const AppSettings(language: AppLanguagePreference.chinese),
        windowController: WindowController.fromWindowId(
          'resource-manager-test',
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const Key('resource-manager-navigation')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-manager-nav-resources')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-manager-nav-clipboard')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('resource-manager-nav-agent-activity')),
      findsOneWidget,
    );
    expect(find.text('资源'), findsWidgets);
    expect(find.text('剪贴板'), findsOneWidget);

    await tester.tap(find.byKey(const Key('resource-manager-nav-clipboard')));
    await tester.pump();
    expect(find.byKey(const Key('clipboard-manager-search')), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('resource-manager-nav-agent-activity')),
    );
    await tester.pump();
    expect(
      find.byKey(const Key('agent-activity-manager-list')),
      findsOneWidget,
    );
    expect(find.text('Read-only result'), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);

    await tester.tap(find.byKey(const Key('resource-manager-nav-resources')));
    await tester.pump();
    expect(find.byKey(const Key('resource-search')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    activity.dispose();
  });
}
