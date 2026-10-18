// Display formatting copied from the PWA (docs/app/app-formatters.js).

String symbolForKind(String kind) => switch (kind) {
  'url' => 'assets/symbols/link.png',
  'command' => 'assets/symbols/command.png',
  'code' || 'json' => 'assets/symbols/code.png',
  'path' || 'file' => 'assets/symbols/path.png',
  'image' => 'assets/symbols/image.png',
  _ => 'assets/symbols/text.png',
};

String kindLabel(String kind) => switch (kind) {
  'url' => '链接',
  'command' => '命令',
  'code' => '代码',
  'json' => 'JSON',
  'path' => '路径',
  'file' => '文件',
  'image' => '图片',
  _ => '文本',
};

String _two(int value) => value.toString().padLeft(2, '0');

/// `2026/10/19 09:41`, as `Intl.DateTimeFormat('zh-CN')` renders it.
String formatTime(DateTime? value) {
  if (value == null) return '未记录';
  final DateTime d = value.toLocal();
  return '${d.year}/${_two(d.month)}/${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
}

String formatLifecycleTime(DateTime? value) {
  if (value == null) return '未记录';
  final DateTime d = value.toLocal();
  return '${formatTime(d)}:${_two(d.second)}';
}

String formatDuration(Duration duration) {
  int seconds = duration.inSeconds;
  if (seconds < 1) return '不足 1 秒';
  final int days = seconds ~/ 86400;
  seconds %= 86400;
  final int hours = seconds ~/ 3600;
  seconds %= 3600;
  final int minutes = seconds ~/ 60;
  seconds %= 60;
  final List<String> parts = <String>[
    if (days > 0) '$days 天',
    if (hours > 0) '$hours 小时',
    if (minutes > 0) '$minutes 分',
  ];
  if (seconds > 0 || parts.isEmpty) parts.add('$seconds 秒');
  return parts.join(' ');
}

String formatBytes(int? value) {
  if (value == null) return '';
  if (value < 1024) return '$value B';
  if (value < 1024 * 1024) return '${(value / 1024).round()} KB';
  return '${(value / 1024 / 1024).toStringAsFixed(1)} MB';
}

String? workspaceName(String? path) {
  if (path == null) return null;
  final List<String> parts = path
      .split(RegExp(r'[\\/]'))
      .where((String part) => part.isNotEmpty)
      .toList();
  return parts.isEmpty ? null : parts.last;
}

DateTime? parseDate(Object? value) =>
    value is String ? DateTime.tryParse(value)?.toLocal() : null;
