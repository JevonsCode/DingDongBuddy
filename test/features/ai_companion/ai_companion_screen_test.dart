import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
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
  testWidgets(
    'token supports explicit paste and visibility while configuring',
    (tester) async {
      final fixture = _Fixture();
      addTearDown(fixture.controller.dispose);
      await fixture.controller.load();
      await _pump(tester, fixture.controller);
      await _show(tester, find.byKey(const Key('ai-configure-provider')));
      await tester.tap(find.byKey(const Key('ai-configure-provider')));
      await tester.pumpAndSettle();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.getData') return {'text': 'dummy'};
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.ensureVisible(find.byKey(const Key('ai-paste-api-key')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ai-paste-api-key')));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(
        find.byKey(const Key('ai-provider-api-key')),
      );
      expect(field.controller!.text, 'dummy');
      expect(field.focusNode!.hasFocus, true);
      expect(field.obscureText, true);
      await tester.tap(find.byKey(const Key('ai-toggle-api-key')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('ai-provider-api-key')))
            .obscureText,
        false,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );

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
                'bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ),
            ).readAsBytes().then(ByteData.sublistView),
          );
        await icons.load();
      });
      final _Fixture fixture = _Fixture();
      addTearDown(fixture.controller.dispose);
      await fixture.controller.load();
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
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _pump(
  WidgetTester tester,
  AiCompanionController controller,
) async {
  await tester.binding.setSurfaceSize(const Size(1000, 760));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      theme: AppTheme.desktopPanelLight(),
      localizationsDelegates: DingDongLocalizations.localizationsDelegates,
      supportedLocales: DingDongLocalizations.supportedLocales,
      home: Scaffold(body: AiCompanionScreen(controller: controller)),
    ),
  );
  await tester.pumpAndSettle();
}

class _Fixture {
  _Fixture() {
    store = AiCompanionPreferencesStore(
      MemoryPreferencesBackend(),
      secretStore: _Secrets(),
    );
    controller = AiCompanionController(
      store: store,
      client: AiCompanionClient(transport: transport),
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
