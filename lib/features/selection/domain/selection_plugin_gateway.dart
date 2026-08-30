import 'package:dingdong/features/selection/domain/selection_plugin_configuration.dart';

/// Observable state returned by the DingDong native host.
final class SelectionPluginRuntimeStatus {
  const SelectionPluginRuntimeStatus({
    required this.enabled,
    required this.running,
    required this.permissionGranted,
    required this.tokenConfigured,
  });

  const SelectionPluginRuntimeStatus.disabled()
    : enabled = false,
      running = false,
      permissionGranted = false,
      tokenConfigured = false;

  factory SelectionPluginRuntimeStatus.fromPlatform(Object? value) {
    final Map<Object?, Object?>? values = value is Map ? value : null;
    return SelectionPluginRuntimeStatus(
      enabled: values?['enabled'] == true,
      running: values?['running'] == true,
      permissionGranted: values?['permissionGranted'] == true,
      tokenConfigured: values?['tokenConfigured'] == true,
    );
  }

  final bool enabled;
  final bool running;
  final bool permissionGranted;
  final bool tokenConfigured;

  Map<String, bool> toPlatformResult() => <String, bool>{
    'enabled': enabled,
    'running': running,
    'permissionGranted': permissionGranted,
    'tokenConfigured': tokenConfigured,
  };
}

/// Host operations that keep permission and secrets under DingDong's identity.
abstract interface class SelectionPluginGateway {
  Future<SelectionPluginRuntimeStatus> apply(
    SelectionPluginConfiguration configuration,
  );

  Future<SelectionPluginRuntimeStatus> status();

  Future<void> openAccessibilitySettings();

  Future<void> saveToken(String token);

  Future<void> clearToken();
}
