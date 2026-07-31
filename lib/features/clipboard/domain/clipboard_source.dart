/// One source application represented by the metadata already stored on
/// clipboard history records.
final class ClipboardSourceOption {
  const ClipboardSourceOption({required this.id, required this.label});

  /// Stable filter identity derived from a bundle identifier or executable.
  final String id;

  /// User-facing application name taken from the stored source metadata.
  final String label;
}

/// Converts one stored clipboard source into an application-level filter.
///
/// macOS stores `Application · bundle.identifier`, while Windows stores
/// `Window title · executable.exe`. The stable suffix keeps records from the
/// same application grouped even when their visible window titles differ.
ClipboardSourceOption? clipboardSourceOption(String? source) {
  final String value = source?.trim() ?? '';
  if (value.isEmpty || value.toLowerCase() == 'clipboard') {
    return null;
  }

  const String separator = ' · ';
  final int separatorIndex = value.lastIndexOf(separator);
  if (separatorIndex >= 0) {
    final String prefix = value.substring(0, separatorIndex).trim();
    final String identity = value
        .substring(separatorIndex + separator.length)
        .trim();
    final ClipboardSourceOption? structured = _structuredSource(
      prefix: prefix,
      identity: identity,
    );
    if (structured != null) {
      return structured;
    }
  }

  final ClipboardSourceOption? executable = _executableSource(value);
  if (executable != null) {
    return executable;
  }

  return ClipboardSourceOption(
    id: 'source:${value.toLowerCase()}',
    label: value,
  );
}

ClipboardSourceOption? _structuredSource({
  required String prefix,
  required String identity,
}) {
  final ClipboardSourceOption? executable = _executableSource(identity);
  if (executable != null) {
    return executable;
  }
  if (!_bundleIdentifier.hasMatch(identity)) {
    return null;
  }
  return ClipboardSourceOption(
    id: 'bundle:${identity.toLowerCase()}',
    label: prefix.isEmpty || prefix.toLowerCase() == 'unknown'
        ? identity
        : prefix,
  );
}

ClipboardSourceOption? _executableSource(String value) {
  if (!_windowsExecutable.hasMatch(value)) {
    return null;
  }
  return ClipboardSourceOption(id: 'exe:${value.toLowerCase()}', label: value);
}

final RegExp _bundleIdentifier = RegExp(r'^[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$');
final RegExp _windowsExecutable = RegExp(
  r'^[^\\/]+\.exe$',
  caseSensitive: false,
);
