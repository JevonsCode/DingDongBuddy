import 'dart:async';

import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/domain/issue_cleanup.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const AppIssue issue = AppIssue(
    id: 'duplicate',
    source: agentResourceSyncIssueSource,
    kind: AppIssueKind.duplicateMcp,
    severity: AppIssueSeverity.warning,
    title: 'Duplicate',
    detail: 'Duplicate',
    resourceId: 'figma',
    resourceTitle: 'Figma',
    duplicateEntryName: 'Figma',
    targetPath: '/tmp/cursor.json',
  );

  testWidgets(
    'cleanup defaults to backup and exposes completion path after refresh',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      bool deleted = false;
      final Completer<IssueCleanupResult> pending =
          Completer<IssueCleanupResult>();
      final IssueCenterController controller = IssueCenterController(
        inspector: () async => deleted ? <AppIssue>[] : <AppIssue>[issue],
      );
      addTearDown(controller.dispose);
      controller.replaceSource(agentResourceSyncIssueSource, <AppIssue>[issue]);
      controller.setResolver((
        _, {
        required bool backup,
        required IssueCleanupChoice choice,
      }) async {
        expect(backup, isTrue);
        expect(choice, IssueCleanupChoice.externalMcp);
        final IssueCleanupResult result = await pending.future;
        deleted = true;
        return result;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: IssueCenterScreen(
            controller: controller,
            onOpenResource: (_) {},
          ),
        ),
      );
      await tester.tap(find.byKey(const Key('issue-resolve-duplicate')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('duplicate-cleanup-backup')),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.byKey(const Key('duplicate-cleanup-confirm')));
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const Key('duplicate-cleanup-confirm')),
            )
            .onPressed,
        isNull,
      );
      pending.complete(
        const IssueCleanupResult(
          backupPath: '/private/Issue Backups/duplicate-one',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('/private/Issue Backups/duplicate-one'), findsOneWidget);
      expect(controller.issues, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('cleanup can skip backup and keeps errors visible for retry', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final IssueCenterController controller = IssueCenterController();
    addTearDown(controller.dispose);
    controller.replaceSource(agentResourceSyncIssueSource, <AppIssue>[issue]);
    controller.setResolver((
      _, {
      required bool backup,
      required IssueCleanupChoice choice,
    }) async {
      expect(backup, isFalse);
      throw StateError('The duplicate changed.');
    });
    await tester.pumpWidget(
      MaterialApp(
        home: IssueCenterScreen(controller: controller, onOpenResource: (_) {}),
      ),
    );
    await tester.tap(find.byKey(const Key('issue-resolve-duplicate')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('duplicate-cleanup-backup')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('duplicate-cleanup-confirm')));
    await tester.pumpAndSettle();
    expect(find.textContaining('The duplicate changed.'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.byKey(const Key('duplicate-cleanup-confirm')),
          )
          .onPressed,
      isNotNull,
    );
    expect(controller.issues, hasLength(1));
    expect(tester.takeException(), isNull);
  });
}
