import 'dart:async';

import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:flutter/foundation.dart';

typedef IssueInspector = Future<List<AppIssue>> Function();

/// Aggregates persistent, actionable app problems for the shared issue panel.
final class IssueCenterController extends ChangeNotifier {
  IssueCenterController({this.inspector});

  IssueInspector? inspector;
  final Map<String, List<AppIssue>> _issuesBySource =
      <String, List<AppIssue>>{};
  bool _isChecking = false;

  bool get isChecking => _isChecking;

  List<AppIssue> get issues {
    final List<AppIssue> values = _issuesBySource.values
        .expand((List<AppIssue> source) => source)
        .toList(growable: false);
    values.sort((AppIssue left, AppIssue right) {
      final int severity = right.severity.index.compareTo(left.severity.index);
      if (severity != 0) {
        return severity;
      }
      final int title = left.title.compareTo(right.title);
      return title != 0 ? title : left.id.compareTo(right.id);
    });
    return List<AppIssue>.unmodifiable(values);
  }

  int get count => issues.length;

  void setInspector(IssueInspector value) => inspector = value;

  void replaceSource(String source, Iterable<AppIssue> issues) {
    final List<AppIssue> next = issues.toList(growable: false);
    if (next.isEmpty) {
      _issuesBySource.remove(source);
    } else {
      _issuesBySource[source] = next;
    }
    notifyListeners();
  }

  Future<void> refresh() async {
    final IssueInspector? inspect = inspector;
    if (inspect == null || _isChecking) {
      return;
    }
    _isChecking = true;
    notifyListeners();
    try {
      replaceSource(agentResourceSyncIssueSource, await inspect());
    } on Object catch (error) {
      replaceSource(agentResourceSyncIssueSource, <AppIssue>[
        AppIssue(
          id: 'syncFailed:inspection',
          source: agentResourceSyncIssueSource,
          kind: AppIssueKind.syncFailed,
          severity: AppIssueSeverity.error,
          title: 'Agent resource check failed',
          detail: error.toString(),
        ),
      ]);
    } finally {
      _isChecking = false;
      notifyListeners();
    }
  }
}

const String agentResourceSyncIssueSource = 'agent-resource-sync';
const String agentResourceIssuesChangedMethod = 'agent_resource_issues_changed';
const String agentResourceIssuesRequestedMethod =
    'agent_resource_issues_requested';
