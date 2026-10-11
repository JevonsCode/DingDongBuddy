import 'dart:io';

import 'package:path/path.dart' as path;

/// Locates the bundled `dingdong_mcp` executable that Agents launch.
///
/// On Windows, an app installed or started from inside a packaged host (for
/// example an Agent desktop app distributed as MSIX) sees `%LOCALAPPDATA%`
/// through that host's private container. Its own executable path is then a
/// virtual path that no other Agent can open, so the command is resolved to
/// the physical file the operating system actually serves.
String resolveMcpCommandPath({
  required String executablePath,
  required bool isWindows,
  String Function(String path)? resolvePhysicalPath,
}) {
  final path.Context paths = isWindows ? path.windows : path.posix;
  final String executableDirectory = paths.dirname(executablePath);
  final String bundled = paths.normalize(
    isWindows
        ? paths.join(
            executableDirectory,
            'mcp',
            'bundle',
            'bin',
            'dingdong_mcp.exe',
          )
        : paths.join(
            executableDirectory,
            '..',
            'MCP',
            'bundle',
            'bin',
            'dingdong_mcp',
          ),
  );
  if (!isWindows) return bundled;
  try {
    final String physical =
        (resolvePhysicalPath ??
        (String value) => File(value).resolveSymbolicLinksSync())(bundled);
    return paths.normalize(physical);
  } on FileSystemException {
    return bundled;
  }
}

final RegExp _packageContainer = RegExp(
  r'[\\/]AppData[\\/]Local[\\/]Packages[\\/]([^\\/]+)[\\/]LocalCache[\\/]',
  caseSensitive: false,
);

/// Whether [mcpCommandPath] lives in another app's private package container,
/// where only that app (and processes it starts) can see DingDong.
bool isInsidePackageContainer(String mcpCommandPath) =>
    _packageContainer.hasMatch(mcpCommandPath);

/// The host app owning the container, such as `OpenAI.Codex` for
/// `Packages\OpenAI.Codex_2p2nqsd0c76g0\LocalCache`, or null outside one.
String? packageContainerName(String mcpCommandPath) {
  final String? family = _packageContainer.firstMatch(mcpCommandPath)?.group(1);
  if (family == null) return null;
  final int separator = family.lastIndexOf('_');
  return separator > 0 ? family.substring(0, separator) : family;
}
