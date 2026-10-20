import 'dart:async';

import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/domain/issue_cleanup.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('issues preserve structured fields across window transport', () {
    const AppIssue issue = AppIssue(
      id: 'skill-name:one:/tmp/code-review',
      source: agentResourceSyncIssueSource,
      kind: AppIssueKind.skillNameConflict,
      severity: AppIssueSeverity.error,
      title: 'Skill name conflict',
      detail: 'Existing Skill preserved.',
      resourceId: 'one',
      resourceTitle: 'code-review',
      clientName: 'Claude Code',
      targetPath: '/tmp/code-review',
    );

    final AppIssue restored = AppIssue.fromJson(issue.toJson());

    expect(restored.id, issue.id);
    expect(restored.source, issue.source);
    expect(restored.kind, issue.kind);
    expect(restored.severity, issue.severity);
    expect(restored.resourceId, issue.resourceId);
    expect(restored.resourceTitle, issue.resourceTitle);
    expect(restored.clientName, issue.clientName);
    expect(restored.targetPath, issue.targetPath);
  });

  test('keeps issue sources independent and errors first', () {
    final IssueCenterController controller = IssueCenterController();
    addTearDown(controller.dispose);

    controller.replaceSource('warning-source', const <AppIssue>[
      AppIssue(
        id: 'warning',
        source: 'warning-source',
        kind: AppIssueKind.syncFailed,
        severity: AppIssueSeverity.warning,
        title: 'Warning',
        detail: 'Warning detail',
      ),
    ]);
    controller.replaceSource('error-source', const <AppIssue>[
      AppIssue(
        id: 'error',
        source: 'error-source',
        kind: AppIssueKind.skillNameConflict,
        severity: AppIssueSeverity.error,
        title: 'Error',
        detail: 'Error detail',
      ),
    ]);

    expect(controller.issues.map((AppIssue issue) => issue.id), <String>[
      'error',
      'warning',
    ]);

    controller.replaceSource('error-source', const <AppIssue>[]);
    expect(controller.issues.single.id, 'warning');
  });

  test('refresh publishes inspection failures instead of throwing', () async {
    final IssueCenterController controller = IssueCenterController(
      inspector: () => throw StateError('broken inspection'),
    );
    addTearDown(controller.dispose);

    await controller.refresh();

    expect(controller.isChecking, isFalse);
    expect(controller.issues, hasLength(1));
    expect(controller.issues.single.kind, AppIssueKind.syncFailed);
    expect(controller.issues.single.detail, contains('broken inspection'));
  });

  test(
    'cleanup forwards choice and backup then refreshes current issues',
    () async {
      const AppIssue issue = AppIssue(
        id: 'duplicate',
        source: agentResourceSyncIssueSource,
        kind: AppIssueKind.duplicateMcp,
        severity: AppIssueSeverity.warning,
        title: 'Duplicate',
        detail: 'Duplicate',
        resourceId: 'figma',
        duplicateEntryName: 'Figma',
      );
      bool deleted = false;
      final Completer<IssueCleanupResult> pending =
          Completer<IssueCleanupResult>();
      final IssueCenterController controller = IssueCenterController(
        inspector: () async => deleted ? <AppIssue>[] : <AppIssue>[issue],
      );
      addTearDown(controller.dispose);
      controller.setResolver((
        AppIssue selected, {
        required bool backup,
        required IssueCleanupChoice choice,
      }) async {
        expect(selected, same(issue));
        expect(backup, isFalse);
        expect(choice, IssueCleanupChoice.dingDongResource);
        final IssueCleanupResult result = await pending.future;
        deleted = true;
        return result;
      });
      await controller.refresh();
      final Future<IssueCleanupResult> operation = controller.resolve(
        issue,
        backup: false,
        choice: IssueCleanupChoice.dingDongResource,
      );
      expect(controller.resolvingIssueId, issue.id);
      await expectLater(
        controller.resolve(
          issue,
          backup: false,
          choice: IssueCleanupChoice.externalMcp,
        ),
        throwsStateError,
      );
      pending.complete(const IssueCleanupResult());
      await operation;
      expect(controller.resolvingIssueId, isNull);
      expect(controller.issues, isEmpty);
    },
  );

  test('cleanup failures preserve issues and release busy state', () async {
    const AppIssue issue = AppIssue(
      id: 'duplicate',
      source: agentResourceSyncIssueSource,
      kind: AppIssueKind.pluginSkillNameConflict,
      severity: AppIssueSeverity.warning,
      title: 'Duplicate',
      detail: 'Duplicate',
      resourceId: 'skill',
    );
    final IssueCenterController controller = IssueCenterController();
    addTearDown(controller.dispose);
    controller.replaceSource(agentResourceSyncIssueSource, <AppIssue>[issue]);
    controller.setResolver(
      (_, {required backup, required choice}) => throw StateError('changed'),
    );
    await expectLater(
      controller.resolve(
        issue,
        backup: true,
        choice: IssueCleanupChoice.dingDongResource,
      ),
      throwsStateError,
    );
    expect(controller.resolvingIssueId, isNull);
    expect(controller.issues, <AppIssue>[issue]);
  });
}
