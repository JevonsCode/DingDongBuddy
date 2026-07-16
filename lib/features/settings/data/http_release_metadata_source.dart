import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/settings/domain/release_update.dart';

/// Fetches release metadata from the project mirrors in priority order.
final class HttpReleaseMetadataSource implements ReleaseMetadataSource {
  HttpReleaseMetadataSource({HttpClient? client, List<Uri>? metadataUris})
    : _client = client ?? HttpClient(),
      _metadataUris = metadataUris ?? defaultReleaseMetadataUris;

  final HttpClient _client;
  final List<Uri> _metadataUris;

  @override
  Future<ReleaseMetadata> fetch() async {
    Object? lastError;
    for (final Uri uri in _metadataUris) {
      try {
        final HttpClientRequest request = await _client
            .getUrl(uri)
            .timeout(_timeout);
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final HttpClientResponse response = await request.close().timeout(
          _timeout,
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          await response.drain<void>();
          throw HttpException(
            'Release metadata returned HTTP ${response.statusCode}',
            uri: uri,
          );
        }
        final String body = await utf8.decodeStream(response).timeout(_timeout);
        if (body.length > _maximumCharacters) {
          throw const FormatException('Release metadata is too large');
        }
        return _decode(body);
      } on Object catch (error) {
        lastError = error;
      }
    }
    throw StateError('Release metadata is unavailable: $lastError');
  }
}

ReleaseMetadata _decode(String body) {
  final Object? decoded = jsonDecode(body);
  if (decoded is! Map<String, Object?>) {
    throw const FormatException('Release metadata must be a JSON object');
  }
  final String app = _requiredString(decoded, 'app');
  if (app != 'DingDong') {
    throw const FormatException('Release metadata is for another app');
  }
  final List<String> notes = (decoded['notes'] as List<Object?>? ?? const [])
      .whereType<String>()
      .toList(growable: false);
  return ReleaseMetadata(
    app: app,
    latestVersion: _requiredString(decoded, 'latestVersion'),
    latestBuild: decoded['latestBuild'] as String?,
    publishedAt: DateTime.tryParse(decoded['publishedAt'] as String? ?? ''),
    website: Uri.parse(_requiredString(decoded, 'website')),
    releasePage: Uri.parse(_requiredString(decoded, 'releasePage')),
    notes: List<String>.unmodifiable(notes),
  );
}

String _requiredString(Map<String, Object?> json, String key) {
  final Object? value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing release metadata field: $key');
  }
  return value.trim();
}

final List<Uri> defaultReleaseMetadataUris = <Uri>[
  Uri.parse(
    'https://xn--8ovp9s.xn--m8txu.com/DingDongBuddy/dingdong-release.json',
  ),
  Uri.parse('https://jevonscode.github.io/DingDongBuddy/dingdong-release.json'),
  Uri.parse(
    'https://raw.githubusercontent.com/JevonsCode/DingDongBuddy/main/docs/dingdong-release.json',
  ),
];

const Duration _timeout = Duration(seconds: 15);
const int _maximumCharacters = 256 * 1024;
