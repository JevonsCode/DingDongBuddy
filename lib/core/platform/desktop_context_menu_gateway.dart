/// One entry in a platform-native desktop context menu.
final class DesktopContextMenuItem {
  const DesktopContextMenuItem({
    required this.id,
    required this.englishLabel,
    required this.chineseLabel,
    this.enabled = true,
  }) : separator = false;

  const DesktopContextMenuItem.separator()
    : id = '',
      englishLabel = '',
      chineseLabel = '',
      enabled = false,
      separator = true;

  final String id;
  final String englishLabel;
  final String chineseLabel;
  final bool enabled;
  final bool separator;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'englishLabel': englishLabel,
    'chineseLabel': chineseLabel,
    'enabled': enabled,
    'separator': separator,
  };
}

/// Opens the operating system's context menu at the current pointer location.
abstract interface class DesktopContextMenuGateway {
  Future<String?> show({
    required double x,
    required double y,
    required bool useChinese,
    required List<DesktopContextMenuItem> items,
  });
}
