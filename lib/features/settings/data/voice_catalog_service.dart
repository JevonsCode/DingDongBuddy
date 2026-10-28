import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:dingdong/features/settings/data/reminder_audio_importer.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';
import 'package:dingdong/features/settings/domain/voice_catalog.dart';

abstract interface class VoiceCatalogGateway {
  Future<VoiceCatalogPage> load({int page = 1, bool refresh = false});
  Future<CatalogVoice> findIssue(String link);
  Future<ReminderAudio> subscribe(CatalogVoice voice, Directory directory);
}

/// No account tokens, arbitrary hosts, execution or background audio updates.
final class VoiceCatalogService implements VoiceCatalogGateway {
  VoiceCatalogService({
    this.repository = voiceCatalogRepository,
    HttpClient Function()? clientFactory,
  }) : _clientFactory = clientFactory ?? HttpClient.new {
    if (!RegExp(r'^[a-zA-Z0-9_.-]+/[a-zA-Z0-9_.-]+$').hasMatch(repository)) {
      throw const FormatException('Invalid catalog repository.');
    }
  }
  final String repository;
  final HttpClient Function() _clientFactory;
  final Map<int, VoiceCatalogPage> _cache = {};
  final Map<int, DateTime> _cachedAt = {};

  @override
  Future<VoiceCatalogPage> load({int page = 1, bool refresh = false}) async {
    if (page < 1 || page > 10) {
      throw const FormatException('Catalog page limit reached.');
    }
    if (!refresh &&
        _cache.containsKey(page) &&
        DateTime.now().difference(_cachedAt[page]!) <
            const Duration(minutes: 5)) {
      return _cache[page]!;
    }
    final uri = Uri.https('api.github.com', '/repos/$repository/issues', {
      'state': 'open',
      'per_page': '100',
      'sort': 'created',
      'direction': 'desc',
      'page': '$page',
    });
    final bytes = await _get(uri, maxBytes: 4 * 1024 * 1024, attachment: false);
    final json = jsonDecode(utf8.decode(bytes));
    if (json is! List) throw const FormatException('Invalid catalog response.');
    final voices = <CatalogVoice>[];
    for (final item in json) {
      if (item is Map<String, dynamic>) {
        final voice = CatalogVoice.fromIssue(item, repository: repository);
        if (voice != null) voices.add(voice);
      }
    }
    final result = VoiceCatalogPage(voices, hasMore: json.length == 100);
    _cache[page] = result;
    _cachedAt[page] = DateTime.now();
    return result;
  }

  @override
  Future<CatalogVoice> findIssue(String link) async {
    final uri = Uri.tryParse(link.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.toString() != link.trim() ||
        uri.host != 'github.com' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        !RegExp(
          '^/${RegExp.escape(repository)}/issues/[1-9][0-9]*\u0024',
        ).hasMatch(uri.path)) {
      throw const FormatException(
        'Paste an Issue link from this voice catalog.',
      );
    }
    final api = Uri.https('api.github.com', '/repos${uri.path}');
    final json = jsonDecode(
      utf8.decode(await _get(api, maxBytes: 128 * 1024, attachment: false)),
    );
    final voice = json is Map<String, dynamic>
        ? CatalogVoice.fromIssue(json, repository: repository)
        : null;
    if (voice == null) {
      throw const FormatException('Voice is not available in this catalog.');
    }
    return voice;
  }

  /// Re-check the submission and attachment at installation time, not a stale card.
  @override
  Future<ReminderAudio> subscribe(
    CatalogVoice voice,
    Directory directory,
  ) async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$repository/issues/${voice.number}',
    );
    final json = jsonDecode(
      utf8.decode(await _get(uri, maxBytes: 128 * 1024, attachment: false)),
    );
    final current = json is Map<String, dynamic>
        ? CatalogVoice.fromIssue(json, repository: repository)
        : null;
    if (current == null || current.metadataJson != voice.metadataJson) {
      throw const FormatException(
        'This voice changed or is no longer available. Refresh the catalog.',
      );
    }
    final bytes = await _get(
      current.audioUrl,
      maxBytes: voiceCatalogMaxBytes,
      attachment: true,
    );
    validateCatalogWave(bytes);
    final digest = (await Sha256().hash(
      bytes,
    )).bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
    final latestJson = jsonDecode(
      utf8.decode(await _get(uri, maxBytes: 128 * 1024, attachment: false)),
    );
    final latest = latestJson is Map<String, dynamic>
        ? CatalogVoice.fromIssue(latestJson, repository: repository)
        : null;
    if (latest == null || latest.metadataJson != current.metadataJson) {
      throw const FormatException(
        'Voice changed during verification. Refresh the catalog.',
      );
    }
    await directory.create(recursive: true);
    // Keep catalog entries separate from local custom imports, even when the
    // bytes are identical, so subscribing never renames a user's local sound.
    final file = File('${directory.path}/voice-${voice.number}-$digest.wav');
    // Content addressing pins subscriptions. Never overwrite a selected file.
    if (await file.exists()) {
      if (await file.length() > voiceCatalogMaxBytes ||
          (await Sha256().hash(
                await file.readAsBytes(),
              )).bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join() !=
              digest) {
        throw const FormatException(
          'The existing local copy is damaged. It was not replaced.',
        );
      }
    } else {
      await file.writeAsBytes(bytes, flush: true);
    }
    var name = '';
    for (final rune in current.title.runes) {
      final character = String.fromCharCode(rune);
      if (name.length + character.length > 64) break;
      name += character;
    }
    return ReminderAudio(
      name: name,
      path: file.path,
      sourceIssue: current.issueUrl.toString(),
      sourceAuthor: current.author,
      sourceLicense: current.license,
      sourceAttribution: current.source,
      audioSha256: digest,
      metadataSha256: (await Sha256().hash(
        utf8.encode(current.metadataJson),
      )).bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join(),
    );
  }

  Future<Uint8List> _get(
    Uri uri, {
    required int maxBytes,
    required bool attachment,
  }) async {
    final client = _clientFactory()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      return await _read(
        client,
        uri,
        maxBytes,
        attachment,
      ).timeout(const Duration(seconds: 30));
    } finally {
      client.close(force: true);
    }
  }

  Future<Uint8List> _read(
    HttpClient client,
    Uri uri,
    int cap,
    bool attachment,
  ) async {
    // GitHub attachments use a signed, HTTPS redirect to this fixed CDN.
    for (var hop = 0; hop < 4; hop++) {
      final request = await client.getUrl(uri);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.userAgentHeader, 'DingDongBuddy-Voices');
      request.headers.set(
        HttpHeaders.acceptHeader,
        attachment
            ? 'audio/wav, application/octet-stream'
            : 'application/vnd.github+json',
      );
      final response = await request.close();
      if ([301, 302, 303, 307, 308].contains(response.statusCode)) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (!attachment || location == null) {
          throw const FormatException('Unexpected catalog redirect.');
        }
        final next = uri.resolve(location);
        if (next.scheme != 'https' ||
            next.hasPort ||
            next.userInfo.isNotEmpty ||
            !(isVoiceAttachment(next) ||
                (next.host ==
                        'github-production-user-asset-6210df.s3.amazonaws.com' &&
                    RegExp(r'^/[0-9]+/[a-zA-Z0-9_./-]+$').hasMatch(next.path) &&
                    next.fragment.isEmpty) ||
                (next.host == 'objects.githubusercontent.com' &&
                    RegExp(
                      r'^/github-production-repository-file-5c1aeb/[0-9]+/[0-9]+$',
                    ).hasMatch(next.path) &&
                    next.fragment.isEmpty))) {
          throw const FormatException('Untrusted audio redirect.');
        }
        uri = next;
        continue;
      }
      if (response.statusCode == 403 || response.statusCode == 429) {
        throw const HttpException(
          'GitHub rate limit reached. Try again later.',
        );
      }
      if (response.statusCode != 200) {
        throw HttpException('Catalog request failed (${response.statusCode}).');
      }
      if (response.contentLength > cap) {
        throw const FormatException('Response exceeds size limit.');
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        if (builder.length + chunk.length > cap) {
          throw const FormatException('Response exceeds size limit.');
        }
        builder.add(chunk);
      }
      return builder.takeBytes();
    }
    throw const FormatException('Too many audio redirects.');
  }
}

/// Structural PCM validation gives duration from decoded sample frames, not
/// filename, MIME, author claims, or a possibly forged duration header.
double validateCatalogWave(Uint8List bytes) {
  if (bytes.length > voiceCatalogMaxBytes) {
    throw const FormatException('Voice exceeds 5 MiB.');
  }
  validateWave(bytes); // Preserve the existing local-import contract.
  final view = ByteData.sublistView(bytes);
  if (view.getUint32(4, Endian.little) + 8 != bytes.length) {
    throw const FormatException('Invalid RIFF size.');
  }
  int? rate, align, framesBytes;
  var formats = 0;
  var dataChunks = 0;
  var at = 12;
  while (at + 8 <= bytes.length) {
    final tag = String.fromCharCodes(bytes.sublist(at, at + 4));
    final size = view.getUint32(at + 4, Endian.little);
    if (tag == 'fmt ') {
      formats++;
      if ((size != 16 && size != 18) ||
          (size == 18 && view.getUint16(at + 24, Endian.little) != 0)) {
        throw const FormatException('Use standard PCM WAV.');
      }
      rate = view.getUint32(at + 12, Endian.little);
      align = view.getUint16(at + 20, Endian.little);
    } else if (tag == 'data') {
      dataChunks++;
      framesBytes = size;
    }
    at += 8 + size + size % 2;
  }
  if (at != bytes.length ||
      formats != 1 ||
      dataChunks != 1 ||
      rate == null ||
      align == null ||
      framesBytes == null ||
      align == 0 ||
      framesBytes % align != 0 ||
      framesBytes > rate * align * 3) {
    throw const FormatException(
      'Public voices must contain at most 3 seconds of PCM WAV audio.',
    );
  }
  return framesBytes / align / rate;
}
