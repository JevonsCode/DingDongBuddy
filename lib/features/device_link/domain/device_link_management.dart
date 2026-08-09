import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:flutter/foundation.dart';

/// The state and actions shown by the dedicated device connection window.
///
/// The main Flutter engine implements this directly. Child-window engines use
/// a multi-window proxy, so connection ownership always remains in the host.
abstract interface class DeviceLinkManagement implements Listenable {
  LocalDeviceIdentity get localDevice;
  List<LinkedDevice> get devices;
  PendingDevicePairing? get pendingPairing;
  DeviceConnectionStatus get pairingStatus;
  bool get canPair;

  DeviceConnectionStatus statusOf(String deviceId);
  bool isConnected(String deviceId);

  Future<PendingDevicePairing?> beginPairing();
  Future<void> cancelPairing();
  Future<void> setAutoSendClipboard(String deviceId, bool value);
  Future<void> setAgentNotifications(String deviceId, bool value);
  Future<void> disconnect(String deviceId);
  Future<void> reconnect(String deviceId);
  Future<void> deleteDevice(String deviceId);
}

/// Opens the full connection manager in its own desktop window.
abstract interface class DeviceLinkManagerLauncher {
  Future<void> show();
}
