import 'package:flutter/foundation.dart';

final class NearbyComputer {
  factory NearbyComputer.fromJson(Map json) => NearbyComputer(
    id: json['id'] as String,
    name: json['name'] as String,
    pairing: json['pairing'] == true,
  );
  const NearbyComputer({
    required this.id,
    required this.name,
    required this.pairing,
  });
  final String id;
  final String name;
  final bool pairing;
  Map<String, Object?> toJson() => {'id': id, 'name': name, 'pairing': pairing};
}

/// Optional capability shared by the main engine and its connection window.
abstract interface class LanComputerManagement implements Listenable {
  List<NearbyComputer> get nearbyComputers;
  String? get computerPairingCode;
  String? get computerDiscoveryError;
  Future<void> refreshComputers();
  Future<void> beginComputerPairing();
  Future<void> cancelComputerPairing();
  Future<void> joinNearbyComputer(String deviceId, String code);
}
