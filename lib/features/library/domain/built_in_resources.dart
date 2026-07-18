import 'package:dingdong/core/models/resource.dart';

const String builtInReplyMarkerPromptId =
    'dingdong.builtin.reply-marker-prompt.v1';
const String builtInDingDongConfigureSkillId =
    'dingdong.builtin.configure-skill.v1';
const String builtInDingDongConfigureSkillSource = 'DingDong Built-in';
const String builtInDingDongConfigureSkillUpdateUrl =
    'https://github.com/JevonsCode/DingDongBuddy/tree/main/skills/dingdong-configure';

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

/// Creates the bundled operator Skill while retaining its public update link.
Resource builtInDingDongConfigureSkill(String document, DateTime timestamp) {
  final DateTime utcTimestamp = timestamp.toUtc();
  return Resource(
    id: builtInDingDongConfigureSkillId,
    type: ResourceType.skill,
    group: 'DingDong',
    title: 'DingDong Configure',
    content: document,
    tags: const <String>[
      'DingDong',
      'built-in',
      'configuration',
      'trigger-groups',
    ],
    source: builtInDingDongConfigureSkillSource,
    updateUrl: builtInDingDongConfigureSkillUpdateUrl,
    enabled: true,
    activation: ResourceActivation.manual,
    createdAt: utcTimestamp,
    updatedAt: utcTimestamp,
  );
}
