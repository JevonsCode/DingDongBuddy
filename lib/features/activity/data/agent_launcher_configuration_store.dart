import 'dart:io';

import 'package:dingdong/features/activity/domain/agent_launcher_configuration.dart';

/// Loads the user-editable Agent launcher configuration.
final class FileAgentLauncherConfigurationStore {
  const FileAgentLauncherConfigurationStore(this.file);

  final File file;

  Future<AgentLauncherConfiguration> load() async {
    if (!await file.exists()) {
      return const AgentLauncherConfiguration();
    }
    return AgentLauncherConfiguration.decode(await file.readAsString());
  }
}
