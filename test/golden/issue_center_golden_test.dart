import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/activity/ui/activity_controller.dart';
import 'package:dingdong/features/clipboard/data/clipboard_repository.dart';
import 'package:dingdong/features/clipboard/ui/clipboard_view_model.dart';
import 'package:dingdong/features/issue_center/domain/app_issue.dart';
import 'package:dingdong/features/issue_center/ui/issue_center_controller.dart';
import 'package:dingdong/features/library/data/resource_repository.dart';
import 'package:dingdong/features/library/domain/resource_manager_launcher.dart';
import 'package:dingdong/features/library/ui/library_view_model.dart';
import 'package:dingdong/features/library/ui/resource_manager_app.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'resource manager gives Agent issues a clear full-size workspace',
    (WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1080, 752);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);
      const MethodChannel channels = MethodChannel(
        'mixin.one/desktop_multi_window/channels',
      );
      const MethodChannel registry = MethodChannel(
        'mixin.one/desktop_multi_window',
      );
      final TestDefaultBinaryMessenger messenger =
          tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(channels, (_) async => null);
      messenger.setMockMethodCallHandler(registry, (MethodCall call) async {
        if (call.method == 'getWindowDefinition') {
          return <String, String>{
            'windowId': 'issue-center-golden',
            'windowArgument': '',
          };
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(channels, null);
        messenger.setMockMethodCallHandler(registry, null);
      });

      final LibraryViewModel library = LibraryViewModel(
        InMemoryResourceStore(),
      );
      await library.load();
      final ClipboardViewModel clipboard = ClipboardViewModel(
        InMemoryClipboardStore(),
      )..load();
      final ActivityController activity = ActivityController();
      addTearDown(activity.dispose);
      final IssueCenterController issues = IssueCenterController();
      addTearDown(issues.dispose);
      issues.replaceSource(agentResourceSyncIssueSource, const <AppIssue>[
        AppIssue(
          id: 'skill-conflict',
          source: agentResourceSyncIssueSource,
          kind: AppIssueKind.skillNameConflict,
          severity: AppIssueSeverity.error,
          title: 'Skill name conflict',
          detail: 'Existing Skill preserved.',
          resourceId: 'reviewer',
          resourceTitle: 'code-review',
          clientName: 'Claude Code',
          targetPath: '/Users/demo/.claude/skills/code-review',
        ),
        AppIssue(
          id: 'managed-conflict',
          source: agentResourceSyncIssueSource,
          kind: AppIssueKind.managedSkillNameConflict,
          severity: AppIssueSeverity.error,
          title: 'DingDong Skills use the same name',
          detail: 'Two resources use one destination.',
          resourceId: 'verification',
          resourceTitle: 'verification-before',
          clientName: 'Codex',
          targetPath: '/Users/demo/.agents/skills/verification-before',
        ),
        AppIssue(
          id: 'mcp-invalid',
          source: agentResourceSyncIssueSource,
          kind: AppIssueKind.invalidAgentConfig,
          severity: AppIssueSeverity.error,
          title: 'Agent config invalid',
          detail: 'Invalid JSON.',
          clientName: 'Cursor',
          targetPath: '/Users/demo/.cursor/mcp.json',
        ),
      ]);

      await tester.pumpWidget(
        ResourceManagerApp(
          viewModel: library,
          clipboardViewModel: clipboard,
          activityController: activity,
          issueCenterController: issues,
          settings: const AppSettings(language: AppLanguagePreference.chinese),
          windowController: WindowController.fromWindowId(
            'issue-center-golden',
          ),
          initialDestination: ResourceManagerDestination.issues,
        ),
      );
      await tester.pumpAndSettle();

      await expectLater(
        find.byKey(const Key('resource-manager-shell')),
        matchesGoldenFile('goldens/issue_center.png'),
      );
    },
    tags: <String>['golden'],
  );
}
