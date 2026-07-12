import 'dart:convert';

/// Presentation metadata derived from clipboard text without storing it twice.
final class ClipboardClassification {
  const ClipboardClassification({
    required this.group,
    required this.title,
    required this.tags,
  });

  final String group;
  final String title;
  final List<String> tags;
}

/// Deterministic, local-only clipboard text classifier.
abstract final class ClipboardClassifier {
  static const Set<String> _knownCommands = <String>{
    'flutter',
    'dart',
    'curl',
    'git',
    'swift',
    'npm',
    'pnpm',
    'yarn',
    'node',
    'python',
    'python3',
    'brew',
    'docker',
    'kubectl',
    'gh',
    'ssh',
    'scp',
    'rsync',
    'mkdir',
    'cp',
    'mv',
    'rm',
    'cat',
    'rg',
    'grep',
    'sed',
    'awk',
    'chmod',
    'open',
  };

  static final RegExp _secretAssignment = RegExp(
    r'\b(api[_-]?key|secret|token|password|passwd|pwd|authorization|bearer)\b\s*[:=]\s*\S{8,}',
    caseSensitive: false,
  );
  static final RegExp _email = RegExp(
    r'^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$',
    caseSensitive: false,
  );

  static ClipboardClassification classify(String text) {
    final String trimmed = text.trim();
    final String? sensitiveKind = _sensitiveKind(trimmed);
    if (sensitiveKind != null) {
      return ClipboardClassification(
        group: '',
        title: _sensitiveTitle(sensitiveKind),
        tags: <String>['clipboard', 'sensitive', 'secret', sensitiveKind],
      );
    }
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty) {
      return ClipboardClassification(
        group: '',
        title: _lineTitle(trimmed, maximumLength: 56),
        tags: <String>['clipboard', 'url', 'domain:${uri.host.toLowerCase()}'],
      );
    }
    try {
      final Object? decoded = jsonDecode(trimmed);
      if (decoded is Map<String, Object?> && decoded.isNotEmpty) {
        return ClipboardClassification(
          group: '',
          title: _lineTitle(trimmed),
          tags: const <String>['clipboard', 'text', 'json', 'structured'],
        );
      }
    } on FormatException {
      // Continue with non-JSON classifiers.
    }
    final String firstLine = trimmed.split('\n').first.trim();
    final String firstToken = firstLine.split(RegExp(r'\s+')).first;
    if (_knownCommands.contains(firstToken) || firstLine.startsWith('./')) {
      final String command = firstToken.replaceAll(RegExp(r'^[./]+'), '');
      return ClipboardClassification(
        group: '',
        title: _lineTitle(trimmed),
        tags: <String>[
          'clipboard',
          'text',
          'command',
          command.isEmpty ? 'script' : command,
        ],
      );
    }
    final String lower = trimmed.toLowerCase();
    if (lower.contains('func ') ||
        lower.contains('import swiftui') ||
        lower.contains('import foundation')) {
      return ClipboardClassification(
        group: '',
        title: _lineTitle(trimmed),
        tags: const <String>['clipboard', 'text', 'code', 'swift'],
      );
    }
    if (_email.hasMatch(trimmed)) {
      return ClipboardClassification(
        group: '',
        title: trimmed,
        tags: const <String>['clipboard', 'text', 'email'],
      );
    }
    if (trimmed.startsWith('/') ||
        trimmed.startsWith('~/') ||
        trimmed.startsWith('./') ||
        trimmed.startsWith('../') ||
        RegExp(r'^[A-Za-z]:[\\/]').hasMatch(trimmed)) {
      return ClipboardClassification(
        group: '',
        title: _lineTitle(trimmed),
        tags: const <String>['clipboard', 'text', 'path'],
      );
    }
    return ClipboardClassification(
      group: '',
      title: _lineTitle(trimmed),
      tags: const <String>['clipboard', 'text'],
    );
  }

  static String? _sensitiveKind(String text) {
    if (RegExp(r'-----BEGIN [A-Z ]*PRIVATE KEY-----').hasMatch(text)) {
      return 'private-key';
    }
    if (RegExp(r'\bAKIA[0-9A-Z]{16}\b').hasMatch(text)) {
      return 'aws-key';
    }
    if (RegExp(r'\bgh[pousr]_[A-Za-z0-9_]{24,}\b').hasMatch(text)) {
      return 'github-token';
    }
    if (RegExp(r'\bsk-[A-Za-z0-9_-]{20,}\b').hasMatch(text) ||
        _secretAssignment.hasMatch(text)) {
      return 'api-key';
    }
    return null;
  }
}

String _sensitiveTitle(String kind) {
  return switch (kind) {
    'private-key' => 'Private key',
    'aws-key' => 'AWS key',
    'github-token' => 'GitHub token',
    _ => 'API key or token',
  };
}

String _lineTitle(String text, {int maximumLength = 48}) {
  final String firstLine = text.split('\n').first;
  if (firstLine.length <= maximumLength) {
    return firstLine;
  }
  return '${firstLine.substring(0, maximumLength - 3)}...';
}
