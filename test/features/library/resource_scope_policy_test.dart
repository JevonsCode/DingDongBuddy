import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/domain/resource_scope_policy.dart';
import 'package:dingdong/features/library/domain/trigger_group.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'native MCP sync preserves runtime scopes and honors source-only routing',
    () {
      final DateTime now = DateTime.utc(2026, 8, 24);
      Resource mcp(String groupId) => Resource(
        id: 'mcp-$groupId',
        type: ResourceType.mcp,
        title: 'Scoped MCP',
        content: '{"command":"scoped-mcp"}',
        triggerGroupIds: <String>[groupId],
        createdAt: now,
        updatedAt: now,
      );
      TriggerGroup group(String id, TriggerRule rule) => TriggerGroup(
        id: id,
        name: id,
        rules: <TriggerRule>[rule],
        createdAt: now,
        updatedAt: now,
      );
      final Map<String, TriggerGroup> groups = <String, TriggerGroup>{
        'project': group(
          'project',
          TriggerRule(
            field: TriggerRuleField.projectPath,
            operator: TriggerRuleOperator.contains,
            value: 'dingdong',
          ),
        ),
        'repository': group(
          'repository',
          TriggerRule(
            field: TriggerRuleField.repositoryUrl,
            operator: TriggerRuleOperator.contains,
            value: 'DingDongBuddy',
          ),
        ),
        'codex': group(
          'codex',
          TriggerRule(
            field: TriggerRuleField.source,
            operator: TriggerRuleOperator.equals,
            value: 'Codex',
          ),
        ),
      };

      expect(
        resourceCanSyncToAgentSource(mcp('project'), 'Codex', groups),
        isTrue,
      );
      expect(
        resourceCanSyncToAgentSource(mcp('project'), 'Claude Code', groups),
        isTrue,
      );
      expect(
        resourceCanSyncToAgentSource(mcp('repository'), 'Cursor', groups),
        isTrue,
      );
      expect(
        resourceCanSyncToAgentSource(mcp('codex'), 'Codex', groups),
        isTrue,
      );
      expect(
        resourceCanSyncToAgentSource(mcp('codex'), 'Cursor', groups),
        isFalse,
      );
    },
  );

  test(
    'strict Skill scope fails closed when its trigger definition drifts',
    () {
      final Directory first = Directory.systemTemp.createTempSync(
        'dingdong-scope-first-',
      );
      final Directory second = Directory.systemTemp.createTempSync(
        'dingdong-scope-second-',
      );
      addTearDown(() => first.deleteSync(recursive: true));
      addTearDown(() => second.deleteSync(recursive: true));
      final String firstPath = first.resolveSymbolicLinksSync();
      final String secondPath = second.resolveSymbolicLinksSync();
      final DateTime now = DateTime.utc(2026, 7, 29);
      final Resource skill = Resource(
        id: 'reviewer',
        type: ResourceType.skill,
        title: 'Reviewer',
        content: '---\nname: reviewer\ndescription: Review code\n---\n',
        strictProjectSkill: true,
        triggerGroupIds: const <String>['project'],
        skillProjectPaths: <String>[firstPath],
        createdAt: now,
        updatedAt: now,
      );
      TriggerGroup group(TriggerRule rule) => TriggerGroup(
        id: 'project',
        name: 'Project',
        rules: <TriggerRule>[rule],
        createdAt: now,
        updatedAt: now,
      );
      final TriggerContext context = TriggerContext(projectPath: firstPath);

      expect(
        resourceMatchesScope(skill, context, <String, TriggerGroup>{
          'project': group(
            TriggerRule(
              field: TriggerRuleField.projectPath,
              operator: TriggerRuleOperator.equals,
              value: firstPath,
            ),
          ),
        }),
        isTrue,
      );
      expect(
        resourceMatchesScope(skill, context, <String, TriggerGroup>{
          'project': group(
            TriggerRule(
              field: TriggerRuleField.projectPath,
              operator: TriggerRuleOperator.contains,
              value: 'dingdong-scope',
            ),
          ),
        }),
        isFalse,
      );
      expect(
        resourceMatchesScope(
          skill,
          TriggerContext(projectPath: secondPath),
          <String, TriggerGroup>{
            'project': group(
              TriggerRule(
                field: TriggerRuleField.projectPath,
                operator: TriggerRuleOperator.equals,
                value: secondPath,
              ),
            ),
          },
        ),
        isFalse,
      );
    },
  );
}
