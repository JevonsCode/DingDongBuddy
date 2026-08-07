import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/system_usage.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:dingdong/features/settings/ui/system_usage_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'clipboard usage is detailed and each history type clears independently',
    (WidgetTester tester) async {
      final _UsageSource source = _UsageSource();
      final _Cleaner cleaner = _Cleaner(source);
      final SettingsViewModel model = SettingsViewModel(
        SettingsRepository(MemoryPreferencesBackend()),
        systemUsageSource: source,
        systemDataCleaner: cleaner,
      );
      addTearDown(model.dispose);
      await model.load();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SystemUsageSection(viewModel: model),
            ),
          ),
        ),
      );

      expect(find.text('Clipboard history'), findsOneWidget);
      expect(find.text('Image cache'), findsOneWidget);
      expect(find.text('Text history'), findsOneWidget);
      expect(find.text('File history'), findsOneWidget);
      expect(find.text('Permanent archives'), findsOneWidget);
      expect(find.text('Resource library'), findsOneWidget);
      expect(find.text('Agent activity'), findsOneWidget);
      expect(find.text('Adapter version history'), findsOneWidget);
      expect(find.text('Application configuration'), findsOneWidget);
      expect(
        find.byKey(const Key('settings-clear-clipboard-archive')),
        findsNothing,
      );
      expect(
        find.byKey(const Key('settings-clear-resource-library')),
        findsNothing,
      );

      final Finder clearButton = find.byKey(
        const Key('settings-clear-clipboard-images'),
      );
      expect(tester.widget<FilledButton>(clearButton).onPressed, isNotNull);

      await tester.tap(clearButton);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('settings-clear-usage-dialog')),
        findsOneWidget,
      );
      expect(
        find.text(
          'Permanent archives and their image files are protected and will stay intact.',
        ),
        findsOneWidget,
      );
      expect(cleaner.categories, isEmpty);

      await tester.tap(find.byKey(const Key('settings-clear-usage-cancel')));
      await tester.pumpAndSettle();
      expect(cleaner.categories, isEmpty);

      await tester.tap(clearButton);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('settings-clear-usage-confirm')));
      await tester.pumpAndSettle();

      expect(cleaner.categories, <SystemDataCategory>{
        SystemDataCategory.clipboardImages,
      });
      expect(source.loadCount, 2);
      expect(
        model.systemUsage?.bytesFor(SystemDataCategory.clipboardImages),
        0,
      );
    },
  );
}

final class _UsageSource implements SystemUsageSource {
  int loadCount = 0;
  bool imagesCleared = false;

  @override
  Future<SystemUsageSnapshot> load() async {
    loadCount += 1;
    final int imageBytes = imagesCleared ? 0 : 8 * 1024 * 1024;
    return SystemUsageSnapshot(
      residentMemoryBytes: 64 * 1024 * 1024,
      storageBytes: imageBytes + 5 * 1024 * 1024,
      storageByCategory: <SystemDataCategory, int>{
        SystemDataCategory.clipboardImages: imageBytes,
        SystemDataCategory.clipboardText: 2 * 1024 * 1024,
        SystemDataCategory.clipboardFiles: 128 * 1024,
        SystemDataCategory.clipboardArchive: 4 * 1024 * 1024,
        SystemDataCategory.resourceLibrary: 2 * 1024 * 1024,
        SystemDataCategory.agentActivity: 512 * 1024,
        SystemDataCategory.adapterHistory: 256 * 1024,
        SystemDataCategory.configuration: 256 * 1024,
      },
      itemCountByCategory: const <SystemDataCategory, int>{
        SystemDataCategory.clipboardImages: 8,
        SystemDataCategory.clipboardText: 20,
        SystemDataCategory.clipboardFiles: 2,
        SystemDataCategory.clipboardArchive: 5,
      },
    );
  }
}

final class _Cleaner implements SystemDataCleaner {
  _Cleaner(this.source);

  final _UsageSource source;
  Set<SystemDataCategory> categories = const <SystemDataCategory>{};

  @override
  Future<void> clear(Set<SystemDataCategory> categories) async {
    this.categories = Set<SystemDataCategory>.of(categories);
    source.imagesCleared = categories.contains(
      SystemDataCategory.clipboardImages,
    );
  }
}
