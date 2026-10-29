import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/platform/native_agent_conversation_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final spec in <(String, String, String, String)>[
    ('Pi', 'pi', 'pi', '--session'),
    ('OpenCode CLI', 'opencode-cli', 'opencode', '--session'),
    ('Antigravity CLI', 'antigravity-cli', 'agy', '--conversation'),
    ('GitHub Copilot CLI', 'copilot-cli', 'copilot', '--resume'),
    ('Grok Build', 'grok-build', 'grok', '--resume'),
  ]) {
    test('${spec.$1} resumes the identified CLI session', () async {
      List<String>? launched;
      final launcher = NativeAgentConversationLauncher(
        operatingSystem: 'macos',
        processStarter: (command, args, {workingDirectory}) async {
          launched = args;
        },
      );
      const id = 'a45cce14-b0be-4aea-a8f9-e88195674770';
      final target = AgentConversationTarget.fromJson({
        'client': spec.$1,
        'conversationId': id,
        'workspacePath': '/workspace/project',
      });
      expect(target.client.apiValue, spec.$2);
      expect(launcher.canOpen(target), isTrue);
      await launcher.open(target);
      expect(launched!.last, contains("exec '${spec.$3}' '${spec.$4}' '$id'"));
    });
  }

  test('ambiguous and desktop sources never resume in a terminal', () {
    final launcher = NativeAgentConversationLauncher(operatingSystem: 'macos');
    for (final source in [
      'OpenCode',
      'OpenCode Desktop',
      'Antigravity',
      'Antigravity IDE',
      'GitHub Copilot',
      'GitHub Copilot VS Code',
      'Windsurf',
      'Grok',
      'Grok Web',
    ]) {
      final target = AgentConversationTarget(
        client: AgentClient.fromSource(source),
        conversationId: 'session-1',
        workspacePath: '/workspace/project',
      );
      expect(launcher.canOpen(target), isFalse, reason: source);
    }
  });

  test('recognizes the full Pi coding agent name', () {
    expect(AgentClient.fromSource('Pi Coding Agent'), AgentClient.pi);
  });

  test('Pi refuses partial session IDs that could match another session', () {
    final launcher = NativeAgentConversationLauncher(operatingSystem: 'macos');
    expect(
      launcher.canOpen(
        const AgentConversationTarget(
          client: AgentClient.pi,
          conversationId: 'a45cce14',
          workspacePath: '/workspace/project',
        ),
      ),
      isFalse,
    );
  });
}
