import 'package:dingdong/features/agent_api/domain/agent_bridge_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prompt-file guidance keeps the complete bridge protocol', () {
    for (final String required in <String>[
      'dingdong_bridge',
      'expand="prompts"',
      'required instruction',
      'authoritative Prompt snapshot',
      'authoritative dynamic-delivery Skill catalog',
      'active.skillSuppressions',
      'duplicate-name conflict',
      'dingdong_load_skill',
      'dingdong_confirm_mcp_use',
      'dingdong_read_skill_file',
      'MCP entries are tool references',
      'conversation.visible',
      'single Markdown text line',
      'keep DingDong as text',
      'symbols and lineToken values returned by DingDong',
      'conversation.presentations.ansi.line',
      'merged plain-text tokens',
      'confirmedUse',
      'MCP marker means called',
      'Prompt items remain unmarked',
      'same mergeKey',
      'must never be displayed',
      'does not claim that every instruction was followed',
      'dingdong_install_skill',
      'dingdong_create_resource',
      'dingdong_update_resource',
      'strict project scope',
      'completion hook',
      'dingdong_notify',
    ]) {
      expect(dingDongAgentBridgeGuidance, contains(required));
    }
  });

  test('MCP handshake instructions fit host truncation limits', () {
    expect(dingDongMcpInstructions.length, lessThan(2048));
    expect(dingDongMcpInstructions, isNot(contains('iframe')));
  });
}
