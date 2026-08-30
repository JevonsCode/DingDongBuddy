part of 'device_link_controller.dart';

// Small session records, the share gateway, and platform-safe filename helpers.
final class DeviceClipboardShareGateway implements ClipboardShareGateway {
  const DeviceClipboardShareGateway(this.controller);

  final DeviceLinkController controller;

  @override
  Future<void> share(ClipboardRecord record) async {
    controller.requestShare(record);
  }
}

final class _ManagedDeviceSession {
  _ManagedDeviceSession({
    required this.handle,
    required this.room,
    required this.deviceId,
    required this.connectionSide,
  });

  final DeviceLinkSessionHandle handle;
  final String room;
  final DeviceLinkConnectionSide connectionSide;
  String? deviceId;
  bool helloSent = false;
  bool snapshotPending = false;
  bool active = true;
  StreamSubscription<void>? subscription;
}

final class _IncomingFileUpload {
  _IncomingFileUpload({
    required this.deviceId,
    required this.name,
    required this.expectedBytes,
    required this.partialFile,
    required this.writer,
    required this.lastActivityAt,
  });

  final String deviceId;
  final String name;
  final int expectedBytes;
  final File partialFile;
  final RandomAccessFile writer;
  int receivedBytes = 0;
  int nextIndex = 0;
  DateTime lastActivityAt;
}

LocalDeviceIdentity _newLocalIdentity(DingDongLocalizations strings) {
  final String name = Platform.localHostname.trim();
  return LocalDeviceIdentity(
    id: 'desktop-${_randomToken(12)}',
    name: name.isEmpty ? strings.dingDongComputer : name,
    platform: Platform.operatingSystem,
  );
}

String _randomToken(int bytes) {
  final Random random = Random.secure();
  return base64Url
      .encode(List<int>.generate(bytes, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}

File? _firstExistingFile(ClipboardRecord record) {
  for (final String value in record.filePaths) {
    final File file = File(value);
    if (file.existsSync()) return file;
  }
  return null;
}

String sanitizeDeviceLinkFileName(
  String value, {
  String fallback = 'Shared file',
}) {
  final List<String> segments = value.trim().split(RegExp(r'[/\\]+'));
  String base = (segments.isEmpty ? '' : segments.last)
      .replaceAll(RegExp(r'[\x00-\x1f<>:"/\\|?*]'), '_')
      .replaceFirst(RegExp(r'[ .]+$'), '');
  if (base.isEmpty || base == '.' || base == '..') base = fallback;
  final String deviceStem = base
      .split('.')
      .first
      .replaceFirst(RegExp(r'[ .]+$'), '');
  if (RegExp(
    r'^(?:con|prn|aux|nul|clock\$|conin\$|conout\$|com[1-9¹²³]|lpt[1-9¹²³])$',
    caseSensitive: false,
  ).hasMatch(deviceStem)) {
    base = '_$base';
  }
  return _truncateDeviceLinkFileName(base, maximumBytes: 180);
}

String _truncateDeviceLinkFileName(String value, {required int maximumBytes}) {
  if (utf8.encode(value).length <= maximumBytes) return value;
  final int dot = value.lastIndexOf('.');
  final String extension = dot > 0 ? value.substring(dot) : '';
  final bool preserveExtension =
      extension.isNotEmpty && utf8.encode(extension).length <= 32;
  final String stem = preserveExtension ? value.substring(0, dot) : value;
  final int stemBudget =
      maximumBytes - (preserveExtension ? utf8.encode(extension).length : 0);
  final StringBuffer truncated = StringBuffer();
  var bytes = 0;
  for (final int rune in stem.runes) {
    final String character = String.fromCharCode(rune);
    final int characterBytes = utf8.encode(character).length;
    if (bytes + characterBytes > stemBudget) break;
    truncated.write(character);
    bytes += characterBytes;
  }
  return '${truncated.toString()}${preserveExtension ? extension : ''}';
}

Uri _relayApiUri(Uri base, String path) {
  final String basePath = base.path == '/' ? '' : base.path;
  return base.replace(path: '$basePath/$path', query: '', fragment: '');
}
