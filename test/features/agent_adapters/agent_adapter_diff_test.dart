import 'package:dingdong/features/agent_adapters/domain/agent_adapter_diff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('line diff keeps line numbers for additions and removals', () {
    final List<AgentAdapterDiffLine> diff = diffAgentAdapterDocuments(
      'id: codex\nformat: old\n',
      'id: codex\nformat: new\nprompt: enabled\n',
    );

    expect(
      diff.map((AgentAdapterDiffLine line) => line.kind),
      <AgentAdapterDiffKind>[
        AgentAdapterDiffKind.unchanged,
        AgentAdapterDiffKind.removed,
        AgentAdapterDiffKind.added,
        AgentAdapterDiffKind.added,
      ],
    );
    expect(diff[1].previousLine, 2);
    expect(diff[1].currentLine, isNull);
    expect(diff[2].previousLine, isNull);
    expect(diff[2].currentLine, 2);
  });
}
