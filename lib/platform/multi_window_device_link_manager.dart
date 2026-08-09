import 'dart:convert';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/features/device_link/domain/device_link_management.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const String deviceLinkManagerWindowKind = 'device-link-manager';
const String deviceLinkManagerChangedMethod = 'device_link_changed';
const String deviceLinkManagerSnapshotMethod = 'device_link_snapshot';
const String deviceLinkManagerBeginPairingMethod = 'device_link_begin_pairing';
const String deviceLinkManagerCancelPairingMethod =
    'device_link_cancel_pairing';
const String deviceLinkManagerAutoSendSetMethod = 'device_link_auto_send_set';
const String deviceLinkManagerAgentNotificationsSetMethod =
    'device_link_agent_notifications_set';
const String deviceLinkManagerDisconnectMethod = 'device_link_disconnect';
const String deviceLinkManagerReconnectMethod = 'device_link_reconnect';
const String deviceLinkManagerDeleteMethod = 'device_link_delete';

/// Reuses one dedicated connection manager window per desktop process.
final class MultiWindowDeviceLinkManagerLauncher
    implements DeviceLinkManagerLauncher {
  const MultiWindowDeviceLinkManagerLauncher({required this.parentWindowId});

  final String parentWindowId;

  @override
  Future<void> show() async {
    for (final WindowController controller in await WindowController.getAll()) {
      if (_decode(controller.arguments)['kind'] ==
          deviceLinkManagerWindowKind) {
        await controller.show();
        await controller.invokeMethod<void>('window_focus');
        return;
      }
    }

    await WindowController.create(
      WindowConfiguration(
        hiddenAtLaunch: true,
        arguments: jsonEncode(<String, Object?>{
          'kind': deviceLinkManagerWindowKind,
          'parentWindowId': parentWindowId,
        }),
      ),
    );
  }

  /// Asks an already-open manager to fetch a fresh host-owned snapshot.
  Future<void> refresh() async {
    try {
      for (final WindowController controller
          in await WindowController.getAll()) {
        if (_decode(controller.arguments)['kind'] ==
            deviceLinkManagerWindowKind) {
          await controller.invokeMethod<void>(deviceLinkManagerChangedMethod);
          return;
        }
      }
    } on Object {
      // The child window can disappear while an RTC state change is emitted.
    }
  }
}

/// Serializes presentation state for the trusted local child-window channel.
Map<String, Object?> encodeDeviceLinkManagerSnapshot(
  DeviceLinkManagement controller,
) {
  return <String, Object?>{
    'localDevice': controller.localDevice.toJson(),
    'devices': controller.devices
        .map((LinkedDevice device) => device.toJson())
        .toList(growable: false),
    'statuses': <String, String>{
      for (final LinkedDevice device in controller.devices)
        device.id: controller.statusOf(device.id).name,
    },
    'pairing': controller.pendingPairing?.toJson(),
    'pairingStatus': controller.pairingStatus.name,
    'canPair': controller.canPair,
  };
}

/// Handles connection-manager calls in the main engine, which alone owns RTC.
Future<Object?> handleDeviceLinkManagerHostCall(
  DeviceLinkManagement controller,
  MethodCall call,
) async {
  switch (call.method) {
    case deviceLinkManagerSnapshotMethod:
      return encodeDeviceLinkManagerSnapshot(controller);
    case deviceLinkManagerBeginPairingMethod:
      await controller.beginPairing();
      return null;
    case deviceLinkManagerCancelPairingMethod:
      await controller.cancelPairing();
      return null;
    case deviceLinkManagerAutoSendSetMethod:
      final Map<Object?, Object?> values = call.arguments! as Map;
      await controller.setAutoSendClipboard(
        values['deviceId']! as String,
        values['enabled']! as bool,
      );
      return null;
    case deviceLinkManagerAgentNotificationsSetMethod:
      final Map<Object?, Object?> values = call.arguments! as Map;
      await controller.setAgentNotifications(
        values['deviceId']! as String,
        values['enabled']! as bool,
      );
      return null;
    case deviceLinkManagerDisconnectMethod:
      await controller.disconnect(call.arguments! as String);
      return null;
    case deviceLinkManagerReconnectMethod:
      await controller.reconnect(call.arguments! as String);
      return null;
    case deviceLinkManagerDeleteMethod:
      await controller.deleteDevice(call.arguments! as String);
      return null;
    default:
      return null;
  }
}

bool isDeviceLinkManagerHostMethod(String method) => const <String>{
  deviceLinkManagerSnapshotMethod,
  deviceLinkManagerBeginPairingMethod,
  deviceLinkManagerCancelPairingMethod,
  deviceLinkManagerAutoSendSetMethod,
  deviceLinkManagerAgentNotificationsSetMethod,
  deviceLinkManagerDisconnectMethod,
  deviceLinkManagerReconnectMethod,
  deviceLinkManagerDeleteMethod,
}.contains(method);

/// Child-window presentation proxy. It never creates a second RTC session.
final class RemoteDeviceLinkManagement extends ChangeNotifier
    implements DeviceLinkManagement {
  factory RemoteDeviceLinkManagement({
    required WindowController parentController,
  }) => RemoteDeviceLinkManagement._(parentController);

  RemoteDeviceLinkManagement._(this._parentController);

  final WindowController _parentController;
  LocalDeviceIdentity _localDevice = const LocalDeviceIdentity(
    id: 'loading',
    name: 'DingDong',
    platform: '',
  );
  List<LinkedDevice> _devices = const <LinkedDevice>[];
  Map<String, DeviceConnectionStatus> _statuses =
      const <String, DeviceConnectionStatus>{};
  PendingDevicePairing? _pendingPairing;
  DeviceConnectionStatus _pairingStatus = DeviceConnectionStatus.disconnected;
  bool _canPair = false;
  bool _disposed = false;

  @override
  LocalDeviceIdentity get localDevice => _localDevice;

  @override
  List<LinkedDevice> get devices => List<LinkedDevice>.unmodifiable(_devices);

  @override
  PendingDevicePairing? get pendingPairing => _pendingPairing;

  @override
  DeviceConnectionStatus get pairingStatus => _pairingStatus;

  @override
  bool get canPair => _canPair;

  @override
  DeviceConnectionStatus statusOf(String deviceId) =>
      _statuses[deviceId] ?? DeviceConnectionStatus.disconnected;

  @override
  bool isConnected(String deviceId) =>
      statusOf(deviceId) == DeviceConnectionStatus.connected;

  Future<void> reload() async {
    final Object? response = await _parentController.invokeMethod<Object?>(
      deviceLinkManagerSnapshotMethod,
    );
    if (response is! Map) return;
    final Map<String, Object?> json = Map<String, Object?>.from(response);
    _localDevice = LocalDeviceIdentity.fromJson(
      Map<String, Object?>.from(json['localDevice']! as Map),
    );
    final Object? rawDevices = json['devices'];
    _devices = rawDevices is List
        ? rawDevices
              .whereType<Map>()
              .map(
                (Map value) =>
                    LinkedDevice.fromJson(Map<String, Object?>.from(value)),
              )
              .toList(growable: false)
        : const <LinkedDevice>[];
    final Object? rawStatuses = json['statuses'];
    _statuses = rawStatuses is Map
        ? <String, DeviceConnectionStatus>{
            for (final MapEntry<Object?, Object?> entry in rawStatuses.entries)
              if (entry.key is String)
                entry.key! as String: _parseStatus(entry.value),
          }
        : const <String, DeviceConnectionStatus>{};
    final Object? rawPairing = json['pairing'];
    _pendingPairing = rawPairing is Map
        ? PendingDevicePairing.fromJson(Map<String, Object?>.from(rawPairing))
        : null;
    _pairingStatus = _parseStatus(json['pairingStatus']);
    _canPair = json['canPair'] == true;
    if (!_disposed) notifyListeners();
  }

  @override
  Future<PendingDevicePairing?> beginPairing() async {
    await _invokeAndReload(deviceLinkManagerBeginPairingMethod);
    return _pendingPairing;
  }

  @override
  Future<void> cancelPairing() =>
      _invokeAndReload(deviceLinkManagerCancelPairingMethod);

  @override
  Future<void> setAutoSendClipboard(String deviceId, bool value) =>
      _invokeAndReload(deviceLinkManagerAutoSendSetMethod, <String, Object?>{
        'deviceId': deviceId,
        'enabled': value,
      });

  @override
  Future<void> setAgentNotifications(String deviceId, bool value) =>
      _invokeAndReload(
        deviceLinkManagerAgentNotificationsSetMethod,
        <String, Object?>{'deviceId': deviceId, 'enabled': value},
      );

  @override
  Future<void> disconnect(String deviceId) =>
      _invokeAndReload(deviceLinkManagerDisconnectMethod, deviceId);

  @override
  Future<void> reconnect(String deviceId) =>
      _invokeAndReload(deviceLinkManagerReconnectMethod, deviceId);

  @override
  Future<void> deleteDevice(String deviceId) =>
      _invokeAndReload(deviceLinkManagerDeleteMethod, deviceId);

  Future<void> _invokeAndReload(String method, [Object? arguments]) async {
    await _parentController.invokeMethod<void>(method, arguments);
    await reload();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

DeviceConnectionStatus _parseStatus(Object? value) {
  return DeviceConnectionStatus.values.firstWhere(
    (DeviceConnectionStatus status) => status.name == value,
    orElse: () => DeviceConnectionStatus.disconnected,
  );
}

Map<String, Object?> _decode(String arguments) {
  if (arguments.trim().isEmpty) return const <String, Object?>{};
  final Object? value = jsonDecode(arguments);
  return value is Map<String, Object?> ? value : const <String, Object?>{};
}
