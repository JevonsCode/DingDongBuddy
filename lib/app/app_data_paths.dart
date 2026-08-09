import 'dart:io';

/// Platform-specific durable locations used by the app and MCP executable.
final class AppDataPaths {
  const AppDataPaths._(
    this.applicationSupportDirectory,
    this._separator, {
    required this.development,
  });

  factory AppDataPaths.current({bool? development}) {
    return AppDataPaths.forPlatform(
      operatingSystem: Platform.operatingSystem,
      homeDirectory:
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!,
      appDataDirectory: Platform.environment['APPDATA'],
      development:
          development ?? _hasDevelopmentMarker(Platform.resolvedExecutable),
    );
  }

  factory AppDataPaths.forPlatform({
    required String operatingSystem,
    required String homeDirectory,
    String? appDataDirectory,
    bool development = false,
  }) {
    final String directoryName = development ? 'DingDong DEV' : 'DingDong';
    final String directory = switch (operatingSystem) {
      'macos' => '$homeDirectory/Library/Application Support/$directoryName',
      'windows' => '${appDataDirectory ?? homeDirectory}\\$directoryName',
      _ => '$homeDirectory/.local/share/$directoryName',
    };
    return AppDataPaths._(
      Directory(directory),
      operatingSystem == 'windows' ? r'\' : '/',
      development: development,
    );
  }

  static const String developmentMarkerFileName = 'dingdong-development.marker';

  final Directory applicationSupportDirectory;
  final bool development;
  final String _separator;

  File get resourceLibraryFile => File(
    '${applicationSupportDirectory.path}${_separator}resource-library.json',
  );

  File get triggerGroupsFile => File(
    '${applicationSupportDirectory.path}${_separator}trigger-groups.json',
  );

  File get clipboardDatabaseFile => File(
    '${applicationSupportDirectory.path}${_separator}clipboard-history.sqlite',
  );

  File get clipboardCategoryRulesFile => File(
    '${applicationSupportDirectory.path}${_separator}clipboard-category-rules.json',
  );

  File get clipboardGroupOrderFile => File(
    '${applicationSupportDirectory.path}${_separator}clipboard-group-order.json',
  );

  File get libraryImportHistoryFile => File(
    '${applicationSupportDirectory.path}${_separator}library-import-history.json',
  );

  File get agentActivityFile => File(
    '${applicationSupportDirectory.path}${_separator}agent-activity.json',
  );

  File get agentLaunchersFile => File(
    '${applicationSupportDirectory.path}${_separator}agent-launchers.json',
  );

  File get deviceLinksFile =>
      File('${applicationSupportDirectory.path}${_separator}device-links.json');

  Directory get agentAdaptersDirectory => Directory(
    '${applicationSupportDirectory.path}${_separator}Agent Adapters',
  );

  Directory get agentAdapterHistoryDirectory => Directory(
    '${applicationSupportDirectory.path}${_separator}Agent Adapter History',
  );

  File get activePortFile =>
      File('${applicationSupportDirectory.path}${_separator}api-port');

  Directory get clipboardImagesDirectory => Directory(
    '${applicationSupportDirectory.path}${_separator}Clipboard Images',
  );

  Directory get deviceTransferDirectory => Directory(
    '${applicationSupportDirectory.path}${_separator}Device Transfers',
  );

  Directory get skillPackagesDirectory => Directory(
    '${applicationSupportDirectory.path}${_separator}Skill Packages',
  );

  static bool _hasDevelopmentMarker(String executablePath) {
    Directory directory = File(executablePath).parent;
    for (int depth = 0; depth < 8; depth += 1) {
      final String separator = Platform.pathSeparator;
      final File directMarker = File(
        '${directory.path}$separator$developmentMarkerFileName',
      );
      final File resourceMarker = File(
        '${directory.path}${separator}Resources$separator'
        '$developmentMarkerFileName',
      );
      if (directMarker.existsSync() || resourceMarker.existsSync()) {
        return true;
      }
      final Directory parent = directory.parent;
      if (parent.path == directory.path) {
        return false;
      }
      directory = parent;
    }
    return false;
  }
}
