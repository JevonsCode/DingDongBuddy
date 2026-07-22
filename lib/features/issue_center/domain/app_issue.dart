enum AppIssueSeverity { warning, error }

enum AppIssueKind {
  skillNameConflict,
  managedSkillNameConflict,
  pluginSkillNameConflict,
  skillPackageMissing,
  invalidSkill,
  invalidProjectPath,
  invalidMcp,
  invalidAgentConfig,
  syncFailed,
}

/// One actionable problem detected while applying DingDong resources.
final class AppIssue {
  const AppIssue({
    required this.id,
    required this.source,
    required this.kind,
    required this.severity,
    required this.title,
    required this.detail,
    this.resourceId,
    this.resourceTitle,
    this.clientName,
    this.targetPath,
  });

  factory AppIssue.fromJson(Map<Object?, Object?> values) => AppIssue(
    id: values['id']! as String,
    source: values['source']! as String,
    kind: AppIssueKind.values.byName(values['kind']! as String),
    severity: AppIssueSeverity.values.byName(values['severity']! as String),
    title: values['title']! as String,
    detail: values['detail']! as String,
    resourceId: values['resourceId'] as String?,
    resourceTitle: values['resourceTitle'] as String?,
    clientName: values['clientName'] as String?,
    targetPath: values['targetPath'] as String?,
  );

  final String id;
  final String source;
  final AppIssueKind kind;
  final AppIssueSeverity severity;
  final String title;
  final String detail;
  final String? resourceId;
  final String? resourceTitle;
  final String? clientName;
  final String? targetPath;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'source': source,
    'kind': kind.name,
    'severity': severity.name,
    'title': title,
    'detail': detail,
    'resourceId': resourceId,
    'resourceTitle': resourceTitle,
    'clientName': clientName,
    'targetPath': targetPath,
  };
}

/// Preserves structured sync failures across transactional rollback.
final class AppIssueException implements Exception {
  const AppIssueException(this.issues);

  final List<AppIssue> issues;

  @override
  String toString() => issues.isEmpty
      ? 'DingDong resource synchronization failed.'
      : issues.first.detail;
}
