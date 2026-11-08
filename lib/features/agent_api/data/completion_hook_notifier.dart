import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:dingdong/features/activity/domain/agent_notification_kind.dart';
import 'package:dingdong/features/agent_api/data/agent_source_identity.dart';
import 'package:dingdong/features/agent_api/data/loopback_mcp_tool_executor.dart';
import 'package:path/path.dart' as path;

/// Delivers the durable Agent stop notification and classifies pending input.
final class CompletionHookNotifier {
  CompletionHookNotifier(this._transport, {Map<String, String>? environment})
    : _environment = environment ?? Platform.environment;

  final McpHttpTransport _transport;
  final Map<String, String> _environment;

  Future<Map<String, Object?>> notify(
    String hookInput, {
    String? sourceOverride,
  }) async {
    final Map<String, Object?> input = _decodeInput(hookInput);
    final String requestedSource = _source(
      input,
      sourceOverride: sourceOverride,
      environment: _environment,
    );
    final String source = requestedSource.toLowerCase() == 'antigravity'
        ? _antigravitySource(input, _environment) ?? requestedSource
        : requestedSource;
    // Antigravity can emit Stop while background work is still active.
    if ((source.toLowerCase().contains('antigravity') ||
            source.toLowerCase() == 'agy') &&
        input['fullyIdle'] != true) {
      return const <String, Object?>{'status': 'ignored'};
    }
    final String? completionMessage = await _completionMessage(input);
    final AgentNotificationKind notificationKind = await _notificationKind(
      input,
      completionMessage,
    );
    final String? summary = _oneLineSummary(completionMessage);
    final String? detail = _notificationDetail(completionMessage);
    final String? conversationId = _firstText(input, const <String>[
      'session_id',
      'sessionId',
      'conversation_id',
      'conversationId',
      'thread_id',
      'threadId',
    ]);
    final String? workspacePath =
        _firstText(input, const <String>[
          'cwd',
          'workspace_path',
          'workspacePath',
        ]) ??
        _firstWorkspaceRoot(input['workspace_roots']) ??
        _onlyWorkspaceRoot(input['workspacePaths']);
    final String? transcriptPath = _firstText(input, const <String>[
      'transcript_path',
      'transcriptPath',
    ]);
    return _transport.request(
      method: 'POST',
      path: '/ding',
      body: <String, Object?>{
        'message': ?summary,
        if (detail != null && detail != summary) 'detail': detail,
        'source': source,
        'flashCount': 4,
        'fallback': true,
        if (notificationKind != AgentNotificationKind.completion)
          'notificationKind': notificationKind.apiValue,
        'conversationId': ?conversationId,
        if (source == 'Claude Desktop')
          'hostSessionId': _environment['CLAUDE_CODE_HOST_SESSION_ID'],
        'workspacePath': ?workspacePath,
        'transcriptPath': ?transcriptPath,
      },
    );
  }
}

/// Decides which reminder a hook event plays, strongest evidence first: what
/// the host says the event is, an explicit kind, the Agent's own
/// dingdong_notify call in this turn, and only then the final reply's text.
Future<AgentNotificationKind> _notificationKind(
  Map<String, Object?> input,
  String? message,
) async {
  final String eventName = (input['hook_event_name'] as String? ?? '')
      .trim()
      .toLowerCase();
  if (eventName == 'sessionend') {
    return AgentNotificationKind.completion;
  }
  // Claude Code raises Notification for permission prompts, questions and
  // idle input, and PermissionRequest before a permission dialog. Both mean
  // the Agent is waiting on the user, whatever the message says.
  if (eventName == 'permissionrequest') {
    return AgentNotificationKind.attention;
  }
  final Object? explicit =
      input['notificationKind'] ?? input['notification_type'] ?? input['kind'];
  final AgentNotificationKind? explicitKind = AgentNotificationKind.tryParse(
    explicit,
  );
  if (explicitKind != null) {
    return explicitKind;
  }
  if (eventName == 'notification') {
    // auth_success and other informational notices are not a finished task
    // either, but they never need the user: keep them on the quieter sound.
    return explicit is String && explicit.trim().isNotEmpty
        ? AgentNotificationKind.completion
        : AgentNotificationKind.attention;
  }
  final String? transcriptPath = _firstText(input, const <String>[
    'transcript_path',
    'transcriptPath',
  ]);
  if (transcriptPath != null &&
      await _turnRequestedAttention(File(transcriptPath))) {
    return AgentNotificationKind.attention;
  }
  return replyNeedsUserAttention(message)
      ? AgentNotificationKind.attention
      : AgentNotificationKind.completion;
}

/// Whether an Agent's final reply asks the user to act or answer.
///
/// Quoted text, code, table rows and Agent receipts are ignored: a report
/// quotes UI labels (「请选择」), commands and cells that are not addressed to
/// the user. Reported states such as "not committed" are results, not
/// requests. A reply whose last line is a question waits for an answer.
bool replyNeedsUserAttention(String? message) {
  if (message == null || message.trim().isEmpty) {
    return false;
  }
  final List<String> lines = <String>[];
  bool inCode = false;
  for (final String raw in message.replaceAll('\r', '').split('\n')) {
    if (raw.trimLeft().startsWith('```')) {
      inCode = !inCode;
      continue;
    }
    if (inCode || raw.trimLeft().startsWith('|')) continue;
    final String line = _cleanMarkdownLine(raw);
    if (line.isEmpty ||
        _genericHeading(line) ||
        _isAgentBridgeMarkerLine(line) ||
        _isReceiptLine(line)) {
      continue;
    }
    final String normalized = line
        .replaceAll(_quotedText, ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    if (normalized.isNotEmpty) lines.add(normalized);
  }
  if (lines.isEmpty) {
    return false;
  }
  if (RegExp(r'[?？]\s*$').hasMatch(lines.last)) {
    return true;
  }
  String text = lines.join('\n');
  for (final String negated in _negatedRequests) {
    text = text.replaceAll(negated, ' ');
  }
  return _attentionMarkers.any(text.contains) ||
      _chineseRequest.hasMatch(text) ||
      RegExp(
        r'(?:是否|要不要|do you want|would you like).{0,40}[?？]',
      ).hasMatch(text);
}

/// 请 opening a clause addresses the reader (请点取消、请在手机打开); 请求,
/// 申请 and 邀请 do not.
final RegExp _chineseRequest = RegExp(
  r'(?:^|[，。；！？、,.;!?:：\s🟥])请(?!求)',
  multiLine: true,
  unicode: true,
);

final RegExp _quotedText = RegExp(
  r'「[^」\n]{0,80}」|『[^』\n]{0,80}』|“[^”\n]{0,80}”|"[^"\n]{0,80}"|《[^》\n]{0,80}》|‘[^’\n]{0,80}’',
);

/// "Nothing is needed from you" reports that the user can stay away.
const List<String> _negatedRequests = <String>[
  '不需要你',
  '不需要您',
  '无需你',
  '无需您',
  '不用你',
  '不必你',
  'nothing needed from you',
  'nothing is needed from you',
  'no action needed from you',
  'no action is needed from you',
  "don't need your",
  "doesn't need your",
  'do not need your',
  'does not need your',
  'no need for your',
];

// 待确认 alone is not here: reports use it as a noun ("100 条待确认").
const List<String> _attentionMarkers = <String>[
  '需确认',
  '待裁决',
  '等待负责人',
  '等待人工',
  '要求你',
  '需要重新登录',
  '请确认',
  '等待确认',
  '等你确认',
  '你确认后',
  '待你确认',
  '请确定',
  '需要先确定',
  '请先选择',
  '请选择',
  '需要你',
  '需要您',
  '等你回复',
  '等待你的回复',
  '请回复',
  '请接管',
  '等待授权',
  '请授权',
  '请批准',
  '请放行',
  '请允许',
  '请决定',
  '请告诉我',
  '请提供',
  '请粘贴',
  '待你决定',
  '等你决定',
  '由你决定',
  'please confirm',
  'please approve',
  'please allow',
  'please grant',
  'please choose',
  'please select',
  'please decide',
  'please reply',
  'please answer',
  'please provide',
  'please paste',
  'please send',
  'please tell me',
  'please let me know',
  'please take over',
  'please stop',
  'please pause',
  'please sign in',
  'please log in',
  'awaiting your',
  'waiting for your',
  'waiting for you to',
  'waiting on you',
  'need your',
  'needs your',
  'needed from you',
  'need you to',
  'needs you to',
  'up to you',
];

/// Agent receipts and bridge footers close many replies; they are never the
/// request itself.
bool _isReceiptLine(String line) =>
    line.contains('fuli://') ||
    RegExp(r'^(?:FULI|DingDong)\b', caseSensitive: false).hasMatch(line);

/// Whether the transcript's latest turn already asked for attention through
/// dingdong_notify. The Stop hook that follows reports the same turn, so it
/// must play the attention sound too instead of a completion right after.
Future<bool> _turnRequestedAttention(File transcript) async {
  final List<String>? lines = await _transcriptTailLines(transcript);
  if (lines == null) return false;
  for (final String line in lines.reversed) {
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } on Object {
      continue;
    }
    if (decoded is! Map<String, Object?>) continue;
    if (_isUserPrompt(decoded)) return false;
    for (final Map<String, Object?> input in _notifyCallInputs(decoded)) {
      final Object? reminderId = input['reminderId'];
      final AgentNotificationKind kind =
          reminderId is String && reminderId.trim().isNotEmpty
          ? AgentNotificationKind.tryParse(reminderId) ??
                AgentNotificationKind.completion
          : AgentNotificationKind.tryParse(input['notificationKind']) ??
                AgentNotificationKind.attention;
      if (kind == AgentNotificationKind.attention) return true;
    }
  }
  return false;
}

/// A message the user typed, which starts a new turn. Tool results and
/// injected context are recorded as user entries too and do not count.
bool _isUserPrompt(Map<String, Object?> entry) {
  final Object? payload = entry['payload'];
  if (entry['type'] == 'event_msg' &&
      payload is Map<String, Object?> &&
      payload['type'] == 'user_message') {
    return true;
  }
  final Object? message = entry['message'];
  if (entry['type'] != 'user' ||
      entry['isMeta'] == true ||
      message is! Map<String, Object?>) {
    return false;
  }
  final Object? content = message['content'];
  if (content is String) return content.trim().isNotEmpty;
  return content is List<Object?> &&
      content.whereType<Map<String, Object?>>().any(
        (Map<String, Object?> item) => item['type'] == 'text',
      );
}

/// Arguments of dingdong_notify calls in one Claude Code or Codex entry.
Iterable<Map<String, Object?>> _notifyCallInputs(
  Map<String, Object?> entry,
) sync* {
  final Object? payload = entry['payload'];
  if (entry['type'] == 'response_item' &&
      payload is Map<String, Object?> &&
      payload['type'] == 'function_call' &&
      _isNotifyTool(payload['name'], payload['namespace'])) {
    final Object? arguments = payload['arguments'];
    Object? decoded = arguments;
    if (arguments is String) {
      try {
        decoded = jsonDecode(arguments);
      } on Object {
        decoded = null;
      }
    }
    yield decoded is Map<String, Object?> ? decoded : <String, Object?>{};
  }
  final Object? message = entry['message'];
  if (entry['type'] == 'assistant' && message is Map<String, Object?>) {
    final Object? content = message['content'];
    if (content is! List<Object?>) return;
    for (final Map<String, Object?> item
        in content.whereType<Map<String, Object?>>()) {
      if (item['type'] == 'tool_use' && _isNotifyTool(item['name'], null)) {
        final Object? input = item['input'];
        yield input is Map<String, Object?> ? input : <String, Object?>{};
      }
    }
  }
}

bool _isNotifyTool(Object? name, Object? namespace) {
  if (name is! String) return false;
  if (name == 'dingdong_notify') {
    return namespace == null ||
        (namespace is String && namespace.toLowerCase().contains('dingdong'));
  }
  return name.endsWith('__dingdong_notify');
}

Map<String, Object?> _decodeInput(String input) {
  if (input.trim().isEmpty) {
    return <String, Object?>{};
  }
  try {
    return jsonDecode(input) as Map<String, Object?>;
  } on Object {
    return <String, Object?>{};
  }
}

String _source(
  Map<String, Object?> input, {
  String? sourceOverride,
  required Map<String, String> environment,
}) {
  final String explicit = (sourceOverride ?? '').trim();
  final String configured = (input['agent_name'] as String? ?? '').trim();
  return resolveActivitySource(
        explicit.isNotEmpty ? explicit : configured,
        inferAgentSourceFromEnvironment(environment),
      ) ??
      'Codex';
}

Future<String?> _completionMessage(Map<String, Object?> input) async {
  for (final String key in const <String>[
    'summary',
    'last_assistant_message',
    'last-assistant-message',
    'lastAssistantMessage',
    'assistant_message',
    'prompt_response',
    'assistant_response',
    'text',
  ]) {
    final Object? value = input[key];
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
  }

  final String? transcriptPath = _firstText(input, const <String>[
    'transcript_path',
    'transcriptPath',
  ]);
  if (transcriptPath == null) {
    return null;
  }
  try {
    return await _lastAssistantMessage(File(transcriptPath));
  } on Object {
    return null;
  }
}

String? _firstText(Map<String, Object?> input, List<String> keys) {
  for (final String key in keys) {
    final Object? value = input[key];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
  }
  return null;
}

String? _firstWorkspaceRoot(Object? value) {
  if (value is! List<Object?>) {
    return null;
  }
  for (final Object? root in value) {
    if (root is String && root.trim().isNotEmpty) {
      return root.trim();
    }
  }
  return null;
}

String? _onlyWorkspaceRoot(Object? value) {
  if (value is! List<Object?>) return null;
  final List<String> roots = value
      .whereType<String>()
      .map((String root) => root.trim())
      .where((String root) => root.isNotEmpty)
      .toSet()
      .toList();
  return roots.length == 1 ? roots.single : null;
}

String? _antigravitySource(
  Map<String, Object?> input,
  Map<String, String> environment,
) {
  final String? id = _firstText(input, const <String>['conversationId']);
  final String? transcript = _firstText(input, const <String>[
    'transcriptPath',
  ]);
  final String home = (environment['HOME'] ?? environment['USERPROFILE'] ?? '')
      .trim();
  if (id == null ||
      transcript == null ||
      !path.isAbsolute(home) ||
      !RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
      ).hasMatch(id)) {
    return null;
  }
  final String actual = path.normalize(
    transcript.startsWith('~/')
        ? path.join(home, transcript.substring(2))
        : transcript,
  );
  for (final (String directory, String source) in <(String, String)>[
    ('antigravity-cli', 'Antigravity CLI'),
    ('antigravity-ide', 'Antigravity IDE'),
    ('antigravity', 'Antigravity App'),
  ]) {
    final String expected = path.normalize(
      path.joinAll(<String>[
        home,
        '.gemini',
        directory,
        'brain',
        id,
        '.system_generated',
        'logs',
        'transcript.jsonl',
      ]),
    );
    if (path.equals(actual, expected)) return source;
  }
  return null;
}

/// The last megabyte of a JSONL transcript, as whole lines.
Future<List<String>?> _transcriptTailLines(File transcript) async {
  try {
    if (!await transcript.exists()) {
      return null;
    }
    final RandomAccessFile handle = await transcript.open();
    try {
      final int length = await handle.length();
      if (length == 0) {
        return null;
      }
      const int maximumBytes = 1024 * 1024;
      final int start = math.max(0, length - maximumBytes);
      await handle.setPosition(start);
      String text = utf8.decode(
        await handle.read(length - start),
        allowMalformed: true,
      );
      if (start > 0) {
        final int firstNewline = text.indexOf('\n');
        if (firstNewline < 0) {
          return null;
        }
        text = text.substring(firstNewline + 1);
      }
      return const LineSplitter().convert(text);
    } finally {
      await handle.close();
    }
  } on FileSystemException {
    return null;
  }
}

Future<String?> _lastAssistantMessage(File transcript) async {
  final List<String>? lines = await _transcriptTailLines(transcript);
  if (lines == null) {
    return null;
  }
  String? latestAssistantMessage;
  for (final String line in lines.reversed) {
    final _TranscriptMessage? message = _decodeTranscriptMessage(line);
    if (message == null) {
      continue;
    }
    latestAssistantMessage ??= message.text;
    if (message.finalAnswer) {
      return message.text;
    }
  }
  return latestAssistantMessage;
}

_TranscriptMessage? _decodeTranscriptMessage(String line) {
  try {
    final Object? decoded = jsonDecode(line);
    if (decoded is! Map<String, Object?>) {
      return null;
    }

    // Codex JSONL transcript entry.
    final Object? rawPayload = decoded['payload'];
    if (decoded['type'] == 'response_item' &&
        rawPayload is Map<String, Object?> &&
        rawPayload['type'] == 'message' &&
        rawPayload['role'] == 'assistant') {
      final String? text = _textContent(rawPayload['content']);
      return text == null
          ? null
          : _TranscriptMessage(
              text,
              finalAnswer: rawPayload['phase'] == 'final_answer',
            );
    }

    // Claude Code and compatible JSONL transcript entry.
    final Object? rawMessage = decoded['message'];
    if (decoded['type'] == 'assistant' &&
        rawMessage is Map<String, Object?> &&
        rawMessage['role'] == 'assistant') {
      final String? text = _textContent(rawMessage['content']);
      return text == null ? null : _TranscriptMessage(text, finalAnswer: true);
    }
  } on Object {
    return null;
  }
  return null;
}

String? _textContent(Object? rawContent) {
  if (rawContent is String) {
    return rawContent.trim().isEmpty ? null : rawContent;
  }
  if (rawContent is! List<Object?>) {
    return null;
  }
  final String text = rawContent
      .whereType<Map<String, Object?>>()
      .where(
        (Map<String, Object?> item) =>
            item['type'] == 'output_text' || item['type'] == 'text',
      )
      .map((Map<String, Object?> item) => item['text'])
      .whereType<String>()
      .join('\n')
      .trim();
  return text.isEmpty ? null : text;
}

String? _oneLineSummary(Object? rawMessage) {
  if (rawMessage is! String || rawMessage.trim().isEmpty) {
    return null;
  }
  final List<String> candidates = rawMessage
      .replaceAll('\r', '')
      .split('\n')
      .map(_cleanMarkdownLine)
      .where((String line) => line.isNotEmpty && !_genericHeading(line))
      .toList(growable: false);
  if (candidates.isEmpty) {
    return null;
  }
  final int firstContentIndex = candidates.indexWhere(
    (String line) => !_isAgentBridgeMarkerLine(line),
  );
  if (firstContentIndex < 0) {
    return null;
  }
  final String first = candidates[firstContentIndex];
  final String sentence = _firstSentence(
    first,
  ).replaceFirst(RegExp(r'[:：]\s*$'), '');
  const int maximumRunes = 96;
  final List<int> runes = sentence.runes.toList(growable: false);
  if (runes.length <= maximumRunes) {
    return sentence;
  }
  return '${String.fromCharCodes(runes.take(maximumRunes))}…';
}

String? _notificationDetail(Object? rawMessage) {
  if (rawMessage is! String || rawMessage.trim().isEmpty) return null;
  final List<String> lines = rawMessage
      .replaceAll('\r', '')
      .split('\n')
      .map(_cleanMarkdownLine)
      .where(
        (String line) =>
            line.isNotEmpty &&
            !_genericHeading(line) &&
            !_isAgentBridgeMarkerLine(line),
      )
      .toList(growable: false);
  if (lines.isEmpty) return null;
  final String detail = lines.join('\n');
  const int maximumRunes = 720;
  final List<int> runes = detail.runes.toList(growable: false);
  return runes.length <= maximumRunes
      ? detail
      : '${String.fromCharCodes(runes.take(maximumRunes))}…';
}

String _cleanMarkdownLine(String rawLine) {
  String line = rawLine.trim();
  if (line.isEmpty ||
      line.startsWith('```') ||
      line.startsWith('::') ||
      line.startsWith('![')) {
    return '';
  }
  line = line
      .replaceFirst(RegExp(r'^#{1,6}\s+'), '')
      .replaceFirst(RegExp(r'^(?:[-*+]\s+|\d+[.)]\s+)'), '')
      .replaceAllMapped(
        RegExp(r'\[([^\]]+)\]\([^)]+\)'),
        (Match match) => match.group(1) ?? '',
      )
      .replaceAll(RegExp(r'[*_`]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return line;
}

bool _genericHeading(String line) {
  return RegExp(
    r'^(?:完成|完成情况|结果|总结|结论|done|result|summary)[:：]?$',
    caseSensitive: false,
  ).hasMatch(line);
}

bool _isAgentBridgeMarkerLine(String line) => RegExp(
  r'^[^A-Za-z0-9\u3400-\u9FFF]*(?:DingDong|FULI)(?:\s*(?:[·•|｜:：—-].*)?)$',
  caseSensitive: false,
).hasMatch(line);

String _firstSentence(String line) {
  final Match? match = RegExp(r'^(.{8,}?[。！？!?])(?:\s|$)').firstMatch(line);
  return match?.group(1) ?? line;
}

final class _TranscriptMessage {
  const _TranscriptMessage(this.text, {required this.finalAnswer});

  final String text;
  final bool finalAnswer;
}
