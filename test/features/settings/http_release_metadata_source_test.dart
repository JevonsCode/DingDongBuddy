import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/settings/data/http_release_metadata_source.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('decodes localized release notes with deterministic fallback', () async {
    final HttpClient client = HttpClient();
    addTearDown(() => client.close(force: true));
    final Uri metadataUri = await _serveMetadata(<String, Object?>{
      'app': 'DingDong',
      'latestVersion': '1.4.7',
      'website': 'https://example.com',
      'releasePage': 'https://example.com/releases/1.4.7',
      'notes': <String, Object?>{
        'en': <String>['English change'],
        'zh': <String>['中文变更'],
        'es': <String>['Cambio en español'],
      },
    });

    final ReleaseMetadata metadata = await HttpReleaseMetadataSource(
      client: client,
      metadataUris: <Uri>[metadataUri],
    ).fetch();

    expect(metadata.notesFor('zh-CN'), <String>['中文变更']);
    expect(metadata.notesFor('en-US'), <String>['English change']);
    expect(metadata.notesFor('es'), <String>['Cambio en español']);
  });

  test('keeps legacy release-note arrays compatible', () async {
    final HttpClient client = HttpClient();
    addTearDown(() => client.close(force: true));
    final Uri metadataUri = await _serveMetadata(<String, Object?>{
      'app': 'DingDong',
      'latestVersion': '1.4.7',
      'website': 'https://example.com',
      'releasePage': 'https://example.com/releases/1.4.7',
      'notes': <String>['Legacy change'],
    });

    final ReleaseMetadata metadata = await HttpReleaseMetadataSource(
      client: client,
      metadataUris: <Uri>[metadataUri],
    ).fetch();

    expect(metadata.notesFor('zh'), <String>['Legacy change']);
  });
}

Future<Uri> _serveMetadata(Map<String, Object?> payload) async {
  final HttpServer server = await HttpServer.bind(
    InternetAddress.loopbackIPv4,
    0,
  );
  server.listen((HttpRequest request) async {
    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(payload));
    await request.response.close();
    await server.close(force: true);
  });
  return Uri.parse(
    'http://${server.address.address}:${server.port}/release.json',
  );
}
