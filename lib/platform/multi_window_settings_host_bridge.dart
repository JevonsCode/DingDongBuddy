import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/clipboard/domain/clipboard_monitor_service.dart';
import 'package:dingdong/features/settings/domain/application_updater.dart';
import 'package:dingdong/features/settings/domain/launch_at_startup.dart';
import 'package:dingdong/features/settings/domain/quick_paste_permission.dart';
import 'package:dingdong/features/settings/domain/sound_preview_gateway.dart';

/// Proxies settings-only native operations back to the primary Flutter engine.
final class MultiWindowSettingsHostBridge
    implements
        ClipboardMonitoring,
        LaunchAtStartup,
        QuickPastePermissionGateway,
        SoundPreviewGateway,
        ApplicationUpdater {
  MultiWindowSettingsHostBridge(String parentWindowId)
    : _parent = WindowController.fromWindowId(parentWindowId);

  final WindowController _parent;
  bool _isRunning = false;

  @override
  bool get isRunning => _isRunning;

  @override
  Future<bool> isEnabled() async {
    return await _parent.invokeMethod<bool>('settings_launch_is_enabled') ??
        false;
  }

  @override
  Future<void> setEnabled(bool value) {
    return _parent.invokeMethod<void>('settings_launch_set', <String, bool>{
      'enabled': value,
    });
  }

  @override
  Future<bool> isGranted() async {
    return await _parent.invokeMethod<bool>('settings_quick_is_granted') ??
        false;
  }

  @override
  Future<void> openSettings() {
    return _parent.invokeMethod<void>('settings_quick_open');
  }

  @override
  Future<void> start() async {
    await _parent.invokeMethod<void>('settings_clipboard_start');
    _isRunning = true;
  }

  @override
  Future<void> stop() async {
    await _parent.invokeMethod<void>('settings_clipboard_stop');
    _isRunning = false;
  }

  Future<void> setOpacity(double value) {
    return _parent.invokeMethod<void>('settings_opacity_set', <String, double>{
      'value': value,
    });
  }

  Future<void> notifyChanged() {
    return _parent.invokeMethod<void>('settings_changed');
  }

  Future<void> restartApplication() {
    return _parent.invokeMethod<void>('settings_restart');
  }

  @override
  Future<bool> isSupported() async {
    return await _parent.invokeMethod<bool>('settings_update_supported') ??
        false;
  }

  @override
  Future<ApplicationUpdateStatus> readStatus() async {
    final Map<Object?, Object?>? values = await _parent
        .invokeMethod<Map<Object?, Object?>>('settings_update_state');
    return values == null
        ? const ApplicationUpdateStatus(
            phase: ApplicationUpdatePhase.unsupported,
          )
        : ApplicationUpdateStatus.fromJson(values);
  }

  @override
  Future<void> installLatest() {
    return _parent.invokeMethod<void>('settings_update_install');
  }

  @override
  Future<void> preview({required String sound, String? customSoundPath}) {
    return _parent.invokeMethod<void>(
      'settings_sound_preview',
      <String, Object?>{'sound': sound, 'customSoundPath': ?customSoundPath},
    );
  }
}
