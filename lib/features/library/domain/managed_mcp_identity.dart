import 'package:dingdong/features/library/domain/resource_configuration.dart';

/// Stable server identity used when DingDong writes a managed MCP entry into
/// an Agent configuration.
String managedMcpServerName({required String title, required String id}) {
  final String slug = normalizeSkillName(title);
  final String suffix = id.replaceAll(RegExp('[^A-Za-z0-9]'), '').toLowerCase();
  final int suffixLength = suffix.length < 6 ? suffix.length : 6;
  return 'dingdong-$slug-${suffix.substring(0, suffixLength)}';
}

/// Codex exposes MCP tools under a normalized namespace derived from the
/// configured server name.
String codexMcpToolPrefix(String serverName) =>
    'mcp__${serverName.replaceAll('-', '_')}__';
