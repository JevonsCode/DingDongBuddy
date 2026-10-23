import 'dart:convert';
import 'package:cryptography/cryptography.dart';

/// Public catalog rules are deliberately separate from local custom audio.
const voiceCatalogRepository = 'JevonsCode/dingdong-voices';
const voiceCatalogLabel = 'voice-approved';
const voiceCatalogMaxBytes = 5 * 1024 * 1024;
const voiceCatalogWebsite =
    'https://xn--8ovp9s.xn--m8txu.com/DingDongBuddy/voices/';

/// Only GitHub's attachment storage is accepted, never arbitrary Issue URLs.
bool isVoiceAttachment(Uri uri) =>
    uri.scheme == 'https' &&
    uri.host == 'github.com' &&
    !uri.hasPort &&
    uri.userInfo.isEmpty &&
    uri.query.isEmpty &&
    uri.fragment.isEmpty &&
    RegExp(
      r'^/user-attachments/files/[0-9]+/[a-zA-Z0-9_.-]+\.wav$',
      caseSensitive: false,
    ).hasMatch(uri.path);

Map<String, String>? voiceIssueFields(String body) {
  final fields = <String, String>{};
  String? key;
  for (final line in body.replaceAll('\r\n', '\n').split('\n')) {
    final heading = RegExp(r'^### (.+?)\s*$').firstMatch(line);
    if (heading != null) {
      key = heading.group(1)!;
      if (fields.containsKey(key)) return null;
      fields[key] = '';
    } else if (key != null) {
      fields[key] = '${fields[key]}$line\n';
    }
  }
  return fields.map((key, value) => MapEntry(key, value.trim()));
}

final class CatalogVoice {
  const CatalogVoice({
    required this.number,
    required this.title,
    required this.description,
    required this.author,
    required this.createdAt,
    required this.updatedAt,
    required this.audioUrl,
    required this.issueUrl,
    required this.license,
    required this.source,
    required this.metadataJson,
    this.likes = 0,
    this.dislikes = 0,
  });
  final int number;
  final String title, description, author, license, source, metadataJson;
  final DateTime createdAt, updatedAt;
  final Uri audioUrl, issueUrl;
  final int likes, dislikes;

  /// Labels, author, timestamps and votes come from the API, not body claims.
  static CatalogVoice? fromIssue(
    Map<String, dynamic> issue, {
    String repository = voiceCatalogRepository,
  }) {
    try {
      if (issue['state'] != 'open' || issue.containsKey('pull_request')) {
        return null;
      }
      final labels = issue['labels'];
      if (labels is! List ||
          !labels.any((l) => l is Map && l['name'] == voiceCatalogLabel)) {
        return null;
      }
      final number = issue['number'];
      final title = issue['title'];
      final body = issue['body'];
      final author = (issue['user'] as Map?)?['login'];
      if (number is! int ||
          number < 1 ||
          title is! String ||
          title.trim().isEmpty ||
          title.length > 256 ||
          body is! String ||
          body.length > 65536 ||
          author is! String ||
          !RegExp(r'^[a-zA-Z0-9-]{1,39}$').hasMatch(author)) {
        return null;
      }
      final fields = voiceIssueFields(body);
      if (fields == null) return null;
      final audio = fields['Audio'];
      final description = fields['Description'];
      final license = fields['License'];
      final source = fields['Source'];
      final rights = fields['Rights confirmation'];
      if (audio == null ||
          description == null ||
          description.isEmpty ||
          description == '_No response_' ||
          description.length > 2000 ||
          license == null ||
          license.isEmpty ||
          license == '_No response_' ||
          license.length > 500 ||
          source == null ||
          source.isEmpty ||
          source == '_No response_' ||
          source.length > 2000 ||
          rights == null ||
          !RegExp(r'- \[x\]', caseSensitive: false).hasMatch(rights)) {
        return null;
      }
      final urls = RegExp(
        r'https://[^\s<>\[\]\(\)]+',
      ).allMatches(audio).map((m) => m.group(0)!).toList();
      if (urls.length != 1) return null;
      if (!RegExp(
        r'^https://github\.com/user-attachments/files/[0-9]+/[a-zA-Z0-9_.-]+\.wav$',
        caseSensitive: false,
      ).hasMatch(urls.single)) {
        return null;
      }
      final audioUrl = Uri.parse(urls.single);
      if (!isVoiceAttachment(audioUrl)) return null;
      final issueUrl = Uri.https('github.com', '/$repository/issues/$number');
      if (issue['html_url'] != issueUrl.toString()) return null;
      final reactions = issue['reactions'] as Map?;
      int votes(String key) {
        final n = reactions?[key];
        return n is int && n >= 0 ? n : 0;
      }

      final displayTitle = title
          .replaceFirst(RegExp(r'^\[Voice\]\s*', caseSensitive: false), '')
          .trim();
      return CatalogVoice(
        number: number,
        title: displayTitle.isEmpty ? title.trim() : displayTitle,
        description: description,
        author: author,
        createdAt: DateTime.parse(issue['created_at'] as String),
        updatedAt: DateTime.parse(issue['updated_at'] as String),
        audioUrl: audioUrl,
        issueUrl: issueUrl,
        license: license,
        source: source,
        metadataJson: jsonEncode([
          title,
          description,
          urls.single,
          source,
          license,
          rights,
        ]),
        likes: votes('+1'),
        dislikes: votes('-1'),
      );
    } on Object {
      return null;
    }
  }
}

final class VoiceCatalogPage {
  const VoiceCatalogPage(this.voices, {this.hasMore = false});
  final List<CatalogVoice> voices;
  final bool hasMore;
}

/// Approval is data, never a script or Markdown renderer. Current issue fields
/// must exactly match an owner-approved digest before accessing audio.
Future<String?> approvedAudioHash(
  CatalogVoice voice,
  List<dynamic> comments,
) async {
  final digest = (await Sha256().hash(
    utf8.encode(voice.metadataJson),
  )).bytes.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  for (final comment in comments.reversed) {
    if (comment is! Map) continue;
    final user = comment['user'];
    if (user is! Map ||
        user['id'] != 36203025 ||
        comment['author_association'] != 'OWNER') {
      continue;
    }
    final body = comment['body'];
    if (body is! String || body.length > 2048) continue;
    try {
      const prefix = '🕵🏻‍♀️[DOT]\n';
      final approval = jsonDecode(
        body.startsWith(prefix) ? body.substring(prefix.length) : body,
      );
      if (approval is Map &&
          approval['dingdongVoiceApproval'] == 1 &&
          approval['issue'] == voice.number &&
          approval['metadataSha256'] == digest &&
          approval['audioSha256'] is String &&
          RegExp(
            r'^[0-9a-f]{64}$',
          ).hasMatch(approval['audioSha256'] as String)) {
        return approval['audioSha256'] as String;
      }
    } on FormatException {
      /* Other comments are discussion, not approvals. */
    }
  }
  return null;
}
