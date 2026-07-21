import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/platform/native_agent_conversation_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Codex conversation opens through its allow-listed thread URL',
    () async {
      Uri? opened;
      final NativeAgentConversationLauncher launcher =
          NativeAgentConversationLauncher(
            operatingSystem: 'macos',
            uriOpener: (Uri uri) async {
              opened = uri;
              return true;
            },
          );
      const AgentConversationTarget target = AgentConversationTarget(
        client: AgentClient.codex,
        conversationId: 'thread-1',
      );

      expect(launcher.canOpen(target), isTrue);
      await launcher.open(target);

      expect(opened.toString(), 'codex://threads/thread-1');
    },
  );

  test('Kiro session resumes in a terminal from its workspace', () async {
    String? executable;
    List<String>? arguments;
    final NativeAgentConversationLauncher launcher =
        NativeAgentConversationLauncher(
          operatingSystem: 'macos',
          processStarter:
              (
                String value,
                List<String> values, {
                String? workingDirectory,
              }) async {
                executable = value;
                arguments = values;
              },
        );
    const AgentConversationTarget target = AgentConversationTarget(
      client: AgentClient.kiro,
      conversationId: 'kiro-session-1',
      workspacePath: '/workspace/kiro',
    );

    await launcher.open(target);

    expect(executable, 'osascript');
    expect(arguments, hasLength(2));
    expect(arguments![1], contains("exec 'kiro-cli' 'chat' '--resume-id'"));
    expect(arguments![1], contains("'kiro-session-1'"));
  });

  test(
    'local Cursor conversation falls back to opening its workspace',
    () async {
      String? executable;
      List<String>? arguments;
      final NativeAgentConversationLauncher launcher =
          NativeAgentConversationLauncher(
            operatingSystem: 'macos',
            processStarter:
                (
                  String value,
                  List<String> values, {
                  String? workingDirectory,
                }) async {
                  executable = value;
                  arguments = values;
                },
          );
      const AgentConversationTarget target = AgentConversationTarget(
        client: AgentClient.cursor,
        conversationId: 'local-conversation-1',
        workspacePath: '/workspace/cursor',
      );

      await launcher.open(target);

      expect(executable, 'open');
      expect(arguments, <String>['-a', 'Cursor', '/workspace/cursor']);
    },
  );

  test('untrusted identifiers and relative workspaces are not opened', () {
    final NativeAgentConversationLauncher launcher =
        NativeAgentConversationLauncher(operatingSystem: 'macos');

    expect(
      launcher.canOpen(
        const AgentConversationTarget(
          client: AgentClient.codex,
          conversationId: 'thread/../../settings',
        ),
      ),
      isFalse,
    );
    expect(
      launcher.canOpen(
        const AgentConversationTarget(
          client: AgentClient.kiro,
          conversationId: 'session-1',
          workspacePath: 'relative/project',
        ),
      ),
      isFalse,
    );
  });

  test('Windows CLI resume does not pass hook data through cmd.exe', () async {
    String? executable;
    List<String>? arguments;
    final NativeAgentConversationLauncher launcher =
        NativeAgentConversationLauncher(
          operatingSystem: 'windows',
          processStarter:
              (
                String value,
                List<String> values, {
                String? workingDirectory,
              }) async {
                executable = value;
                arguments = values;
              },
        );

    await launcher.open(
      const AgentConversationTarget(
        client: AgentClient.kiro,
        conversationId: 'f2946a26-3735-4b08-8d05-c928010302d5',
        workspacePath: r'C:\workspace with spaces\kiro',
      ),
    );

    expect(executable, 'wt.exe');
    expect(arguments, <String>[
      '-d',
      r'C:\workspace with spaces\kiro',
      'kiro-cli',
      'chat',
      '--resume-id',
      'f2946a26-3735-4b08-8d05-c928010302d5',
    ]);
  });
}
