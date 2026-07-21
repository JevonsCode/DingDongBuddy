import 'dart:convert';

import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/shell/domain/tray_unread_store.dart';

/// Stores tray attention state as one preference value so updates are atomic.
final class PreferencesTrayUnreadStore implements TrayUnreadStore {
  PreferencesTrayUnreadStore(this._preferences);

  static const String _key = 'dingdong.tray.unreadState';
  final PreferencesBackend _preferences;

  @override
  Future<TrayUnreadState> load() async {
    final Object? stored = await _preferences.read(_key);
    if (stored is! String || stored.trim().isEmpty) {
      return const TrayUnreadState.empty();
    }
    try {
      final Map<String, Object?> json =
          jsonDecode(stored) as Map<String, Object?>;
      final int latest = (json['latestEventId'] as int? ?? 0).clamp(
        0,
        0x7fffffffffffffff,
      );
      final int acknowledged = (json['acknowledgedEventId'] as int? ?? 0).clamp(
        0,
        latest,
      );
      return TrayUnreadState(
        latestEventId: latest,
        acknowledgedEventId: acknowledged,
      );
    } on Object {
      return const TrayUnreadState.empty();
    }
  }

  @override
  Future<void> save(TrayUnreadState state) {
    return _preferences.write(
      _key,
      jsonEncode(<String, Object?>{
        'latestEventId': state.latestEventId,
        'acknowledgedEventId': state.acknowledgedEventId,
      }),
    );
  }
}
