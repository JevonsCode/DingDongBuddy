/// Preset colors for unread menu bar and Windows notification-area markers.
enum TrayNotificationColor {
  orange(0xDB7333),
  pink(0xE85991),
  blue(0x3B7DDD),
  green(0x2F9D68),
  purple(0x8C5BD6),
  amber(0x966500);

  const TrayNotificationColor(this.rgbValue);

  final int rgbValue;

  static TrayNotificationColor parse(
    Object? value, {
    TrayNotificationColor fallback = TrayNotificationColor.orange,
  }) {
    return values.firstWhere(
      (TrayNotificationColor item) => item.name == value,
      orElse: () => fallback,
    );
  }
}

/// Whether an unread reminder rests or gently alternates its tray marker.
enum TrayReminderStyle {
  staticMarker,
  softPulse;

  static TrayReminderStyle parse(
    Object? value, {
    required TrayReminderStyle fallback,
  }) => values.firstWhere((item) => item.name == value, orElse: () => fallback);
}
