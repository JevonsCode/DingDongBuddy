import 'dart:io';

import 'package:dingdong/features/activity/data/agent_launcher_configuration_store.dart';
import 'package:dingdong/features/activity/domain/agent_conversation_target.dart';
import 'package:dingdong/features/activity/domain/agent_launcher_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing launcher file preserves the Terminal.app default', () async {
    final Directory temporary = Directory.systemTemp.createTempSync(
      'dingdong-agent-launcher-',
    );
    addTearDown(() => temporary.deleteSync(recursive: true));

    final AgentLauncherConfiguration configuration =
        await FileAgentLauncherConfigurationStore(
          File('${temporary.path}/agent-launchers.json'),
        ).load();

    expect(
      configuration.settingsFor(AgentClient.claudeCode).macosTerminal,
      MacOsTerminalApplication.terminal,
    );
    expect(
      configuration.settingsFor(AgentClient.claudeCode).iTermOpenMode,
      ITermOpenMode.newWindow,
    );
  });

  test('Agent override inherits unspecified launcher defaults', () {
    final AgentLauncherConfiguration configuration =
        AgentLauncherConfiguration.decode('''
{
  "schemaVersion": 1,
  "defaults": {
    "macosTerminal": "terminal",
    "itermOpenMode": "new-window"
  },
  "agents": {
    "claude-code": {
      "macosTerminal": "iterm",
      "itermOpenMode": "new-tab"
    },
    "gemini-cli": {
      "macosTerminal": "iterm"
    }
  }
}
''');

    expect(
      configuration.settingsFor(AgentClient.claudeCode).macosTerminal,
      MacOsTerminalApplication.iTerm,
    );
    expect(
      configuration.settingsFor(AgentClient.claudeCode).iTermOpenMode,
      ITermOpenMode.newTab,
    );
    expect(
      configuration.settingsFor(AgentClient.geminiCli).macosTerminal,
      MacOsTerminalApplication.iTerm,
    );
    expect(
      configuration.settingsFor(AgentClient.geminiCli).iTermOpenMode,
      ITermOpenMode.newWindow,
    );
    expect(
      configuration.settingsFor(AgentClient.kiro).macosTerminal,
      MacOsTerminalApplication.terminal,
    );
  });

  test('unknown fields, clients, and enum values are rejected', () {
    expect(
      () => AgentLauncherConfiguration.decode(
        '{"schemaVersion":1,"unexpected":true}',
      ),
      throwsFormatException,
    );
    expect(
      () => AgentLauncherConfiguration.decode(
        '{"schemaVersion":1,"agents":{"other":{"macosTerminal":"iterm"}}}',
      ),
      throwsFormatException,
    );
    expect(
      () => AgentLauncherConfiguration.decode(
        '{"schemaVersion":1,"defaults":{"macosTerminal":"warp"}}',
      ),
      throwsFormatException,
    );
  });
}
