import 'dart:io';

import 'package:dingdong/features/settings/domain/system_usage.dart';

typedef SystemDataFolderLauncher =
    Future<void> Function(String executable, List<String> arguments);

/// Opens only DingDong-owned directories in the host file manager.
final class IoSystemDataLocationGateway implements SystemDataLocationGateway {
  IoSystemDataLocationGateway(
    this.applicationDataDirectory, {
    String Function()? operatingSystem,
    SystemDataFolderLauncher? launcher,
  }) : _operatingSystem = operatingSystem ?? _currentOperatingSystem,
       _launcher = launcher ?? _launchDetached;

  final Directory applicationDataDirectory;
  final String Function() _operatingSystem;
  final SystemDataFolderLauncher _launcher;

  @override
  Future<void> open(SystemDataCategory category) async {
    final Directory directory = category == SystemDataCategory.clipboardImages
        ? Directory(
            '${applicationDataDirectory.path}${Platform.pathSeparator}Clipboard Images',
          )
        : applicationDataDirectory;
    await directory.create(recursive: true);
    final String operatingSystem = _operatingSystem();
    final (String, List<String>) command = switch (operatingSystem) {
      'macos' => ('open', <String>[directory.path]),
      'windows' => ('explorer.exe', <String>[directory.path]),
      'linux' => ('xdg-open', <String>[directory.path]),
      _ => throw UnsupportedError(
        'Opening the DingDong data folder is not supported on $operatingSystem.',
      ),
    };
    await _launcher(command.$1, command.$2);
  }

  static String _currentOperatingSystem() => Platform.operatingSystem;

  static Future<void> _launchDetached(
    String executable,
    List<String> arguments,
  ) async {
    await Process.start(executable, arguments, mode: ProcessStartMode.detached);
  }
}
