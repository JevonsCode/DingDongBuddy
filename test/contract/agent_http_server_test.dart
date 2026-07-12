import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/agent_api/data/agent_http_server.dart';
import 'package:dingdong/features/agent_api/data/agent_router.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loopback server exposes router responses over real HTTP', () async {
    final AgentHttpServer server = AgentHttpServer(
      AgentRouter(resourceStore: InMemoryResourceStore()),
    );
    final HttpClient client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await server.stop();
    });
    await server.start(port: 0);

    final HttpClientRequest request = await client.getUrl(
      server.baseUri.resolve('/health'),
    );
    final HttpClientResponse response = await request.close();
    final String body = await utf8.decoder.bind(response).join();

    expect(response.statusCode, HttpStatus.ok);
    expect(jsonDecode(body), <String, Object?>{
      'status': 'ok',
      'service': 'DingDong',
    });
  });

  test(
    'server falls back to another loopback port when the preferred port is busy',
    () async {
      final ServerSocket occupied = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final AgentHttpServer server = AgentHttpServer(
        AgentRouter(resourceStore: InMemoryResourceStore()),
      );
      addTearDown(() async {
        await occupied.close();
        await server.stop();
      });

      await server.start(port: occupied.port);

      expect(server.baseUri.port, isNot(occupied.port));
      expect(server.baseUri.host, '127.0.0.1');

      final HttpClient client = HttpClient();
      addTearDown(() => client.close(force: true));
      final HttpClientResponse manifestResponse = await (await client.getUrl(
        server.baseUri.resolve('/agent/manifest'),
      )).close();
      final Map<String, Object?> manifest =
          jsonDecode(await utf8.decoder.bind(manifestResponse).join())
              as Map<String, Object?>;
      expect(
        manifest['baseURL'],
        server.baseUri.toString().replaceFirst(RegExp(r'/$'), ''),
      );
    },
  );
}
