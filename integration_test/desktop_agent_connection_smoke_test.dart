import 'dart:io';

import 'package:dingdong/app/dingdong_app.dart';
import 'package:dingdong/features/agent_api/data/agent_http_server.dart';
import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real loopback fallback is healthy and shown consistently', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 760);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    // The occupied port, fallback server, and /health request are real socket
    // operations. App content stores remain in-memory test substitutes so this
    // smoke test never reads or mutates the user's DingDong data.
    final HttpServer occupied = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
      shared: false,
    );
    final AgentHttpServer server = AgentHttpServer(AgentRouter());
    addTearDown(() async {
      await server.stop();
      await occupied.close(force: true);
    });

    final int preferredPort = occupied.port;
    await server.start(port: preferredPort);
    final Uri actualEndpoint = server.baseUri;
    expect(actualEndpoint.port, isNot(preferredPort));

    final SettingsRepository settingsRepository = SettingsRepository(
      MemoryPreferencesBackend(<String, Object>{
        'dingdong.api.port': preferredPort,
        'dingdong.language': 'en',
      }),
    );
    await tester.pumpWidget(
      DingDongApp(
        agentBaseUri: actualEndpoint,
        settingsRepository: settingsRepository,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('API listening on 127.0.0.1:${actualEndpoint.port}'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('today-agent-api')));
    await tester.pumpAndSettle();

    expect(find.text('Local service verified'), findsOneWidget);
    expect(
      find.text(actualEndpoint.toString().replaceFirst(RegExp(r'/$'), '')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('agent-api-fallback-port')), findsOneWidget);
    expect(
      find.textContaining(
        'Preferred port $preferredPort was unavailable; '
        'using ${actualEndpoint.port}.',
      ),
      findsOneWidget,
    );
  });
}
