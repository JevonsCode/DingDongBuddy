import 'package:dingdong/core/models/clipboard_record.dart';

/// An ordered, user-editable clipboard category.
///
/// Every populated condition must match. The view model assigns a record to
/// the first enabled matching rule, mirroring common clipboard managers'
/// ordered automatic-command model without exposing arbitrary scripts.
final class ClipboardCategoryRule {
  const ClipboardCategoryRule({
    required this.id,
    required this.name,
    this.enabled = true,
    this.kinds = const <ClipboardKind>{},
    this.contentPattern = '',
    this.sourcePattern = '',
    this.minCharacters,
    this.maxCharacters,
    this.caseSensitive = false,
  });

  factory ClipboardCategoryRule.fromJson(Map<String, Object?> json) {
    return ClipboardCategoryRule(
      id: json['id'] as String,
      name: json['name'] as String,
      enabled: json['enabled'] as bool? ?? true,
      kinds: (json['kinds'] as List<Object?>? ?? const <Object?>[])
          .map((Object? value) => ClipboardKind.values.byName(value as String))
          .toSet(),
      contentPattern: json['contentPattern'] as String? ?? '',
      sourcePattern: json['sourcePattern'] as String? ?? '',
      minCharacters: json['minCharacters'] as int?,
      maxCharacters: json['maxCharacters'] as int?,
      caseSensitive: json['caseSensitive'] as bool? ?? false,
    );
  }

  static List<ClipboardCategoryRule> defaults() =>
      const <ClipboardCategoryRule>[
        ClipboardCategoryRule(
          id: 'links',
          name: 'Links',
          kinds: <ClipboardKind>{ClipboardKind.url},
        ),
        ClipboardCategoryRule(
          id: 'images',
          name: 'Images',
          kinds: <ClipboardKind>{ClipboardKind.image},
        ),
        ClipboardCategoryRule(
          id: 'files',
          name: 'Files',
          kinds: <ClipboardKind>{ClipboardKind.file},
        ),
        ClipboardCategoryRule(
          id: 'text',
          name: 'Text',
          kinds: <ClipboardKind>{
            ClipboardKind.text,
            ClipboardKind.command,
            ClipboardKind.code,
            ClipboardKind.json,
            ClipboardKind.path,
            ClipboardKind.email,
          },
        ),
      ];

  final String id;
  final String name;
  final bool enabled;
  final Set<ClipboardKind> kinds;
  final String contentPattern;
  final String sourcePattern;
  final int? minCharacters;
  final int? maxCharacters;
  final bool caseSensitive;

  String? get validationError {
    if (id.trim().isEmpty || name.trim().isEmpty) {
      return 'Category name is required.';
    }
    if (minCharacters != null && minCharacters! < 0) {
      return 'Minimum length cannot be negative.';
    }
    if (maxCharacters != null && maxCharacters! < 0) {
      return 'Maximum length cannot be negative.';
    }
    if (minCharacters != null &&
        maxCharacters != null &&
        minCharacters! > maxCharacters!) {
      return 'Minimum length cannot exceed maximum length.';
    }
    for (final String pattern in <String>[contentPattern, sourcePattern]) {
      if (pattern.trim().isEmpty) {
        continue;
      }
      try {
        RegExp(pattern, caseSensitive: caseSensitive, multiLine: true);
      } on FormatException {
        return 'Regular expression is invalid.';
      }
    }
    return null;
  }

  bool matches(ClipboardRecord record) {
    if (!enabled || validationError != null) {
      return false;
    }
    if (kinds.isNotEmpty && !kinds.contains(record.kind)) {
      return false;
    }
    if (minCharacters != null && record.content.length < minCharacters!) {
      return false;
    }
    if (maxCharacters != null && record.content.length > maxCharacters!) {
      return false;
    }
    if (!_matchesPattern(contentPattern, record.content)) {
      return false;
    }
    if (!_matchesPattern(sourcePattern, record.source ?? '')) {
      return false;
    }
    return true;
  }

  bool _matchesPattern(String pattern, String value) {
    if (pattern.trim().isEmpty) {
      return true;
    }
    return RegExp(
      pattern,
      caseSensitive: caseSensitive,
      multiLine: true,
    ).hasMatch(value);
  }

  ClipboardCategoryRule copyWith({
    String? id,
    String? name,
    bool? enabled,
    Set<ClipboardKind>? kinds,
    String? contentPattern,
    String? sourcePattern,
    int? minCharacters,
    int? maxCharacters,
    bool clearMinCharacters = false,
    bool clearMaxCharacters = false,
    bool? caseSensitive,
  }) {
    return ClipboardCategoryRule(
      id: id ?? this.id,
      name: name ?? this.name,
      enabled: enabled ?? this.enabled,
      kinds: kinds ?? this.kinds,
      contentPattern: contentPattern ?? this.contentPattern,
      sourcePattern: sourcePattern ?? this.sourcePattern,
      minCharacters: clearMinCharacters
          ? null
          : minCharacters ?? this.minCharacters,
      maxCharacters: clearMaxCharacters
          ? null
          : maxCharacters ?? this.maxCharacters,
      caseSensitive: caseSensitive ?? this.caseSensitive,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'enabled': enabled,
    'kinds': kinds.map((ClipboardKind kind) => kind.name).toList(),
    if (contentPattern.isNotEmpty) 'contentPattern': contentPattern,
    if (sourcePattern.isNotEmpty) 'sourcePattern': sourcePattern,
    if (minCharacters != null) 'minCharacters': minCharacters,
    if (maxCharacters != null) 'maxCharacters': maxCharacters,
    'caseSensitive': caseSensitive,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipboardCategoryRule &&
          id == other.id &&
          name == other.name &&
          enabled == other.enabled &&
          _setEquals(kinds, other.kinds) &&
          contentPattern == other.contentPattern &&
          sourcePattern == other.sourcePattern &&
          minCharacters == other.minCharacters &&
          maxCharacters == other.maxCharacters &&
          caseSensitive == other.caseSensitive;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    enabled,
    Object.hashAll(kinds),
    contentPattern,
    sourcePattern,
    minCharacters,
    maxCharacters,
    caseSensitive,
  );
}

bool _setEquals<T>(Set<T> left, Set<T> right) =>
    left.length == right.length && left.containsAll(right);
