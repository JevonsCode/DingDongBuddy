import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Loads the text content referenced by a resource update link.
abstract interface class ResourceUpdateFetcher {
  Future<String> fetch(Uri uri);
}

/// Network-backed update loader with desktop-safe protocol and size limits.
final class HttpResourceUpdateFetcher implements ResourceUpdateFetcher {
  HttpResourceUpdateFetcher({HttpClient? client})
    : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<String> fetch(Uri uri) async {
    Uri current = uri;
    for (int redirects = 0; redirects <= _maximumRedirects; redirects += 1) {
      current = normalizeResourceUpdateUri(current);
      _validateUri(current);
      final HttpClientRequest request = await _client
          .getUrl(current)
          .timeout(_requestTimeout);
      request.followRedirects = false;
      final HttpClientResponse response = await request.close().timeout(
        _requestTimeout,
      );
      if (_isRedirect(response.statusCode)) {
        final String? location = response.headers.value(
          HttpHeaders.locationHeader,
        );
        await response.drain<void>();
        if (location == null || redirects == _maximumRedirects) {
          throw const HttpException('Invalid resource update redirect');
        }
        current = current.resolve(location);
        continue;
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        throw HttpException(
          'Resource update returned HTTP ${response.statusCode}',
          uri: current,
        );
      }

      final BytesBuilder bytes = BytesBuilder(copy: false);
      await for (final List<int> chunk in response.timeout(_requestTimeout)) {
        bytes.add(chunk);
        if (bytes.length > _maximumBytes) {
          throw const FormatException('Resource update exceeds 100 KB');
        }
      }
      final String content = utf8.decode(bytes.takeBytes());
      if (content.trim().isEmpty) {
        throw const FormatException('Resource update is empty');
      }
      return content;
    }
    throw const HttpException('Too many resource update redirects');
  }
}

/// Converts GitHub file and Skill folder pages to their raw equivalent.
Uri normalizeResourceUpdateUri(Uri uri) {
  if (uri.host.toLowerCase() != 'github.com') {
    return uri;
  }
  final List<String> parts = uri.pathSegments;
  if (parts.length >= 5 && parts[2] == 'blob') {
    return Uri(
      scheme: 'https',
      host: 'raw.githubusercontent.com',
      pathSegments: <String>[parts[0], parts[1], parts[3], ...parts.skip(4)],
    );
  }
  if (parts.length >= 5 && parts[2] == 'tree') {
    final List<String> folder = parts.skip(4).toList(growable: true);
    if (folder.isEmpty || folder.last.toLowerCase() != 'skill.md') {
      folder.add('SKILL.md');
    }
    return Uri(
      scheme: 'https',
      host: 'raw.githubusercontent.com',
      pathSegments: <String>[parts[0], parts[1], parts[3], ...folder],
    );
  }
  throw const FormatException('Use a GitHub file link or a Skill folder link');
}

void _validateUri(Uri uri) {
  final bool loopback =
      uri.host == 'localhost' || uri.host == '127.0.0.1' || uri.host == '::1';
  if (uri.scheme != 'https' && !(uri.scheme == 'http' && loopback)) {
    throw const FormatException(
      'Resource update links must use HTTPS or loopback HTTP',
    );
  }
  if (!uri.hasAuthority || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    throw const FormatException('Invalid resource update link');
  }
}

bool _isRedirect(int statusCode) =>
    statusCode == HttpStatus.movedPermanently ||
    statusCode == HttpStatus.found ||
    statusCode == HttpStatus.seeOther ||
    statusCode == HttpStatus.temporaryRedirect ||
    statusCode == HttpStatus.permanentRedirect;

const Duration _requestTimeout = Duration(seconds: 10);
const int _maximumBytes = 100 * 1024;
const int _maximumRedirects = 5;
