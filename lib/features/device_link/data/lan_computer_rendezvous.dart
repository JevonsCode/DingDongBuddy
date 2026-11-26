part of 'lan_computer_link.dart';

extension _ComputerRendezvous on LanComputerLink {
  void _stopDiscoveryPairing({bool release = false}) {
    if (release && _inviteReady) {
      _invite?.releaseInvite();
    } else {
      _invite?.close();
    }
    _inviteReady = false;
    _invite = null;
    _lookup?.close();
    _lookup = null;
    _joiningDiscoveredWire?.close();
    _joiningDiscoveredWire = null;
  }

  Future<String> _reserveCode(int generation) async {
    final service = _discovery;
    var code = LanPairingCrypto.code();
    if (service == null || _routedServer == null) return code;
    for (var attempt = 0; attempt < 8; attempt++) {
      if (_closed || _generation != generation) break;
      final invite = service.hostInvite(
        code: code,
        hostId: identity.id,
        addresses: () => localAddresses,
        claimAttempt: () {
          if (generation != _generation ||
              pairingCode != code ||
              _attempts >= 5) {
            return false;
          }
          _attempts++;
          return true;
        },
        onUnverifiedAttemptFinished: () {
          if (generation == _generation && _code == code && _attempts >= 5) {
            _endPairing(release: false);
          }
        },
        onProofVerified: () {
          // A correct discovery proof authorizes the next direct SRP exchange.
          // All unsuccessful admissions remain charged to this displayed code.
          if (generation == _generation && _code == code && _attempts > 0) {
            _attempts--;
          }
        },
      );
      _invite = invite;
      try {
        await invite.ready;
        if (!identical(_invite, invite)) break;
        _inviteReady = true;
        unawaited(
          invite.done.then((_) {
            if (identical(_invite, invite)) {
              _inviteReady = false;
              _invite = null;
              _notifyDiscoveryChange();
            }
          }),
        );
        return code;
      } on LanDiscoverySlotOccupied {
        code = LanPairingCrypto.code();
      } on Exception {
        // Keep the local code usable when the discovery service is offline.
        break;
      } finally {
        if (!_inviteReady || !identical(_invite, invite)) invite.close();
      }
    }
    return code;
  }

  Iterable<InternetAddress> _eligibleCandidates(List<String> values) sync* {
    for (final value in values.toSet().take(8)) {
      final address = InternetAddress.tryParse(value);
      if (address == null || !_isRoutedAddress(address)) continue;
      if (discoveryPort != 0 && localAddresses.contains(address.address)) {
        continue;
      }
      if (_subnets.any((s) => s.contains(address)) && !_allowedHint(address)) {
        continue;
      }
      yield address;
    }
  }

  Future<void> _joinDiscoveredComputer(String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) throw const FormatException('code');
    final service = _discovery;
    if (service == null) throw StateError('Discovery service unavailable');
    final generation = _generation;
    await start();
    if (_closed || generation != _generation) {
      throw StateError('Pairing cancelled');
    }
    _lookup?.close();
    final lookup = service.lookupInvite(code);
    _lookup = lookup;
    try {
      final offer = await lookup.result;
      if (offer.hostId == identity.id) {
        throw const FormatException('Own device');
      }
      for (final address in _eligibleCandidates(offer.addresses)) {
        if (_closed || !identical(_lookup, lookup)) break;
        for (final source in _routedSources) {
          if (_closed || !identical(_lookup, lookup)) {
            throw StateError('Pairing cancelled');
          }
          LanWire pairingWire;
          try {
            // A listening socket on a VPN can be a different machine at the
            // same private IP. Check its identity before spending a guess,
            // and use the same source for the subsequent direct handshake.
            final probe = await _dialRoutedVia(address, source);
            try {
              await probe.write({
                'type': 'lookup',
                'protocol': LanComputerLink._routedProtocol,
              });
              final reply = await probe.read(
                timeout: LanComputerLink._routedTimeout,
              );
              if (reply['protocol'] != LanComputerLink._routedProtocol ||
                  reply['id'] != offer.hostId) {
                continue;
              }
            } finally {
              probe.close();
            }
            pairingWire = await _dialRoutedVia(address, source);
          } on Exception {
            continue;
          }
          if (_closed || !identical(_lookup, lookup)) {
            pairingWire.close();
            throw StateError('Pairing cancelled');
          }
          _joiningDiscoveredWire = pairingWire;
          try {
            await _joinWire(
              offer.hostId,
              code,
              pairingWire,
              isCurrent: () => identical(_lookup, lookup),
            );
          } finally {
            if (identical(_joiningDiscoveredWire, pairingWire)) {
              _joiningDiscoveredWire = null;
            }
          }
          return;
        }
      }
      throw const SocketException('No direct route to the discovered computer');
    } finally {
      if (identical(_lookup, lookup)) _lookup = null;
      lookup.close();
    }
  }
}
