import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dingdong/features/device_link/data/lan_network_policy.dart';
import 'package:dingdong/features/device_link/data/lan_pairing_crypto.dart';
import 'package:dingdong/features/device_link/data/secure_message_codec.dart';

const _timeout = Duration(seconds: 10);
const _purpose = 'dingdong-address-discovery-v1';
const _closed = SocketException('Address discovery closed');

final class LanDiscoverySlotOccupied implements Exception {
  const LanDiscoverySlotOccupied();
}

/// Keep this object for the entire lifetime of one displayed invitation.
final class LanDiscoveryInviteBudget {
  int _attempts = 0;
  bool get exhausted => _attempts >= 5;

  bool _claim() {
    if (exhausted) return false;
    _attempts++;
    return true;
  }
}

final class LanDiscoveryOffer {
  const LanDiscoveryOffer(this.hostId, this.addresses);
  final String hostId;
  final List<String> addresses;
}

final class LanDiscoveryLookup {
  LanDiscoveryLookup._(this.result, this._channel);
  final Future<LanDiscoveryOffer> result;
  final LanDiscoveryChannel _channel;
  void close() => _channel.close();
}

typedef _Frame = Map<String, Object?>;
typedef _Receiver = Future<void> Function(_Frame);

/// Owns a single WebSocket attempt. The LAN controller owns retry and expiry.
final class LanDiscoveryChannel {
  LanDiscoveryChannel._({this._inviteHost = false}) {
    // Cancellation may precede a caller awaiting ready.
    ready.ignore();
  }

  final _client = HttpClient()..connectionTimeout = _timeout;
  final _ready = Completer<void>();
  final _done = Completer<void>();
  WebSocket? _socket;
  void Function()? _onRefresh;
  void Function()? _onClose;
  Timer? _deadline;
  final bool _inviteHost;
  bool _releasing = false;
  bool _closedLocally = false;
  bool get _active => !_releasing && !_closedLocally;

  Future<void> get ready => _ready.future;
  Future<void> get done => _done.future;
  void refresh() => _onRefresh?.call();

  Future<void> _run(Uri uri, _Receiver receive) async {
    if (_closedLocally) return;
    _deadline = Timer(
      _timeout,
      () => _finish(TimeoutException('Discovery upgrade timed out')),
    );
    try {
      final socket = await WebSocket.connect(
        uri.toString(),
        customClient: _client,
        compression: CompressionOptions.compressionOff,
      );
      if (_closedLocally) {
        await socket.close();
        return;
      }
      _socket = socket;
      socket.pingInterval = const Duration(seconds: 30);
      await for (final raw in socket) {
        if (_closedLocally) break;
        if (_releasing) continue;
        if (raw is! String ||
            raw.length > 4096 ||
            utf8.encode(raw).length > 4096) {
          throw const FormatException('Invalid discovery frame');
        }
        final frame = jsonDecode(raw);
        if (frame is! _Frame) {
          throw const FormatException('Invalid discovery frame');
        }
        if (frame['type'] == 'relay' &&
            frame['event'] == 'ready' &&
            !_ready.isCompleted) {
          _deadline?.cancel();
          _ready.complete();
        } else {
          await receive(frame);
        }
      }
    } on WebSocketException catch (error) {
      _finish(
        error.httpStatusCode == HttpStatus.conflict
            ? const LanDiscoverySlotOccupied()
            : error,
      );
    } catch (error) {
      _finish(error);
    } finally {
      close();
    }
  }

  void _send(_Frame frame) {
    final socket = _socket;
    if (_active && socket != null && socket.readyState == WebSocket.open) {
      try {
        socket.add(jsonEncode(frame));
      } on StateError {
        // The write sink can close before readyState observes a peer close.
        close();
      }
    }
  }

  /// A deliberate cancellation or completed direct pairing can relinquish the
  /// host's live lease. Transport loss and exhausted attempts use [close].
  void releaseInvite() {
    if (_closedLocally || _releasing) return;
    final socket = _socket;
    if (!_inviteHost ||
        !_ready.isCompleted ||
        socket == null ||
        socket.readyState != WebSocket.open) {
      close();
      return;
    }
    _releasing = true;
    _onClose?.call();
    _onClose = null;
    if (_closedLocally) return;
    _deadline?.cancel();
    _deadline = Timer(const Duration(seconds: 2), close);
    try {
      // The server closes the socket after processing this frame.
      socket.add(jsonEncode({'type': 'release'}));
    } on StateError {
      close();
    }
  }

  void close() => _finish(_closed);

  void _finish(Object reason) {
    if (_closedLocally) return;
    _closedLocally = true;
    _deadline?.cancel();
    _onRefresh = null;
    _onClose?.call();
    if (!_ready.isCompleted) _ready.completeError(reason);
    _client.close(force: true);
    _socket?.close().ignore();
    _done.complete();
  }
}

/// Authenticates a small set of address candidates. The caller still performs
/// direct lookup and pairing/authentication on its fixed TCP listener port.
final class LanDiscoveryService {
  LanDiscoveryService(this.baseUrl, {this.allowLoopbackCandidates = false}) {
    final loopback =
        baseUrl.host == 'localhost' ||
        (InternetAddress.tryParse(baseUrl.host)?.isLoopback ?? false);
    if (baseUrl.host.isEmpty ||
        baseUrl.userInfo.isNotEmpty ||
        !(baseUrl.isScheme('https') ||
            baseUrl.isScheme('wss') ||
            (loopback &&
                (baseUrl.isScheme('http') || baseUrl.isScheme('ws'))))) {
      throw const FormatException(
        'Discovery requires TLS or a loopback test server',
      );
    }
  }
  static LanDiscoveryService? tryCreate(
    Uri? baseUrl, {
    bool allowLoopbackCandidates = false,
  }) {
    if (baseUrl == null) return null;
    try {
      return LanDiscoveryService(
        baseUrl,
        allowLoopbackCandidates: allowLoopbackCandidates,
      );
    } on FormatException {
      return null;
    }
  }

  final bool allowLoopbackCandidates;
  final Uri baseUrl;

  Uri _url(String slot, String side) => baseUrl.replace(
    scheme: switch (baseUrl.scheme) {
      'https' => 'wss',
      'http' => 'ws',
      _ => baseUrl.scheme,
    },
    path: '${baseUrl.path.replaceFirst(RegExp(r'/+$'), '')}/v1/discovery/$slot',
    queryParameters: {'side': side},
    fragment: '',
  );

  static String _invitationSlot(String code) {
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      throw const FormatException('Six-digit invitation required');
    }
    return 'invite-${code.substring(0, 2)}';
  }

  LanDiscoveryChannel hostInvite({
    required String code,
    required String hostId,
    required List<String> Function() addresses,
    LanDiscoveryInviteBudget? budget,
    bool Function()? claimAttempt,
    void Function()? onProofVerified,
    void Function()? onUnverifiedAttemptFinished,
  }) {
    final slot = _invitationSlot(code);
    final attempts = budget ?? LanDiscoveryInviteBudget();
    final channel = LanDiscoveryChannel._(inviteHost: true);
    _InviteSession? exchange;
    Timer? proofTimeout;
    bool awaitingHello = false;
    bool charged = false;

    void clearChallenge() {
      proofTimeout?.cancel();
      exchange = null;
      awaitingHello = false;
    }

    void finishUnverified() {
      clearChallenge();
      if (charged) {
        charged = false;
        onUnverifiedAttemptFinished?.call();
      }
    }

    final expiration = Timer(const Duration(minutes: 5), channel.close);
    channel._onClose = () {
      expiration.cancel();
      finishUnverified();
    };
    if (attempts.exhausted) {
      channel.close();
      return channel;
    }
    unawaited(
      channel._run(_url(slot, 'host'), (frame) async {
        switch (frame['type']) {
          case 'relay':
            finishUnverified();
            if (frame['event'] == 'peer_joined' && channel._active) {
              charged = attempts._claim() && (claimAttempt?.call() ?? true);
              if (!charged) {
                channel.close();
                return;
              }
              awaitingHello = true;
              proofTimeout = Timer(_timeout, finishUnverified);
            }
          case 'hello' when awaitingHello:
            awaitingHello = false;
            final a = frame['a'];
            if (a is! String) {
              finishUnverified();
              return;
            }
            final BigInt aPublic;
            try {
              aPublic = LanPairingCrypto.readPublic(a);
            } on FormatException {
              finishUnverified();
              return;
            }
            final b = LanPairingCrypto.privateValue();
            final salt = LanPairingCrypto.token(16);
            final password = '$_purpose:$code';
            final bPublic = await LanPairingCrypto.serverPublic(
              salt,
              password,
              b,
            );
            final key = await LanPairingCrypto.serverKey(
              salt: salt,
              code: password,
              aPublic: aPublic,
              b: b,
              bPublic: bPublic,
            );
            if (!channel._active || !charged) return;
            exchange = _InviteSession(key, slot, salt, aPublic, bPublic);
            channel._send({
              'type': 'challenge',
              'b': bPublic.toRadixString(16),
              'salt': salt,
            });
          case 'proof':
            final session = exchange;
            exchange = null; // A challenge can verify at most one proof.
            if (session == null) {
              finishUnverified();
              return;
            }
            final verified = await session.open(frame, 'proof');
            if (!channel._active || !charged) return;
            if (verified == null) {
              finishUnverified();
              return;
            }
            charged = false;
            clearChallenge();
            // A successful discovery still requires one direct SRP exchange.
            // Return its shared TCP trial; keep its discovery admission spent.
            onProofVerified?.call();
            final box = await session.seal('offer', {
              'hostId': hostId,
              'addresses': _addresses(addresses()),
            });
            channel._send({'type': 'offer', 'box': box});
        }
      }),
    );
    return channel;
  }

  LanDiscoveryLookup lookupInvite(String code) {
    final slot = _invitationSlot(code);
    final channel = LanDiscoveryChannel._();
    final result = Completer<LanDiscoveryOffer>();
    result.future.ignore();
    final timeout = Timer(_timeout, () {
      if (!result.isCompleted) {
        result.completeError(TimeoutException('Address lookup timed out'));
      }
      channel.close();
    });
    channel._onClose = () {
      timeout.cancel();
      if (!result.isCompleted) result.completeError(_closed);
    };
    BigInt? a;
    _InviteSession? exchange;
    unawaited(
      channel._run(_url(slot, 'peer'), (frame) async {
        switch (frame['type']) {
          case 'relay':
            if (frame['event'] == 'host_left') channel.close();
            if (frame['event'] == 'host_joined' && a == null) {
              a = LanPairingCrypto.privateValue();
              final aPublic = LanPairingCrypto.generator.modPow(
                a!,
                LanPairingCrypto.modulus,
              );
              channel._send({'type': 'hello', 'a': aPublic.toRadixString(16)});
            }
          case 'challenge' when a != null && exchange == null:
            final salt = frame['salt'] as String;
            if (!RegExp(r'^[A-Za-z0-9_-]{22}$').hasMatch(salt)) {
              throw const FormatException('Invalid invitation salt');
            }
            final bPublic = LanPairingCrypto.readPublic(frame['b'] as String);
            final aPublic = LanPairingCrypto.generator.modPow(
              a!,
              LanPairingCrypto.modulus,
            );
            final key = await LanPairingCrypto.clientKey(
              salt: salt,
              code: '$_purpose:$code',
              a: a!,
              bPublic: bPublic,
            );
            exchange = _InviteSession(key, slot, salt, aPublic, bPublic);
            channel._send({
              'type': 'proof',
              'box': await exchange!.seal('proof', {}),
            });
          case 'offer' when exchange != null:
            final offer = await exchange!.open(frame, 'offer');
            if (!channel._active || offer == null) return;
            final id = offer['hostId'];
            if (id is! String || id.isEmpty || id.length > 256) {
              throw const FormatException('Invalid discovery host');
            }
            result.complete(
              LanDiscoveryOffer(id, _addresses(offer['addresses'])),
            );
            channel.close();
        }
      }),
    );
    return LanDiscoveryLookup._(result.future, channel);
  }

  LanDiscoveryChannel watchPair({
    required String secret,
    required String localId,
    required String peerId,
    required List<String> Function() addresses,
    required void Function(List<String>) onAddresses,
  }) {
    final channel = LanDiscoveryChannel._();
    unawaited(() async {
      try {
        if (localId == peerId) {
          throw const FormatException('Distinct device IDs required');
        }
        final bytes = base64Url.decode(base64Url.normalize(secret));
        if (bytes.length != 32) {
          throw const FormatException('Invalid pairing secret');
        }
        final key = SecretKey(bytes);
        Future<String> derive(String label) async => base64UrlEncode(
          (await Hmac.sha256().calculateMac(
            utf8.encode('$_purpose/$label'),
            secretKey: key,
          )).bytes,
        ).replaceAll('=', '');
        final slot = 'pair-${await derive('slot')}';
        final codec = SecureMessageCodec.fromBase64Url(
          await derive('addresses'),
        );
        final side = localId.compareTo(peerId) < 0 ? 'host' : 'peer';
        final other = side == 'host' ? 'peer' : 'host';
        bool connected = false;
        String? nonce;
        bool? queuedReciprocal;
        Timer? responseTimeout;
        void reset() {
          responseTimeout?.cancel();
          nonce = null;
          queuedReciprocal = null;
        }

        void request({bool reciprocal = false}) {
          if (!connected || !channel._active) return;
          if (nonce != null) {
            queuedReciprocal = (queuedReciprocal ?? false) || reciprocal;
            return;
          }
          responseTimeout = Timer(_timeout, channel.close);
          nonce = '${reciprocal ? 'r' : 'q'}-${LanPairingCrypto.token(24)}';
          channel._send({'type': 'who', 'nonce': nonce});
        }

        if (!channel._active) return;
        channel._onClose = reset;
        channel._onRefresh = () => request(reciprocal: true);
        await channel._run(_url(slot, side), (frame) async {
          switch (frame['type']) {
            case 'relay':
              reset();
              connected = frame['event'] == '${other}_joined';
              if (connected) request();
            case 'who' when connected:
              final received = frame['nonce'];
              if (received is! String ||
                  !RegExp(r'^[qr]-[A-Za-z0-9_-]{32}$').hasMatch(received)) {
                return;
              }
              final box = await codec.seal({
                'purpose': '$_purpose/addresses',
                'slot': slot,
                'side': side,
                'from': localId,
                'to': peerId,
                'nonce': received,
                'addresses': _addresses(addresses()),
              });
              channel._send({'type': 'addresses', 'box': box});
              // A changed adapter asks its peer to challenge it in return.
              if (received.startsWith('r-')) request();
            case 'addresses' when connected && nonce != null:
              final offer = await _open(codec, frame);
              if (!channel._active ||
                  offer == null ||
                  offer['purpose'] != '$_purpose/addresses' ||
                  offer['slot'] != slot ||
                  offer['side'] != other ||
                  offer['from'] != peerId ||
                  offer['to'] != localId ||
                  offer['nonce'] != nonce) {
                return;
              }
              final queued = queuedReciprocal;
              reset();
              onAddresses(_addresses(offer['addresses']));
              if (queued != null) request(reciprocal: queued);
          }
        });
      } catch (error) {
        channel._finish(error);
      }
    }());
    return channel;
  }

  List<String> _addresses(Object? value) {
    if (value is! List) return const [];
    final result = <String>{};
    for (final candidate in value.whereType<String>()) {
      final ip = InternetAddress.tryParse(candidate);
      if (ip != null &&
          ip.type == InternetAddressType.IPv4 &&
          ip.address == candidate &&
          ((isPrivateLanIPv4(ip) && !ip.isLinkLocal) ||
              (allowLoopbackCandidates && ip.isLoopback))) {
        result.add(candidate);
      }
      if (result.length == 8) break;
    }
    return List.unmodifiable(result);
  }
}

final class _InviteSession {
  _InviteSession(String key, String slot, String salt, BigInt a, BigInt b)
    : codec = SecureMessageCodec.fromBase64Url(key),
      transcript = '$slot/$salt/${a.toRadixString(16)}/${b.toRadixString(16)}';
  final SecureMessageCodec codec;
  final String transcript;

  Future<String> seal(String kind, _Frame values) => codec.seal({
    'purpose': '$_purpose/$kind',
    'transcript': transcript,
    ...values,
  });

  Future<_Frame?> open(_Frame frame, String kind) async {
    final payload = await _open(codec, frame);
    return payload != null &&
            payload['purpose'] == '$_purpose/$kind' &&
            payload['transcript'] == transcript
        ? payload
        : null;
  }
}

Future<_Frame?> _open(SecureMessageCodec codec, _Frame frame) async {
  try {
    return await codec.open(frame['box'] as String);
  } on Object {
    return null;
  }
}
