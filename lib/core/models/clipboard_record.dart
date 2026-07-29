import 'dart:typed_data';

/// User-facing clipboard content categories.
enum ClipboardKind { text, url, command, code, json, path, email, file, image }

/// One durable clipboard history entry.
final class ClipboardRecord {
  const ClipboardRecord({
    required this.id,
    required this.group,
    this.groups = const <String>[],
    required this.title,
    required this.content,
    this.htmlData,
    this.rtfData,
    required this.tags,
    required this.pinned,
    required this.enabled,
    required this.activation,
    required this.createdAt,
    required this.updatedAt,
    this.source,
    this.sortOrder,
  });

  final String id;

  /// Legacy primary group retained for store and API compatibility.
  final String group;
  final List<String> groups;
  final String title;
  final String content;
  final Uint8List? htmlData;
  final Uint8List? rtfData;
  final List<String> tags;
  final String? source;
  final bool pinned;
  final bool enabled;
  final String activation;
  final int? sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get sensitive => tags.contains('sensitive');

  bool get canPasteAsPlainText =>
      kind != ClipboardKind.file && kind != ClipboardKind.image;

  bool get hasFormattedText =>
      (htmlData?.isNotEmpty ?? false) || (rtfData?.isNotEmpty ?? false);

  /// Whether automatic retention must leave this record untouched.
  ///
  /// Older releases marked archives with a tag, while current releases archive
  /// by assigning a user-created group. Keep both representations readable so
  /// upgrading cannot make an existing archive disposable.
  bool get isArchived {
    if (tags.any((String tag) => tag.trim().toLowerCase() == 'archived')) {
      return true;
    }
    return groupNames.any((String value) {
      final String normalized = value.trim().toLowerCase();
      return normalized == 'archive' || !isAutomaticClipboardGroup(value);
    });
  }

  /// Every user-defined group this record belongs to, in display order.
  List<String> get groupNames {
    final Set<String> seen = <String>{};
    return <String>[group, ...groups]
        .map((String value) => value.trim())
        .where(
          (String value) => value.isNotEmpty && seen.add(value.toLowerCase()),
        )
        .toList(growable: false);
  }

  ClipboardKind get kind {
    if (tags.contains('image')) {
      return ClipboardKind.image;
    }
    if (tags.contains('file') || tags.contains('file-url')) {
      return ClipboardKind.file;
    }
    for (final ClipboardKind candidate in <ClipboardKind>[
      ClipboardKind.url,
      ClipboardKind.command,
      ClipboardKind.code,
      ClipboardKind.json,
      ClipboardKind.path,
      ClipboardKind.email,
    ]) {
      if (tags.contains(candidate.name)) {
        return candidate;
      }
    }
    return ClipboardKind.text;
  }

  ClipboardRecord copyWith({
    String? group,
    List<String>? groups,
    String? title,
    String? content,
    Uint8List? htmlData,
    Uint8List? rtfData,
    bool replaceFormattedText = false,
    List<String>? tags,
    bool? pinned,
    bool? enabled,
    String? activation,
    int? sortOrder,
    DateTime? updatedAt,
  }) {
    final List<String>? resolvedGroups = groups == null
        ? null
        : _normalizedGroups(groups);
    return ClipboardRecord(
      id: id,
      group: resolvedGroups == null
          ? group ?? this.group
          : (resolvedGroups.isEmpty ? '' : resolvedGroups.first),
      groups: resolvedGroups ?? (group == null ? this.groups : <String>[group]),
      title: title ?? this.title,
      content: content ?? this.content,
      htmlData: replaceFormattedText ? htmlData : htmlData ?? this.htmlData,
      rtfData: replaceFormattedText ? rtfData : rtfData ?? this.rtfData,
      tags: tags ?? this.tags,
      source: source,
      pinned: pinned ?? this.pinned,
      enabled: enabled ?? this.enabled,
      activation: activation ?? this.activation,
      sortOrder: sortOrder ?? this.sortOrder,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toHistoryJson({required bool includeContent}) {
    return <String, Object?>{
      'id': id,
      'title': title,
      'group': group,
      'groups': groupNames,
      'classification': kind.name,
      'tags': tags,
      'pinned': pinned,
      'enabled': enabled,
      'activation': activation,
      'sensitive': sensitive,
      'contentCharacterCount': content.length,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (source != null) 'source': source,
      if (includeContent) 'content': content,
    };
  }

  Map<String, Object?> toResourceApiJson() {
    return <String, Object?>{
      'id': id,
      'type': 'clipboard',
      'group': group,
      'groups': groupNames,
      'title': title,
      'content': content,
      'tags': tags,
      'pinned': pinned,
      'enabled': enabled,
      'activation': activation,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'updatedAt': updatedAt.toUtc().toIso8601String(),
      if (source != null) 'source': source,
    };
  }
}

bool isAutomaticClipboardGroup(String value) =>
    _automaticClipboardGroups.contains(value.trim().toLowerCase());

const Set<String> _automaticClipboardGroups = <String>{
  'archive',
  'clipboard',
  'code',
  'commands',
  'email',
  'files',
  'images',
  'json',
  'paths',
  'sensitive',
  'urls',
};

List<String> _normalizedGroups(Iterable<String> values) {
  final Set<String> seen = <String>{};
  return values
      .map((String value) => value.trim())
      .where(
        (String value) => value.isNotEmpty && seen.add(value.toLowerCase()),
      )
      .toList(growable: false);
}
