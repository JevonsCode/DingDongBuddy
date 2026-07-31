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

  test('root requests redirect to the configured DingDong website', () async {
    final AgentHttpServer server = AgentHttpServer(
      AgentRouter(),
      websiteUri: Uri.parse('https://example.com/dingdong/'),
    );
    final HttpClient client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await server.stop();
    });
    await server.start(port: 0);

    final HttpClientRequest request = await client.getUrl(server.baseUri);
    request.followRedirects = false;
    final HttpClientResponse response = await request.close();

    expect(response.statusCode, HttpStatus.found);
    expect(
      response.headers.value(HttpHeaders.locationHeader),
      'https://example.com/dingdong/',
    );
  });

  test(
    'server rejects browser cross-origin access outside public routes',
    () async {
      final AgentHttpServer server = AgentHttpServer(
        AgentRouter(resourceStore: InMemoryResourceStore()),
      );
      final HttpClient client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await server.stop();
      });
      await server.start(port: 0);

      final HttpClientRequest originRequest = await client.getUrl(
        server.baseUri.resolve('/agent/manifest'),
      );
      originRequest.headers.set('origin', 'https://example.com');
      final HttpClientResponse originResponse = await originRequest.close();

      final HttpClientRequest fetchMetadataRequest = await client.getUrl(
        server.baseUri.resolve('/agent/manifest'),
      );
      fetchMetadataRequest.headers.set('sec-fetch-site', 'cross-site');
      final HttpClientResponse fetchMetadataResponse =
          await fetchMetadataRequest.close();

      expect(originResponse.statusCode, HttpStatus.forbidden);
      expect(fetchMetadataResponse.statusCode, HttpStatus.forbidden);
    },
  );

  test(
    'server requires JSON for POST and state changes are not available by GET',
    () async {
      var dingCount = 0;
      var shownCount = 0;
      final AgentHttpServer server = AgentHttpServer(
        AgentRouter(
          onDing: (_) => dingCount += 1,
          onShowUi: (_) => shownCount += 1,
        ),
      );
      final HttpClient client = HttpClient();
      addTearDown(() async {
        client.close(force: true);
        await server.stop();
      });
      await server.start(port: 0);

      final HttpClientRequest formRequest = await client.postUrl(
        server.baseUri.resolve('/ding'),
      );
      formRequest.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
      );
      formRequest.write('message=unexpected');
      final HttpClientResponse formResponse = await formRequest.close();

      final HttpClientResponse getDingResponse = await (await client.getUrl(
        server.baseUri.resolve('/ding'),
      )).close();
      final HttpClientResponse getShowResponse = await (await client.getUrl(
        server.baseUri.resolve('/ui/show'),
      )).close();

      final HttpClientRequest jsonRequest = await client.postUrl(
        server.baseUri.resolve('/ding'),
      );
      jsonRequest.headers.contentType = ContentType.json;
      jsonRequest.write('{"message":"Expected"}');
      final HttpClientResponse jsonResponse = await jsonRequest.close();

      expect(formResponse.statusCode, HttpStatus.unsupportedMediaType);
      expect(getDingResponse.statusCode, HttpStatus.notFound);
      expect(getShowResponse.statusCode, HttpStatus.notFound);
      expect(jsonResponse.statusCode, HttpStatus.ok);
      expect(dingCount, 1);
      expect(shownCount, 0);
    },
  );

  test('server rejects request bodies above its configured limit', () async {
    final AgentHttpServer server = AgentHttpServer(
      AgentRouter(),
      maxRequestBodyBytes: 16,
    );
    final HttpClient client = HttpClient();
    addTearDown(() async {
      client.close(force: true);
      await server.stop();
    });
    await server.start(port: 0);

    final HttpClientRequest request = await client.postUrl(
      server.baseUri.resolve('/ding'),
    );
    request.headers.contentType = ContentType.json;
    request.write('{"message":"this is too large"}');
    final HttpClientResponse response = await request.close();

    expect(response.statusCode, HttpStatus.requestEntityTooLarge);
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
