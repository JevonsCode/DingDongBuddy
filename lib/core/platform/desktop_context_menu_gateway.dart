/// One entry in a platform-native desktop context menu.
final class DesktopContextMenuItem {
  const DesktopContextMenuItem({
    required this.id,
    required this.label,
    this.enabled = true,
  }) : separator = false;

  const DesktopContextMenuItem.separator()
    : id = '',
      label = '',
      enabled = false,
      separator = true;

  final String id;
  final String label;
  final bool enabled;
  final bool separator;

  Map<String, Object> toJson() => <String, Object>{
    'id': id,
    'label': label,
    'enabled': enabled,
    'separator': separator,
  };
}

/// Opens the operating system's context menu at the current pointer location.
abstract interface class DesktopContextMenuGateway {
  Future<String?> show({
    required double x,
    required double y,
    required bool isDark,
    required List<DesktopContextMenuItem> items,
  });
}
