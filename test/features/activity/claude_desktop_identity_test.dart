import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/agent_api/data/agent_source_identity.dart';
import 'package:dingdong/features/agent_api/data/ding_request.dart';
import 'package:dingdong/platform/native_agent_conversation_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('distinguishes the desktop process from the terminal', () {
    expect(
      inferAgentSourceFromEnvironment(const {
        'CLAUDE_CODE_ENTRYPOINT': 'claude-desktop',
        'CLAUDE_CODE_SESSION_ID': 'cli-session',
        'CLAUDECODE': '1',
      }),
      'Claude Desktop',
    );
    expect(
      inferAgentSourceFromEnvironment(const {
        'CLAUDE_CODE_ENTRYPOINT': 'cli',
        'CLAUDE_CODE_SESSION_ID': 'cli-session',
      }),
      'Claude Code',
    );
  });

  test('desktop notifications keep both session identities', () {
    final request = DingRequest.parse('''
      {"source":"Claude Desktop","conversationId":"cli-session",
       "hostSessionId":"local_01234567-89ab-cdef-0123-456789abcdef"}
    ''');

    expect(request.conversationTarget?.toJson(), {
      'client': 'claude-desktop',
      'conversationId': 'cli-session',
      'hostSessionId': 'local_01234567-89ab-cdef-0123-456789abcdef',
    });
  });

  test('desktop target opens its original session in Claude Desktop', () async {
    Uri? opened;
    final launcher = NativeAgentConversationLauncher(
      operatingSystem: 'macos',
      uriOpener: (uri) async {
        opened = uri;
        return true;
      },
    );
    final target = AgentConversationTarget.fromJson({
      'client': 'claude-desktop',
      'conversationId': 'cli-session',
      'hostSessionId': 'local_01234567-89ab-cdef-0123-456789abcdef',
    });

    expect(launcher.canOpen(target), isTrue);
    await launcher.open(target);
    expect(opened?.scheme, 'claude');
    expect(opened?.host, 'code');
    expect(opened?.path, '/continue');
    expect(
      opened?.queryParameters['session'],
      'local_01234567-89ab-cdef-0123-456789abcdef',
    );
  });

  test('desktop target is not clickable without a valid native session ID', () {
    final launcher = NativeAgentConversationLauncher(operatingSystem: 'macos');
    for (final value in [null, 'not-a-desktop-session', 'local_../other']) {
      expect(
        launcher.canOpen(
          AgentConversationTarget(
            client: AgentClient.claudeDesktop,
            conversationId: 'cli-session',
            hostSessionId: value,
          ),
        ),
        isFalse,
      );
    }
  });
}
