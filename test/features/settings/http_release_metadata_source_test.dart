import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/settings/data/http_release_metadata_source.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'prefers separate localized notes while preserving the legacy array',
    () async {
      final HttpClient client = HttpClient();
      addTearDown(() => client.close(force: true));
      final Uri metadataUri = await _serveMetadata(<String, Object?>{
        'app': 'DingDong',
        'latestVersion': '1.5.1',
        'website': 'https://example.com',
        'releasePage': 'https://example.com/releases/1.5.1',
        'notes': <String>['Legacy English change'],
        'notesByLanguage': <String, Object?>{
          'en': <String>['Localized English change'],
          'zh': <String>['中文变更'],
          'es': <String>['Cambio en español'],
        },
      });

      final ReleaseMetadata metadata = await HttpReleaseMetadataSource(
        client: client,
        metadataUris: <Uri>[metadataUri],
      ).fetch();

      expect(metadata.notes, <String>['Legacy English change']);
      expect(metadata.notesFor('zh-CN'), <String>['中文变更']);
      expect(metadata.notesFor('en-US'), <String>['Localized English change']);
      expect(metadata.notesFor('es'), <String>['Cambio en español']);
    },
  );

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

  test('reads an optional beta release and ignores a malformed one', () async {
    final HttpClient client = HttpClient();
    addTearDown(() => client.close(force: true));
    final Uri withBeta = await _serveMetadata(<String, Object?>{
      'app': 'DingDong',
      'latestVersion': '1.7.0',
      'website': 'https://example.com',
      'releasePage': 'https://example.com/releases/1.7.0',
      'beta': <String, Object?>{
        'latestVersion': '1.8.0-beta.1',
        'latestBuild': '69',
        'releasePage': 'https://example.com/releases/1.8.0-beta.1',
        'notes': <String>['Beta change'],
      },
    });
    final Uri brokenBeta = await _serveMetadata(<String, Object?>{
      'app': 'DingDong',
      'latestVersion': '1.7.0',
      'website': 'https://example.com',
      'releasePage': 'https://example.com/releases/1.7.0',
      'beta': <String, Object?>{'latestBuild': '69'},
    });

    final ReleaseMetadata metadata = await HttpReleaseMetadataSource(
      client: client,
      metadataUris: <Uri>[withBeta],
    ).fetch();
    final ReleaseMetadata stableOnly = await HttpReleaseMetadataSource(
      client: client,
      metadataUris: <Uri>[brokenBeta],
    ).fetch();

    expect(metadata.latestVersion, '1.7.0');
    expect(metadata.beta?.latestVersion, '1.8.0-beta.1');
    expect(metadata.beta?.latestBuild, '69');
    expect(metadata.beta?.website, Uri.parse('https://example.com'));
    expect(metadata.beta?.notes, <String>['Beta change']);
    expect(stableOnly.latestVersion, '1.7.0');
    expect(stableOnly.beta, isNull);
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
