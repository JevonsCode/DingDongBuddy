enum AgentAdapterDiffKind { unchanged, added, removed }

final class AgentAdapterDiffLine {
  const AgentAdapterDiffLine({
    required this.kind,
    required this.text,
    this.previousLine,
    this.currentLine,
  });

  final AgentAdapterDiffKind kind;
  final String text;
  final int? previousLine;
  final int? currentLine;
}

/// Produces a small, stable line diff suitable for human-readable YAML.
List<AgentAdapterDiffLine> diffAgentAdapterDocuments(
  String previous,
  String current,
) {
  final List<String> before = _lines(previous);
  final List<String> after = _lines(current);
  final List<List<int>> longest = List<List<int>>.generate(
    before.length + 1,
    (_) => List<int>.filled(after.length + 1, 0),
  );
  for (int left = before.length - 1; left >= 0; left -= 1) {
    for (int right = after.length - 1; right >= 0; right -= 1) {
      longest[left][right] = before[left] == after[right]
          ? longest[left + 1][right + 1] + 1
          : longest[left + 1][right] >= longest[left][right + 1]
          ? longest[left + 1][right]
          : longest[left][right + 1];
    }
  }

  final List<AgentAdapterDiffLine> result = <AgentAdapterDiffLine>[];
  int left = 0;
  int right = 0;
  while (left < before.length || right < after.length) {
    if (left < before.length &&
        right < after.length &&
        before[left] == after[right]) {
      result.add(
        AgentAdapterDiffLine(
          kind: AgentAdapterDiffKind.unchanged,
          text: before[left],
          previousLine: left + 1,
          currentLine: right + 1,
        ),
      );
      left += 1;
      right += 1;
      continue;
    }
    if (left < before.length &&
        (right == after.length ||
            longest[left + 1][right] >= longest[left][right + 1])) {
      result.add(
        AgentAdapterDiffLine(
          kind: AgentAdapterDiffKind.removed,
          text: before[left],
          previousLine: left + 1,
        ),
      );
      left += 1;
      continue;
    }
    result.add(
      AgentAdapterDiffLine(
        kind: AgentAdapterDiffKind.added,
        text: after[right],
        currentLine: right + 1,
      ),
    );
    right += 1;
  }
  return result;
}

List<String> _lines(String document) {
  final List<String> lines = document.replaceAll('\r\n', '\n').split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  return lines;
}
