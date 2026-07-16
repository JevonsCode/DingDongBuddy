import 'package:dingdong/features/library/domain/resource_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SkillConfiguration', () {
    test('parses and preserves a SKILL.md document', () {
      const String document = '''---
name: release-helper
description: Prepare a safe release
allowed-tools: Read Grep
---

# Release helper

Run checks before publishing.''';

      final SkillConfiguration configuration = SkillConfiguration.parse(
        document,
        fallbackName: 'fallback',
      );

      expect(configuration.name, 'release-helper');
      expect(configuration.description, 'Prepare a safe release');
      expect(configuration.instructions, contains('Run checks'));

      final String encoded = configuration
          .copyWith(
            name: 'updated-release',
            description: 'Use when preparing a release',
          )
          .encode();
      expect(encoded, contains('name: updated-release'));
      expect(encoded, contains('description: "Use when preparing a release"'));
      expect(encoded, contains('allowed-tools: Read Grep'));
      expect(encoded, contains('Run checks before publishing.'));
    });

    test('parses folded and literal YAML description blocks', () {
      final SkillConfiguration folded = SkillConfiguration.parse('''---
name: user-taste
description: >-
  Use when product or design decisions
  should follow this user's preferences.
---

# User Taste''', fallbackName: 'fallback');
      final SkillConfiguration literal = SkillConfiguration.parse('''---
name: release-helper
description: |
  Use before publishing.
  Run every check.
---

# Release''', fallbackName: 'fallback');

      expect(
        folded.description,
        "Use when product or design decisions should follow this user's preferences.",
      );
      expect(literal.description, 'Use before publishing.\nRun every check.');
    });

    test(
      'validates online Skill frontmatter against the Agent Skills rules',
      () {
        expect(
          () => SkillConfiguration.parseOnline('''---
name: user-taste
description: Use when applying saved preferences.
---

# User Taste'''),
          returnsNormally,
        );
        expect(
          () => SkillConfiguration.parseOnline('''---
name: User Taste
description: Use when applying saved preferences.
---'''),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => SkillConfiguration.parseOnline('''---
name: user--taste
description: Use when applying saved preferences.
---'''),
          throwsA(isA<FormatException>()),
        );
        expect(
          () => SkillConfiguration.parseOnline('''---
name: user-taste
description:
---'''),
          throwsA(isA<FormatException>()),
        );
      },
    );

    test('turns legacy plain instructions into a valid skill document', () {
      final SkillConfiguration configuration = SkillConfiguration.parse(
        'Review the changed files.',
        fallbackName: 'Code Review',
      );

      expect(configuration.name, 'code-review');
      expect(configuration.instructions, 'Review the changed files.');
      expect(configuration.encode(), startsWith('---\nname: code-review'));
    });

    test('creates a Cursor-style editable SKILL.md template', () {
      final String document = SkillConfiguration.template(
        'User Taste',
      ).encode();

      expect(document, startsWith('---\nname: user-taste'));
      expect(document, contains('description: ""'));
      expect(document, contains('# User Taste'));
    });
  });

  group('McpConfiguration', () {
    test('parses and encodes a local STDIO server', () {
      final McpConfiguration configuration = McpConfiguration.parse('''{
  "type": "stdio",
  "command": "npx",
  "args": ["-y", "server"],
  "env": {"TOKEN": "value"}
}''');

      expect(configuration.transport, McpTransport.stdio);
      expect(configuration.command, 'npx');
      expect(configuration.arguments, <String>['-y', 'server']);
      expect(configuration.environment, <String, String>{'TOKEN': 'value'});
      expect(configuration.encode(), contains('"command": "npx"'));
    });

    test('parses a nested Cursor or Claude MCP server entry', () {
      final McpConfiguration configuration = McpConfiguration.parse('''{
  "mcpServers": {
    "dingdong": {
      "command": "/Applications/DingDong.app/Contents/MCP/dingdong_mcp",
      "args": []
    }
  }
}''');

      expect(configuration.transport, McpTransport.stdio);
      expect(configuration.detectedName, 'dingdong');
      expect(configuration.command, contains('DingDong.app'));
    });

    test('parses and encodes a Streamable HTTP server', () {
      final McpConfiguration configuration = McpConfiguration.parse('''{
  "type": "streamable-http",
  "url": "https://mcp.example.com/mcp",
  "headers": {"X-Region": "cn"},
  "bearerTokenEnvVar": "MCP_TOKEN"
}''');

      expect(configuration.transport, McpTransport.streamableHttp);
      expect(configuration.url, 'https://mcp.example.com/mcp');
      expect(configuration.headers, <String, String>{'X-Region': 'cn'});
      expect(configuration.tokenEnvironmentVariable, 'MCP_TOKEN');
      expect(configuration.encode(), contains('"type": "streamable-http"'));
    });

    test('uses friendly fallbacks for a command, URL, and raw config', () {
      expect(
        McpConfiguration.parse('uvx local-mcp').transport,
        McpTransport.stdio,
      );
      expect(
        McpConfiguration.parse('https://mcp.example.com/mcp').transport,
        McpTransport.streamableHttp,
      );
      final McpConfiguration raw = McpConfiguration.parse('{broken json');
      expect(raw.transport, McpTransport.raw);
      expect(raw.encode(), '{broken json');
    });

    test('parses line-oriented environment and header values', () {
      expect(parseConfigurationPairs('A=1\nB = two\ninvalid'), <String, String>{
        'A': '1',
        'B': 'two',
      });
      expect(
        formatConfigurationPairs(<String, String>{'A': '1', 'B': 'two'}),
        'A=1\nB=two',
      );
    });
  });
}
