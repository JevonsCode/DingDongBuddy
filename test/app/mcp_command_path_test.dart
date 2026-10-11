import 'dart:io';

import 'package:dingdong/app/mcp_command_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  const String virtualInstall =
      r'C:\Users\me\AppData\Local\JevonsCode.DingDong\current\DingDong.exe';
  const String physicalMcp =
      r'C:\Users\me\AppData\Local\Packages\OpenAI.Codex_2p2nqsd0c76g0'
      r'\LocalCache\Local\JevonsCode.DingDong\current\mcp\bundle\bin'
      r'\dingdong_mcp.exe';

  test('Windows resolves a container-virtualized install to its real file', () {
    String? requested;
    final String result = resolveMcpCommandPath(
      executablePath: virtualInstall,
      isWindows: true,
      resolvePhysicalPath: (String value) {
        requested = value;
        return physicalMcp;
      },
    );

    expect(
      requested,
      path.windows.normalize(
        r'C:\Users\me\AppData\Local\JevonsCode.DingDong\current'
        r'\mcp\bundle\bin\dingdong_mcp.exe',
      ),
    );
    expect(result, path.windows.normalize(physicalMcp));
    expect(isInsidePackageContainer(result), isTrue);
  });

  test('an unresolvable path falls back to the bundled location', () {
    final String result = resolveMcpCommandPath(
      executablePath: virtualInstall,
      isWindows: true,
      resolvePhysicalPath: (String value) =>
          throw FileSystemException('missing', value),
    );

    expect(
      result,
      endsWith(path.windows.normalize(r'mcp\bundle\bin\dingdong_mcp.exe')),
    );
    expect(isInsidePackageContainer(result), isFalse);
  });

  test('macOS keeps the app-bundle MCP path without resolving', () {
    final String result = resolveMcpCommandPath(
      executablePath: '/Applications/DingDong.app/Contents/MacOS/DingDong',
      isWindows: false,
      resolvePhysicalPath: (_) => fail('macOS paths are not virtualized'),
    );

    expect(
      result,
      path.posix.normalize(
        '/Applications/DingDong.app/Contents/MCP/bundle/bin/dingdong_mcp',
      ),
    );
  });

  test('the notice names the app that owns the container', () {
    expect(packageContainerName(physicalMcp), 'OpenAI.Codex');
    expect(
      packageContainerName(
        r'C:\Users\me\AppData\Local\Packages\Claude_pzs8sxrjxfjjc\LocalCache'
        r'\Local\JevonsCode.DingDong\current\mcp\bundle\bin\dingdong_mcp.exe',
      ),
      'Claude',
    );
    expect(packageContainerName(virtualInstall), isNull);
  });

  test('only another app\'s LocalCache counts as a package container', () {
    expect(isInsidePackageContainer(physicalMcp), isTrue);
    expect(
      isInsidePackageContainer(
        r'C:\Users\me\AppData\Local\JevonsCode.DingDong\current\mcp\bundle\bin\dingdong_mcp.exe',
      ),
      isFalse,
    );
    expect(
      isInsidePackageContainer(
        r'C:\Users\me\Documents\Packages\LocalCache\x.exe',
      ),
      isFalse,
    );
  });
}
