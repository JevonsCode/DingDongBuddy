import 'package:dingdong/features/issue_center/domain/app_issue.dart';

enum IssueCleanupChoice { externalMcp, dingDongResource }

final class IssueCleanupResult {
  const IssueCleanupResult({this.backupPath});

  /// Private local directory containing the deleted copy and restore notes.
  final String? backupPath;
}

typedef IssueResolver =
    Future<IssueCleanupResult> Function(
      AppIssue issue, {
      required bool backup,
      required IssueCleanupChoice choice,
    });
