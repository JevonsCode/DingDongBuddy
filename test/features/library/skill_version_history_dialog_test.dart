import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/skill_version.dart';
import 'package:dingdong/features/library/ui/library_screen.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/library/ui/skill_version_history_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _screenshots = String.fromEnvironment('SKILL_HISTORY_SCREENSHOTS');

List<SkillVersion> _versions() => <SkillVersion>[
  for (int i = 1; i <= 3; i++)
    SkillVersion(
      number: i,
      createdAt: DateTime.utc(2026, 10, 23, 8, i * 5),
      source: i == 1
          ? SkillVersionSource.initial
          : i == 2
          ? SkillVersionSource.online
          : SkillVersionSource.manual,
      snapshotId: '$i',
    ),
];

SkillSnapshot _snapshot(String id) => SkillSnapshot(
  title: 'Code review',
  document: switch (id) {
    '1' =>
      '---\nname: code-review\n---\n\nReview the changed files.\nSkip generated files.\n',
    '2' =>
      '---\nname: code-review\n---\n\nReview the changed files.\nCheck error handling.\n',
    _ =>
      '---\nname: code-review\n---\n\nReview the changed files.\nCheck error handling and recovery.\nReport actionable findings with file paths.\n',
  },
  sourceUrl: 'https://github.com/example/skills/tree/main/code-review',
  files: <String, SkillVersionFile>{
    'scripts/check.sh': SkillVersionFile.text('echo $id\n'),
  },
  hasPackage: true,
);

Future<void> _open(
  WidgetTester tester, {
  Future<List<SkillVersion>> Function()? load,
  Future<SkillSnapshot> Function(String)? snapshot,
  Future<void> Function(int)? restore,
  Size size = const Size(1180, 820),
  bool dark = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  await tester.pumpWidget(
    RepaintBoundary(
      key: const Key('capture-history'),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark
            ? AppTheme.desktopPanelDark()
            : AppTheme.desktopPanelLight(),
        home: Scaffold(
          body: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () => showDialog<bool>(
                context: context,
                barrierDismissible: false,
                builder: (_) => SkillVersionHistoryDialog(
                  title: 'Code review',
                  loadVersions: load ?? () async => _versions(),
                  loadSnapshot: snapshot ?? (String id) async => _snapshot(id),
                  onRestore: restore ?? (_) async {},
                ),
              ),
              child: const Text('Open history'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open history'));
  await tester.pump();
}

void main() {
  testWidgets('Skill detail history action restores and refreshes the editor', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1180, 820);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final _VersionedStore store = _VersionedStore();
    final LibraryViewModel model = LibraryViewModel(store);
    addTearDown(model.dispose);
    await model.load();
    model.selectResource(model.allResources.single);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: LibraryScreen(viewModel: model)),
      ),
    );
    await tester.tap(find.byKey(const Key('skill-version-history')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('skill-version-row-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('skill-version-restore')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();
    expect(model.selectedResource!.content, _snapshot('1').document);
    expect(find.byKey(const Key('skill-version-history-dialog')), findsNothing);
    expect(find.byKey(const Key('resource-editor')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'comparison failure is actionable and retry keeps selected endpoints',
    (tester) async {
      var fail = true;
      await _open(
        tester,
        snapshot: (String id) async {
          if (fail) throw StateError('snapshot missing');
          return _snapshot(id);
        },
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('snapshot missing'), findsOneWidget);
      fail = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.textContaining('snapshot missing'), findsNothing);
      expect(
        find.text('Report actionable findings with file paths.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'defaults to latest pair and selects any two nonadjacent versions',
    (tester) async {
      await _open(tester);
      await tester.pumpAndSettle();
      expect(
        find.text('Report actionable findings with file paths.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('skill-version-from')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('v1').last);
      await tester.pumpAndSettle();
      expect(find.text('Skip generated files.'), findsOneWidget);
      expect(
        find.text('Report actionable findings with file paths.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('skill-version-to')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('v1').last);
      await tester.pumpAndSettle();
      expect(
        find.text('No differences between these versions.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('restoration confirms the chosen version and closes on success', (
    tester,
  ) async {
    int? restored;
    await _open(tester, restore: (int version) async => restored = version);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('skill-version-row-1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('skill-version-restore')));
    await tester.pumpAndSettle();
    expect(find.text('Restore v1?'), findsOneWidget);
    expect(restored, isNull);
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();
    expect(restored, 1);
    expect(find.byKey(const Key('skill-version-history-dialog')), findsNothing);
  });

  testWidgets('failed restoration keeps history open and can retry', (
    tester,
  ) async {
    var fail = true;
    await _open(
      tester,
      restore: (_) async {
        if (fail) throw StateError('disk unavailable');
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('skill-version-restore')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Restore').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('disk unavailable'), findsOneWidget);
    expect(
      find.byKey(const Key('skill-version-history-dialog')),
      findsOneWidget,
    );
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.textContaining('disk unavailable'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'single version previews content in narrow window without overflow',
    (tester) async {
      await _open(
        tester,
        size: const Size(390, 760),
        load: () async => <SkillVersion>[_versions().first],
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Only one saved version. Its content is shown below.'),
        findsOneWidget,
      );
      expect(find.textContaining('Skip generated files.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('loading, failure, retry and empty history are recoverable', (
    tester,
  ) async {
    final Completer<List<SkillVersion>> pending =
        Completer<List<SkillVersion>>();
    var calls = 0;
    await _open(
      tester,
      load: () {
        calls++;
        return calls == 1 ? pending.future : Future.value(<SkillVersion>[]);
      },
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(StateError('history unavailable'));
    await tester.pumpAndSettle();
    expect(find.textContaining('history unavailable'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No saved versions yet.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final (String name, Size size, bool dark) entry
      in <(String, Size, bool)>[
        ('desktop', const Size(1180, 820), false),
        ('narrow', const Size(430, 860), false),
        ('dark', const Size(1180, 820), true),
      ]) {
    testWidgets('render history ${entry.$1}', (tester) async {
      await tester.runAsync(() async {
        for (final (String family, String file) font in <(String, String)>[
          ('Segoe UI', 'C:/Windows/Fonts/segoeui.ttf'),
          ('monospace', 'C:/Windows/Fonts/consola.ttf'),
          (
            'MaterialIcons',
            'T:/workspace/dingdong/.tooling/flutter-sdk-3.44.7/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
          ),
        ]) {
          final FontLoader loader = FontLoader(font.$1)
            ..addFont(
              Future.value(
                ByteData.sublistView(await File(font.$2).readAsBytes()),
              ),
            );
          await loader.load();
        }
      });
      await _open(tester, size: entry.$2, dark: entry.$3);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final RenderRepaintBoundary boundary = tester.renderObject(
        find.byKey(const Key('capture-history')),
      );
      await tester.runAsync(() async {
        final ui.Image pixels = await boundary.toImage();
        final ByteData data = (await pixels.toByteData(
          format: ui.ImageByteFormat.png,
        ))!;
        await Directory(_screenshots).create(recursive: true);
        await File(
          '$_screenshots/skill-history-${entry.$1}.png',
        ).writeAsBytes(data.buffer.asUint8List());
        pixels.dispose();
      });
    }, skip: _screenshots.isEmpty);
  }
}

final class _VersionedStore implements ResourceStore, SkillVersionStore {
  Resource resource = Resource(
    id: 'review',
    type: ResourceType.skill,
    title: 'Code review',
    content: _snapshot('3').document,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );
  @override
  Future<List<Resource>> load() async => <Resource>[resource];
  @override
  Future<void> save(List<Resource> resources) async =>
      resource = resources.single;
  @override
  Future<List<SkillVersion>> loadSkillVersions(String resourceId) async =>
      _versions();
  @override
  Future<SkillSnapshot> loadSkillSnapshot(String snapshotId) async =>
      _snapshot(snapshotId);
  @override
  Future<void> restoreSkillVersion(String resourceId, int version) async {
    resource = resource.copyWith(content: _snapshot('$version').document);
  }

  @override
  Future<void> saveWithSkillVersionSource(
    List<Resource> resources, {
    required SkillVersionSource source,
  }) => save(resources);
}
