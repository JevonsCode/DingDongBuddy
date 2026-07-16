import 'package:dingdong/core/models/resource.dart';

const String builtInReplyMarkerPromptId =
    'dingdong.builtin.reply-marker-prompt.v1';

/// Creates the small, visible prompt used to verify Agent prompt activation.
Resource builtInReplyMarkerPrompt(DateTime timestamp) {
  final DateTime utcTimestamp = timestamp.toUtc();
  return Resource(
    id: builtInReplyMarkerPromptId,
    type: ResourceType.prompt,
    group: 'DingDong',
    title: '回复末尾添加 🌟',
    content: '每次完整回复的最后加一个「🌟」',
    tags: const <String>['DingDong', '内置', '验证'],
    source: 'DingDong',
    pinned: true,
    enabled: true,
    activation: ResourceActivation.always,
    createdAt: utcTimestamp,
    updatedAt: utcTimestamp,
  );
}
