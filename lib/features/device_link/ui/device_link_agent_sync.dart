part of 'device_link_controller.dart';

// Build bounded Agent snapshots and encrypted background push payloads.
extension _DeviceLinkAgentSync on DeviceLinkController {
  Future<void> _sendPush(
    LinkedDevice device,
    Map<String, Object?> message,
  ) async {
    final Uri? relay = device.relayUrl ?? _relayBaseUrl;
    if (relay == null) return;
    final SecureMessageCodec codec = SecureMessageCodec.fromBase64Url(
      device.secret,
    );
    final SecretKey secretKey = SecretKey(
      base64Url.decode(base64Url.normalize(device.secret)),
    );
    final Mac tokenMac = await Hmac.sha256().calculateMac(
      utf8.encode('dingdong-push-v1'),
      secretKey: secretKey,
    );
    final String token = base64Url.encode(tokenMac.bytes).replaceAll('=', '');
    final HttpClient client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5);
    try {
      final ({Map<String, Object?> message, String envelope}) push =
          await _sealCompactAgentPush(codec, message);
      final HttpClientRequest request = await client.postUrl(
        _relayApiUri(relay, 'v1/push/${device.room}'),
      );
      request.headers
        ..contentType = ContentType.json
        ..set(HttpHeaders.authorizationHeader, 'Bearer $token');
      request.write(
        jsonEncode(<String, Object?>{
          'envelope': push.envelope,
          'messageId': push.message['id'],
        }),
      );
      final HttpClientResponse response = await request.close().timeout(
        const Duration(seconds: 8),
      );
      final String responseBody = await utf8.decoder
          .bind(response)
          .join()
          .timeout(const Duration(seconds: 8));
      final Object? decoded = responseBody.isEmpty
          ? null
          : jsonDecode(responseBody);
      final bool accepted =
          decoded is Map<String, Object?> && decoded['accepted'] == true;
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          !accepted) {
        final Object? reason = decoded is Map<String, Object?>
            ? decoded['reason'] ?? decoded['error']
            : null;
        throw HttpException(
          'Push provider did not accept the message '
          '(${response.statusCode}${reason == null ? '' : ', $reason'})',
        );
      }
    } finally {
      client.close(force: true);
    }
  }

  Future<({Map<String, Object?> message, String envelope})>
  _sealCompactAgentPush(
    SecureMessageCodec codec,
    Map<String, Object?> message,
  ) async {
    var titleBytes = 120;
    var sourceBytes = 120;
    var summaryBytes = 480;
    var detailBytes = 1300;
    for (var attempt = 0; attempt < 20; attempt += 1) {
      final Map<String, Object?> compact = _compactAgentPush(
        message,
        titleBytes: titleBytes,
        sourceBytes: sourceBytes,
        summaryBytes: summaryBytes,
        detailBytes: detailBytes,
      );
      final String envelope = await codec.seal(compact);
      if (utf8.encode(envelope).length <= 3500) {
        return (message: compact, envelope: envelope);
      }
      if (detailBytes > 160) {
        detailBytes = max(160, (detailBytes * 0.7).floor());
      } else if (summaryBytes > 120) {
        summaryBytes = max(120, (summaryBytes * 0.7).floor());
      } else if (sourceBytes > 48) {
        sourceBytes = max(48, (sourceBytes * 0.7).floor());
      } else if (titleBytes > 48) {
        titleBytes = max(48, (titleBytes * 0.7).floor());
      } else {
        break;
      }
    }
    throw const FormatException('Agent notification exceeds push envelope');
  }

  Map<String, Object?> _compactAgentPush(
    Map<String, Object?> message, {
    required int titleBytes,
    required int sourceBytes,
    required int summaryBytes,
    required int detailBytes,
  }) => <String, Object?>{
    'type': 'agent.completed',
    'id': message['id'],
    'activityId': message['activityId'],
    'title': _truncateUtf8(message['title'], titleBytes),
    'source': _truncateUtf8(message['source'], sourceBytes),
    'summary': _truncateUtf8(message['summary'], summaryBytes),
    'detail': _truncateUtf8(message['detail'], detailBytes),
    if (message['task'] != null)
      'task': _truncateUtf8(message['task'], summaryBytes),
    if (message['workspacePath'] != null)
      'workspacePath': _truncateUtf8(message['workspacePath'], 512),
    'notificationKind': message['notificationKind'] == 'attention'
        ? 'attention'
        : 'completion',
    'needsUserAttention': message['needsUserAttention'] == true,
    'unseen': message['unseen'] != false,
    if (message['startedAt'] != null) 'startedAt': message['startedAt'],
    'completedAt': message['completedAt'],
    'vibrate': message['vibrate'] != false,
  };

  Future<void> _broadcastAgentState() async {
    for (final LinkedDevice device in _devices) {
      if (device.kind == LinkedDeviceKind.computer) continue;
      if (!isConnected(device.id)) continue;
      try {
        await _sendAgentState(_sessionForDevice(device.id));
      } on Object {
        // A reconnect receives the same authoritative snapshot after hello.
      }
    }
  }

  Future<void> _sendAgentState(_ManagedDeviceSession managed) async {
    final AgentStateProvider? provider = _agentStateProvider;
    if (provider == null) return;
    final snapshot = provider();
    await managed.handle.send(<String, Object?>{
      'type': 'agent.state',
      'generatedAt': DateTime.now().toUtc().toIso8601String(),
      'running': snapshot.activeRuns
          .take(deviceLinkAgentRunningLimit)
          .map(_agentRunPayload)
          .toList(growable: false),
      'completed': snapshot.activities
          .take(deviceLinkAgentHistoryLimit)
          .map(_agentActivityPayload)
          .toList(growable: false),
    });
  }

  Map<String, Object?> _agentRunPayload(AgentTaskRun run) => <String, Object?>{
    'id': run.id,
    'source': _truncateUtf8(run.source, 96),
    'task': _truncateUtf8(run.task, 600),
    'startedAt': run.startedAt.toUtc().toIso8601String(),
    if (run.conversationTarget?.workspacePath != null)
      'workspacePath': _truncateUtf8(
        run.conversationTarget!.workspacePath,
        320,
      ),
  };

  Map<String, Object?> _agentActivityPayload(AgentActivity activity) =>
      <String, Object?>{
        'id': activity.id,
        'activityId': activity.id,
        'title': activity.needsUserAttention
            ? _localizations().agentNeedsYourAttention
            : _localizations().agentCompleted,
        'source': _truncateUtf8(activity.source, 96),
        'summary': _truncateUtf8(activity.message, 480),
        'detail': _truncateUtf8(activity.detail ?? activity.message, 1200),
        'notificationKind': activity.notificationKind.apiValue,
        'needsUserAttention': activity.needsUserAttention,
        'unseen': activity.unseen,
        if (activity.task != null) 'task': _truncateUtf8(activity.task, 480),
        if (activity.startedAt != null)
          'startedAt': activity.startedAt!.toUtc().toIso8601String(),
        'completedAt': activity.completedAt.toUtc().toIso8601String(),
        if (activity.conversationTarget?.workspacePath != null)
          'workspacePath': _truncateUtf8(
            activity.conversationTarget!.workspacePath,
            320,
          ),
      };

  String _truncateUtf8(Object? value, int maximumBytes) {
    final String text = (value ?? '').toString();
    if (utf8.encode(text).length <= maximumBytes) return text;
    const String suffix = '…';
    final int contentBudget = maximumBytes - utf8.encode(suffix).length;
    final StringBuffer result = StringBuffer();
    var bytes = 0;
    for (final int rune in text.runes) {
      final String character = String.fromCharCode(rune);
      final int characterBytes = utf8.encode(character).length;
      if (bytes + characterBytes > contentBudget) break;
      result.write(character);
      bytes += characterBytes;
    }
    return '${result.toString()}$suffix';
  }
}
