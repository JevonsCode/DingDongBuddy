import 'package:dingdong/features/agent_api/data/agent_source_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveAgentAdapterId', () {
    test('normalizes supported client aliases to one adapter id', () {
      expect(resolveAgentAdapterId('Codex'), 'codex');
      expect(resolveAgentAdapterId('codex-cli'), 'codex');
      expect(resolveAgentAdapterId('Claude Code'), 'claude-code');
      expect(resolveAgentAdapterId('cursor-agent'), 'cursor');
      expect(resolveAgentAdapterId('Gemini CLI'), 'gemini');
      expect(resolveAgentAdapterId('Grok'), 'grok-build');
      expect(resolveAgentAdapterId('Grok Build'), 'grok-build');
      expect(resolveAgentAdapterId('Kiro'), 'kiro');
      expect(resolveAgentAdapterId('Pi'), 'pi');
      expect(resolveAgentAdapterId('Pi Coding Agent'), 'pi');
    });

    test('returns null for generic or unknown sources', () {
      expect(resolveAgentAdapterId('Agent'), isNull);
      expect(resolveAgentAdapterId('custom-runner'), isNull);
      expect(resolveAgentAdapterId(''), isNull);
    });
  });

  group('inferAgentSourceFromEnvironment', () {
    test('recognizes the official Pi coding-agent environment signals', () {
      expect(
        inferAgentSourceFromEnvironment(const <String, String>{
          'AI_AGENT': 'pi',
        }),
        'Pi',
      );
      expect(
        inferAgentSourceFromEnvironment(const <String, String>{
          'PI_CODING_AGENT': 'true',
        }),
        'Pi',
      );
    });

    test('keeps established Agent session signals deterministic', () {
      expect(
        inferAgentSourceFromEnvironment(const <String, String>{
          'CODEX_THREAD_ID': 'thread-1',
          'AI_AGENT': 'pi',
        }),
        'Codex',
      );
      expect(
        inferAgentSourceFromEnvironment(const <String, String>{
          'CLAUDECODE': '1',
        }),
        'Claude Code',
      );
      expect(inferAgentSourceFromEnvironment(const <String, String>{}), isNull);
    });
  });
}
