/// Project context passed by an Agent when it asks DingDong for resources.
final class TriggerContext {
  const TriggerContext({this.projectPath = '', this.repositoryUrl = ''});

  final String projectPath;
  final String repositoryUrl;
}

enum TriggerRuleField {
  projectPath,
  repositoryUrl;

  String valueFrom(TriggerContext context) => switch (this) {
    TriggerRuleField.projectPath => context.projectPath,
    TriggerRuleField.repositoryUrl => context.repositoryUrl,
  };
}

enum TriggerRuleOperator { equals, contains }

/// One project-aware condition inside a reusable trigger group.
final class TriggerRule {
  TriggerRule({
    required this.field,
    required this.operator,
    required String value,
  }) : value = value.trim();

  factory TriggerRule.fromJson(Map<String, Object?> json) {
    return TriggerRule(
      field: TriggerRuleField.values.byName(json['field'] as String),
      operator: TriggerRuleOperator.values.byName(json['operator'] as String),
      value: json['value'] as String,
    );
  }

  final TriggerRuleField field;
  final TriggerRuleOperator operator;
  final String value;

  bool matches(TriggerContext context) {
    if (value.isEmpty) {
      return false;
    }
    final String candidate = _normalized(field, field.valueFrom(context));
    final String expected = _normalized(field, value);
    if (candidate.isEmpty || expected.isEmpty) {
      return false;
    }
    return switch (operator) {
      TriggerRuleOperator.equals => candidate == expected,
      TriggerRuleOperator.contains => candidate.contains(expected),
    };
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'field': field.name,
    'operator': operator.name,
    'value': value,
  };

  @override
  bool operator ==(Object other) =>
      other is TriggerRule &&
      field == other.field &&
      operator == other.operator &&
      value == other.value;

  @override
  int get hashCode => Object.hash(field, operator, value);
}

/// A named collection of OR-ed project conditions.
final class TriggerGroup {
  TriggerGroup({
    required this.id,
    required String name,
    required List<TriggerRule> rules,
    required this.createdAt,
    required this.updatedAt,
  }) : name = name.trim(),
       rules = List<TriggerRule>.unmodifiable(rules);

  factory TriggerGroup.fromJson(Map<String, Object?> json) {
    return TriggerGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      rules: (json['rules'] as List<Object?>? ?? const <Object?>[])
          .map(
            (Object? value) =>
                TriggerRule.fromJson(value as Map<String, Object?>),
          )
          .toList(growable: false),
      createdAt: DateTime.parse(json['createdAt'] as String).toUtc(),
      updatedAt: DateTime.parse(json['updatedAt'] as String).toUtc(),
    );
  }

  final String id;
  final String name;
  final List<TriggerRule> rules;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool matches(TriggerContext context) =>
      rules.any((TriggerRule rule) => rule.matches(context));

  TriggerGroup copyWith({
    String? name,
    List<TriggerRule>? rules,
    DateTime? updatedAt,
  }) {
    return TriggerGroup(
      id: id,
      name: name ?? this.name,
      rules: rules ?? this.rules,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'rules': rules.map((TriggerRule rule) => rule.toJson()).toList(),
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
  };

  @override
  bool operator ==(Object other) =>
      other is TriggerGroup &&
      id == other.id &&
      name == other.name &&
      _ruleListEquals(rules, other.rules) &&
      createdAt == other.createdAt &&
      updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      Object.hash(id, name, Object.hashAll(rules), createdAt, updatedAt);
}

String _normalized(TriggerRuleField field, String value) {
  final String trimmed = value.trim().toLowerCase();
  if (field == TriggerRuleField.repositoryUrl) {
    return trimmed;
  }
  final String normalized = trimmed.replaceAll(r'\', '/');
  return normalized.length > 1
      ? normalized.replaceFirst(RegExp(r'/+$'), '')
      : normalized;
}

bool _ruleListEquals(List<TriggerRule> left, List<TriggerRule> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index += 1) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}
