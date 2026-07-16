import 'dart:io';

/// Platform-specific durable locations used by the app and MCP executable.
final class AppDataPaths {
  const AppDataPaths._(this.applicationSupportDirectory, this._separator);

  factory AppDataPaths.current() {
    return AppDataPaths.forPlatform(
      operatingSystem: Platform.operatingSystem,
      homeDirectory:
          Platform.environment['HOME'] ?? Platform.environment['USERPROFILE']!,
      appDataDirectory: Platform.environment['APPDATA'],
    );
  }

  factory AppDataPaths.forPlatform({
    required String operatingSystem,
    required String homeDirectory,
    String? appDataDirectory,
  }) {
    final String directory = switch (operatingSystem) {
      'macos' => '$homeDirectory/Library/Application Support/DingDong',
      'windows' => '${appDataDirectory ?? homeDirectory}\\DingDong',
      _ => '$homeDirectory/.local/share/DingDong',
    };
    return AppDataPaths._(
      Directory(directory),
      operatingSystem == 'windows' ? r'\' : '/',
    );
  }

  final Directory applicationSupportDirectory;
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

  File get activePortFile =>
      File('${applicationSupportDirectory.path}${_separator}api-port');

  Directory get clipboardImagesDirectory => Directory(
    '${applicationSupportDirectory.path}${_separator}Clipboard Images',
  );
}
