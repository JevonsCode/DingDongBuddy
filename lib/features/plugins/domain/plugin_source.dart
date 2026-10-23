import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Kept separate from the adapted code so an upstream change is observable
/// without replacing a running binary or claiming compatibility prematurely.
enum PluginUpstreamState { current, changed }

class PluginSource {
  const PluginSource({
    required this.name,
    required this.version,
    required this.license,
    required this.url,
    required this.metadataUrl,
    this.isCommit = false,
  });

  final String name;
  final String version;
  final String license;
  final String url;
  final String metadataUrl;
  final bool isCommit;

  static const screenshot = PluginSource(
    name: 'pro_image_editor',
    version: '14.16.0',
    license: 'BSD-3-Clause',
    url: 'https://github.com/hm21/pro_image_editor',
    metadataUrl: 'https://pub.dev/api/packages/pro_image_editor',
  );

  static const selection = PluginSource(
    name: 'selection-hook',
    version: 'd8ac605db1b0a87f816f6fdfd880e054033737e5',
    license: 'MIT',
    url: 'https://github.com/0xfullex/selection-hook',
    metadataUrl:
        'https://api.github.com/repos/0xfullex/selection-hook/commits/main',
    isCommit: true,
  );

  String get displayVersion => isCommit ? version.substring(0, 12) : version;

  PluginUpstreamState compareMetadata(Map<String, dynamic> json) {
    final value = isCommit ? json['sha'] : (json['latest'] as Map?)?['version'];
    if (value is! String || value.isEmpty) {
      throw const FormatException('Missing upstream version');
    }
    if (isCommit) {
      if (!RegExp(r'^[0-9a-f]{40}$').hasMatch(value)) {
        throw const FormatException('Invalid upstream commit');
      }
      return value == version
          ? PluginUpstreamState.current
          : PluginUpstreamState.changed;
    }
    final pattern = RegExp(r'^(\d+)\.(\d+)\.(\d+)$');
    final remote = pattern.firstMatch(value);
    final local = pattern.firstMatch(version);
    if (remote == null || local == null) {
      throw const FormatException('Invalid stable version');
    }
    for (var i = 1; i <= 3; i++) {
      final difference = int.parse(remote[i]!) - int.parse(local[i]!);
      if (difference != 0) {
        return difference > 0
            ? PluginUpstreamState.changed
            : PluginUpstreamState.current;
      }
    }
    return PluginUpstreamState.current;
  }

  /// On-demand metadata only. No screen, selection, model settings or tokens
  /// are sent. Updating adapted code remains a tested DingDong release.
  Future<PluginUpstreamState> checkForChanges() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 8);
    try {
      return await (() async {
        final request = await client.getUrl(Uri.parse(metadataUrl));
        request.followRedirects = false;
        request.headers.set(
          HttpHeaders.userAgentHeader,
          'DingDong-component-check',
        );
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close();
        if (response.statusCode != HttpStatus.ok) {
          throw HttpException('Component metadata unavailable');
        }
        final bytes = <int>[];
        await for (final chunk in response) {
          if (bytes.length + chunk.length > 2 * 1024 * 1024) {
            throw const FormatException('Component metadata too large');
          }
          bytes.addAll(chunk);
        }
        final decoded = jsonDecode(utf8.decode(bytes));
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Invalid component metadata');
        }
        return compareMetadata(decoded);
      })().timeout(const Duration(seconds: 12));
    } finally {
      client.close(force: true);
    }
  }
}
