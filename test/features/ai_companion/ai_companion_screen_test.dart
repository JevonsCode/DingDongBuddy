import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/features/ai_companion/data/ai_companion_client.dart';
import 'package:dingdong/features/ai_companion/data/ai_companion_store.dart';
import 'package:dingdong/features/ai_companion/ui/ai_companion_controller.dart';
import 'package:dingdong/features/ai_companion/ui/ai_companion_screen.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('AI+ keeps analysis reachable while settings scroll', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.controller.dispose);
    await fixture.controller.load();
    await _pump(tester, fixture.controller);
    expect(find.text('AI+'), findsOneWidget);
    expect(find.byKey(const Key('ai-analyze')).hitTestable(), findsOneWidget);
    await _show(tester, find.byKey(const Key('ai-feature-include-internal')));
    expect(find.byKey(const Key('ai-analyze')).hitTestable(), findsOneWidget);
    expect(fixture.transport.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('retired chat stays absent even with legacy enabled settings', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.controller.dispose);
    await fixture.controller.saveSettings(
      AiCompanionSettings.fromJson({'emotionalSupport': true}),
    );
    await _pump(tester, fixture.controller);
    expect(find.byKey(const Key('ai-feature-chat')), findsNothing);
    expect(find.byKey(const Key('ai-message-input')), findsNothing);
    expect(find.text('A space to talk'), findsNothing);
    expect(
      fixture.controller.settings.toJson().containsKey('emotionalSupport'),
      isFalse,
    );
    expect(fixture.transport.requests, isEmpty);
  });

  testWidgets('protocol choice and HTTP endpoint persist in the model dialog', (
    tester,
  ) async {
    final fixture = _Fixture();
    addTearDown(fixture.controller.dispose);
    await fixture.controller.load();
    await _pump(tester, fixture.controller);
    await _show(tester, find.byKey(const Key('ai-configure-provider')));
    await tester.tap(find.byKey(const Key('ai-configure-provider')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-provider-protocol')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anthropic Messages').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('ai-provider-endpoint')),
      'http://gateway.example/coding-plan',
    );
    await tester.enterText(
      find.byKey(const Key('ai-provider-model')),
      'deepseek-v4.1-flash',
    );
    await tester.tap(find.byKey(const Key('ai-save-provider')));
    await tester.pumpAndSettle();
    final saved = await fixture.store.loadSettings();
    expect(saved.toJson()['protocol'], 'anthropic');
    expect(saved.providerEndpoint, 'http://gateway.example/coding-plan');
    expect(fixture.controller.error, isNull);
    expect(fixture.transport.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('every remaining capability persists independently', (
    WidgetTester tester,
  ) async {
    final _Fixture fixture = _Fixture();
    addTearDown(fixture.controller.dispose);
    await fixture.controller.load();
    await _pump(tester, fixture.controller);
    for (final (String key, String jsonKey) in <(String, String)>[
      ('auto-resources', 'autoResourceSelection'),
      ('clipboard', 'clipboardAnalysis'),
      ('resources', 'usageOptimization'),
      ('progressive-disclosure', 'progressiveDisclosure'),
      ('tokens', 'tokenOptimization'),
      ('check-ins', 'proactiveCheckIns'),
      ('cloud', 'cloudAnalysis'),
      ('include-internal', 'includeInternalInGlobal'),
    ]) {
      await _show(tester, find.byKey(Key('ai-feature-$key')));
      await tester.tap(find.byKey(Key('ai-feature-$key')));
      await tester.pumpAndSettle();
      final saved = (await fixture.store.loadSettings()).toJson();
      expect(saved[jsonKey], isTrue);
      expect(saved.entries.where((entry) => entry.value == true), hasLength(1));
      await _show(tester, find.byKey(Key('ai-feature-$key')));
      await tester.tap(find.byKey(Key('ai-feature-$key')));
      await tester.pumpAndSettle();
      expect(
        (await fixture.store.loadSettings()).toJson().entries.where(
          (entry) => entry.value == true,
        ),
        isEmpty,
      );
    }
    expect(fixture.transport.requests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'progressive disclosure alone analyzes Prompt and MCP scope with local review links',
    (WidgetTester tester) async {
      final _Fixture fixture = _Fixture(
        resources: <Resource>[
          Resource(
            id: 'prompt-scope',
            type: ResourceType.prompt,
            title: 'Task details',
            content: 'Task-specific instructions',
            activation: ResourceActivation.always,
            createdAt: DateTime(2026, 10, 21),
            updatedAt: DateTime(2026, 10, 21),
          ),
          Resource(
            id: 'mcp-scope',
            type: ResourceType.mcp,
            title: 'Task service',
            content: '{"command":"local-service"}',
            activation: ResourceActivation.always,
            createdAt: DateTime(2026, 10, 21),
            updatedAt: DateTime(2026, 10, 21),
          ),
        ],
      );
      addTearDown(fixture.controller.dispose);
      await fixture.controller.load();
      final reviewed = <String>[];
      await _pump(
        tester,
        fixture.controller,
        onReview: (suggestion) => reviewed.add(suggestion.targetId!),
      );
      await _show(
        tester,
        find.byKey(const Key('ai-feature-progressive-disclosure')),
      );
      await tester.tap(
        find.byKey(const Key('ai-feature-progressive-disclosure')),
      );
      await tester.pumpAndSettle();
      final saved = (await fixture.store.loadSettings()).toJson();
      expect(saved['progressiveDisclosure'], isTrue);
      expect(saved.entries.where((entry) => entry.value == true), hasLength(1));
      await _show(tester, find.byKey(const Key('ai-analyze')));
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('ai-analyze')))
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.byKey(const Key('ai-analyze')));
      await tester.pumpAndSettle();
      expect(
        fixture.controller.report!.suggestions.map((item) => item.code),
        <AiSuggestionCode>[
          AiSuggestionCode.progressivePrompt,
          AiSuggestionCode.progressiveMcp,
        ],
      );
      expect(
        find.textContaining('This always-on Prompt contains 26 characters.'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'Third-party Agents may still load all configured tool schemas.',
        ),
        findsOneWidget,
      );
      await _show(
        tester,
        find.byKey(const Key('ai-review-progressivePrompt-prompt-scope')),
      );
      await tester.tap(
        find.byKey(const Key('ai-review-progressivePrompt-prompt-scope')),
      );
      await _show(
        tester,
        find.byKey(const Key('ai-review-progressiveMcp-mcp-scope')),
      );
      await tester.tap(
        find.byKey(const Key('ai-review-progressiveMcp-mcp-scope')),
      );
      expect(reviewed, <String>['prompt-scope', 'mcp-scope']);
      expect(fixture.transport.requests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('default switches are independent, persisted and network-free', (
    WidgetTester tester,
  ) async {
    final _Fixture fixture = _Fixture();
    addTearDown(fixture.controller.dispose);
    await fixture.controller.load();
    String? reviewed;
    await _pump(
      tester,
      fixture.controller,
      onReview: (AiSuggestion suggestion) => reviewed = suggestion.targetId,
    );

    expect(
      tester
          .widgetList<CompactSwitchListTile>(find.byType(CompactSwitchListTile))
          .every((CompactSwitchListTile tile) => !tile.value),
      isTrue,
    );
    await _show(tester, find.byKey(const Key('ai-analyze')));
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('ai-analyze')))
          .onPressed,
      isNull,
    );
    expect(fixture.transport.requests, isEmpty);

    await _show(tester, find.byKey(const Key('ai-feature-clipboard')));
    await tester.tap(find.byKey(const Key('ai-feature-clipboard')));
    await tester.pumpAndSettle();
    expect(fixture.controller.settings.clipboardAnalysis, isTrue);
    expect(fixture.controller.settings.usageOptimization, isFalse);
    expect(fixture.controller.settings.progressiveDisclosure, isFalse);
    expect(fixture.controller.settings.tokenOptimization, isFalse);
    expect(fixture.controller.settings.cloudAnalysis, isFalse);
    expect(fixture.controller.settings.proactiveCheckIns, isFalse);
    final saved = await fixture.store.loadSettings();
    expect(saved.clipboardAnalysis, isTrue);
    expect(saved.cloudAnalysis, isFalse);

    await _show(tester, find.byKey(const Key('ai-analyze')));
    await tester.tap(find.byKey(const Key('ai-analyze')));
    await tester.pumpAndSettle();
    expect(fixture.transport.requests, isEmpty);
    expect(find.text('Local analysis · no model request'), findsOneWidget);
    expect(find.textContaining('Copied 4 times.'), findsOneWidget);
    await _show(tester, find.text('Review item'));
    await tester.tap(find.text('Review item'));
    expect(reviewed, 'clipboard-local');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'saving provider never claims success; explicit test reports failure and success',
    (WidgetTester tester) async {
      final _Fixture fixture = _Fixture();
      addTearDown(fixture.controller.dispose);
      await fixture.controller.load();
      await _pump(tester, fixture.controller);
      await _show(tester, find.byKey(const Key('ai-configure-provider')));
      await tester.tap(find.byKey(const Key('ai-configure-provider')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('ai-provider-endpoint')),
        'http://127.0.0.1:11434/v1',
      );
      await tester.enterText(
        find.byKey(const Key('ai-provider-model')),
        'local-model',
      );
      await tester.tap(find.byKey(const Key('ai-save-provider')));
      await tester.pumpAndSettle();
      expect(fixture.controller.isConfigured, isTrue);
      expect(fixture.transport.requests, isEmpty);
      expect(
        find.text('Model configured · connection not verified'),
        findsOneWidget,
      );
      expect(find.text('Model responded successfully'), findsNothing);

      fixture.transport.statusCode = 500;
      await _show(tester, find.byKey(const Key('ai-test-connection')));
      await tester.tap(find.byKey(const Key('ai-test-connection')));
      await tester.pumpAndSettle();
      expect(fixture.controller.error, AiCompanionError.providerUnavailable);
      expect(
        find.textContaining('The model could not respond.'),
        findsOneWidget,
      );
      expect(find.text('Model responded successfully'), findsNothing);

      fixture.transport.statusCode = 200;
      await tester.tap(find.byKey(const Key('ai-test-connection')));
      await tester.pumpAndSettle();
      expect(fixture.transport.requests, hasLength(2));
      expect(find.text('Model responded successfully'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'opt-in check-ins are local, rate limited and cancelled on page disposal',
    (WidgetTester tester) async {
      DateTime now = DateTime(2026, 10, 21, 9);
      final _Fixture fixture = _Fixture(now: () => now);
      addTearDown(fixture.controller.dispose);
      await fixture.controller.load();
      await fixture.controller.saveSettings(
        const AiCompanionSettings(proactiveCheckIns: true),
      );
      await _pump(tester, fixture.controller, now: () => now);
      now = now.add(const Duration(hours: 1));
      await tester.pump(const Duration(hours: 1));
      await tester.pump();
      expect(
        fixture.controller.report!.suggestions.single.code,
        AiSuggestionCode.takeBreak,
      );
      final firstTime = fixture.controller.report!.createdAt;
      now = now.add(const Duration(hours: 1));
      await tester.pump(const Duration(hours: 1));
      await tester.pump();
      expect(fixture.controller.report!.createdAt, firstTime);
      expect(fixture.transport.requests, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      now = now.add(const Duration(hours: 3));
      await tester.pump(const Duration(hours: 3));
      expect(fixture.controller.report!.createdAt, firstTime);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'Chinese companion local preview at standard and narrow desktop widths',
    (WidgetTester tester) async {
      final String? previewDirectory =
          Platform.environment['DINGDONG_AI_PREVIEW_DIR'];
      if (previewDirectory == null) return;
      await tester.runAsync(() async {
        for (final family in <String>[
          'AI Preview Chinese',
          'Segoe UI',
          '.AppleSystemUIFont',
          'Roboto',
        ]) {
          final font = FontLoader(family)
            ..addFont(
              File(
                Platform.isMacOS
                    ? '/System/Library/Fonts/STHeiti Medium.ttc'
                    : r'C:\Windows\Fonts\msyh.ttc',
              ).readAsBytes().then(ByteData.sublistView),
            );
          await font.load();
        }
        final config =
            jsonDecode(
                  await File('.dart_tool/package_config.json').readAsString(),
                )
                as Map<String, Object?>;
        final sdk = Uri.parse('${config['flutterRoot']}/');
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            File.fromUri(
              sdk.resolve(
                'bin/cache/artifacts/material_fonts/materialicons-regular.otf',
              ),
            ).readAsBytes().then(ByteData.sublistView),
          );
        await icons.load();
      });
      final _Fixture fixture = _Fixture();
      addTearDown(fixture.controller.dispose);
      await fixture.controller.load();
      await fixture.controller.saveSettings(
        const AiCompanionSettings(
          clipboardAnalysis: true,
          usageOptimization: true,
          tokenOptimization: true,
          providerEndpoint: 'http://127.0.0.1:11434/v1',
          model: 'local-model',
        ),
      );
      await fixture.controller.analyze();
      for (final double width in <double>[1100, 800, 520]) {
        await tester.binding.setSurfaceSize(Size(width, 760));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final key = GlobalKey();
        final ThemeData appTheme = AppTheme.desktopPanelLight();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              locale: const Locale('zh'),
              theme: appTheme.copyWith(
                textTheme: appTheme.textTheme.apply(
                  fontFamily: 'AI Preview Chinese',
                ),
              ),
              localizationsDelegates:
                  DingDongLocalizations.localizationsDelegates,
              supportedLocales: DingDongLocalizations.supportedLocales,
              home: Scaffold(
                body: AiCompanionScreen(controller: fixture.controller),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await _capture(
          tester,
          key,
          '$previewDirectory/ai-companion-${width.toInt()}-zh-top.png',
        );
        await _show(tester, find.text('内部 Token 消耗'));
        await _capture(
          tester,
          key,
          '$previewDirectory/ai-companion-${width.toInt()}-zh-usage.png',
        );
        await _show(tester, find.byKey(const Key('ai-analyze')));
        await _capture(
          tester,
          key,
          '$previewDirectory/ai-companion-${width.toInt()}-zh-insights.png',
        );
        await _show(tester, find.byKey(const Key('ai-configure-provider')));
        await tester.tap(find.byKey(const Key('ai-configure-provider')));
        await tester.pumpAndSettle();
        expect(find.text('模型连接'), findsNWidgets(2));
        await _capture(
          tester,
          key,
          '$previewDirectory/ai-companion-${width.toInt()}-zh-provider.png',
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('取消'));
        await tester.pumpAndSettle();
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String path) async {
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(path);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  final ScrollableState scrollable = tester.state<ScrollableState>(
    find.byType(Scrollable).first,
  );
  scrollable.position.jumpTo(0);
  await tester.pump();
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  AiCompanionController controller, {
  ValueChanged<AiSuggestion>? onReview,
  DateTime Function()? now,
}) async {
  await tester.binding.setSurfaceSize(const Size(1000, 760));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: DingDongLocalizations.localizationsDelegates,
      supportedLocales: DingDongLocalizations.supportedLocales,
      home: Scaffold(
        body: AiCompanionScreen(
          controller: controller,
          onReviewSuggestion: onReview,
          now: now,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _Fixture {
  _Fixture({
    DateTime Function()? now,
    List<Resource> resources = const <Resource>[],
  }) {
    store = AiCompanionPreferencesStore(
      MemoryPreferencesBackend(),
      secretStore: _Secrets(),
    );
    controller = AiCompanionController(
      store: store,
      client: AiCompanionClient(transport: transport),
      now: now,
      loadMetadata: () async => AiCompanionMetadata(
        resources: resources,
        clipboard: <ClipboardRecord>[
          ClipboardRecord(
            id: 'clipboard-local',
            group: 'Work',
            title: 'Local title',
            content: 'Reusable short sentence',
            tags: const <String>[],
            pinned: false,
            enabled: true,
            activation: 'manual',
            copyCount: 4,
            createdAt: DateTime(2026, 10, 20),
            updatedAt: DateTime(2026, 10, 21),
          ),
        ],
      ),
    );
  }
  final _Transport transport = _Transport();
  late final AiCompanionPreferencesStore store;
  late final AiCompanionController controller;
}

class _Secrets implements AiCompanionSecretStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String next) async => value = next;
  @override
  Future<void> delete() async => value = null;
}

class _Transport implements AiCompanionTransport {
  int statusCode = 200;
  final List<String> requests = <String>[];
  @override
  Future<AiCompanionHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    requests.add(body);
    return AiCompanionHttpResponse(
      statusCode,
      jsonEncode(<String, Object>{
        'choices': <Object>[
          <String, Object>{
            'message': <String, String>{'content': 'Take a slow breath.'},
          },
        ],
      }),
    );
  }

  @override
  void close() {}
}
