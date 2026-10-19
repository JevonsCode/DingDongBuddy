import 'package:dingdong/features/agent_api/domain/agent_bridge_guidance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('prompt-file guidance keeps only the trigger rules', () {
    for (final String required in <String>[
      'dingdong_bridge',
      'required instruction',
      'replaces earlier ones',
      'could not be loaded',
      'dingdong_load_skill',
      'description matches the task',
      'only when the task needs them',
      '`footer`',
      'Never print `statusLine`',
      'dingdong_notify',
    ]) {
      expect(dingDongAgentBridgeGuidance, contains(required));
    }
    // Response details live in the tool descriptions and MCP instructions;
    // this block is resent with every request.
    for (final String removed in <String>[
      'mergeKey',
      'capsule',
      'lineToken',
      'dingdong_confirm_mcp_use',
      'conversation.',
    ]) {
      expect(dingDongAgentBridgeGuidance, isNot(contains(removed)));
    }
    expect(dingDongAgentBridgeGuidance.length, lessThan(800));
  });

  test('MCP handshake instructions fit host truncation limits', () {
    expect(dingDongMcpInstructions.length, lessThan(2048));
    expect(dingDongMcpInstructions, isNot(contains('iframe')));
    expect(dingDongMcpInstructions, isNot(contains('mergeKey')));
  });
}
