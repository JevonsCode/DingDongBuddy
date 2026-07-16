import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/library/domain/resource_card_presentation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final DateTime now = DateTime.utc(2026, 7, 17);

  test('Skill cards use SKILL.md name and description', () {
    final ResourceCardPresentation
    display = ResourceCardPresentation.fromResource(
      Resource(
        id: 'skill',
        type: ResourceType.skill,
        title: '',
        content: '''---
name: user-taste
description: Use when product decisions need saved preferences.
---

# User Taste

Apply the user's saved preferences.''',
        updateUrl:
            'https://github.com/JevonsCode/codex-skills/tree/main/skills/user-taste',
        createdAt: now,
        updatedAt: now,
      ),
    );

    expect(display.title, 'user-taste');
    expect(
      display.summary,
      'Use when product decisions need saved preferences.',
    );
    expect(display.variantLabel, 'Online');
  });

  test(
    'Skill cards fall back to instructions without exposing frontmatter',
    () {
      final ResourceCardPresentation display =
          ResourceCardPresentation.fromResource(
            Resource(
              id: 'skill',
              type: ResourceType.skill,
              title: 'release-helper',
              content: '''---
name: release-helper
description: ""
---

# Release

Run checks before publishing.''',
              createdAt: now,
              updatedAt: now,
            ),
          );

      expect(display.title, 'release-helper');
      expect(display.summary, contains('Run checks before publishing.'));
      expect(display.summary, isNot(contains('name:')));
      expect(display.variantLabel, 'Local');
    },
  );

  test('legacy Skills without frontmatter preserve their stored title', () {
    final ResourceCardPresentation display =
        ResourceCardPresentation.fromResource(
          Resource(
            id: 'legacy-skill',
            type: ResourceType.skill,
            title: 'Release skill',
            content: 'Run release checks.',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(display.title, 'Release skill');
    expect(display.summary, 'Run release checks.');
  });

  test('MCP cards summarize the configured transport', () {
    final ResourceCardPresentation display =
        ResourceCardPresentation.fromResource(
          Resource(
            id: 'mcp',
            type: ResourceType.mcp,
            title: '',
            content: '''{
  "mcpServers": {
    "dingdong": {
      "type": "stdio",
      "command": "/Applications/DingDong.app/Contents/MCP/bundle/bin/dingdong_mcp"
    }
  }
}''',
            createdAt: now,
            updatedAt: now,
          ),
        );

    expect(display.title, 'dingdong');
    expect(display.summary, startsWith('STDIO · '));
    expect(display.summary, contains('/Applications/DingDong.app'));
    expect(display.variantLabel, 'STDIO');
  });
}
