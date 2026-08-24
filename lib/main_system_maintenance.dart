part of 'main.dart';

// Shared system-data cleanup and startup configuration helpers.
Uri? _configuredUri(String value) {
  final String trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final Uri? uri = Uri.tryParse(trimmed);
  return uri != null && uri.hasScheme && uri.host.isNotEmpty ? uri : null;
}

String _lifecycleTelemetryArchitecture() {
  final String abi = ffi.Abi.current().toString().toLowerCase();
  if (abi.contains('arm64')) return 'arm64';
  if (abi.contains('x64')) return 'x64';
  if (abi.contains('ia32')) return 'x86';
  return 'other';
}

Future<void> _clearClipboardHistory(AppDependencies dependencies) async {
  dependencies.clipboardStore.deleteAll();
  final Directory imageDirectory = dependencies.paths.clipboardImagesDirectory;
  await imageDirectory.create(recursive: true);
  pruneUnreferencedManagedClipboardImages(
    dependencies.clipboardStore.listArchives().map(
      (ClipboardArchiveEntry entry) => entry.record,
    ),
    imageDirectory,
  );
}

Future<void> _clearSelectedSystemData({
  required Set<SystemDataCategory> categories,
  required AppDependencies dependencies,
  required ActivityController activityController,
  required ShellController shellController,
}) async {
  final Set<ClipboardKind> clipboardKinds = <ClipboardKind>{
    if (categories.contains(SystemDataCategory.clipboardImages))
      ClipboardKind.image,
    if (categories.contains(SystemDataCategory.clipboardFiles))
      ClipboardKind.file,
    if (categories.contains(SystemDataCategory.clipboardText))
      ...ClipboardKind.values.where(
        (ClipboardKind kind) =>
            kind != ClipboardKind.image && kind != ClipboardKind.file,
      ),
  };
  if (clipboardKinds.isNotEmpty) {
    dependencies.clipboardStore.deleteHistoryKinds(clipboardKinds);
    final List<ClipboardRecord> preserved = <ClipboardRecord>[
      ...dependencies.clipboardStore.list(
        limit: 5000,
        includeProtectedBeyondLimit: true,
      ),
      ...dependencies.clipboardStore.listArchives().map(
        (ClipboardArchiveEntry entry) => entry.record,
      ),
    ];
    pruneUnreferencedManagedClipboardImages(
      preserved,
      dependencies.paths.clipboardImagesDirectory,
    );
    shellController.requestClipboardRefresh();
  }
  if (categories.contains(SystemDataCategory.agentActivity)) {
    activityController.clear();
  }
  if (categories.contains(SystemDataCategory.adapterHistory)) {
    final Directory history = dependencies.paths.agentAdapterHistoryDirectory;
    if (await history.exists()) {
      await history.delete(recursive: true);
    }
    await history.create(recursive: true);
  }
}
