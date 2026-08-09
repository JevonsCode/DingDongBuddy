/// Real DEV-only integration paths exposed by the standalone test panel.
enum DevelopmentTestAction {
  traySleeping('tray-sleeping'),
  trayNudge('tray-nudge'),
  agentCompletion('agent-completion'),
  agentRichCompletion('agent-rich-completion'),
  agentBurst('agent-burst'),
  phoneClipboardText('phone-clipboard-text'),
  phoneClipboardFile('phone-clipboard-file'),
  autoSendClipboard('auto-send-clipboard'),
  manualDeviceShare('manual-device-share'),
  openDeviceManager('open-device-manager');

  const DevelopmentTestAction(this.id);

  final String id;

  bool get requiresTrayAnimation =>
      this == DevelopmentTestAction.traySleeping ||
      this == DevelopmentTestAction.trayNudge;

  static DevelopmentTestAction? fromId(Object? value) {
    if (value is! String) return null;
    for (final DevelopmentTestAction action in values) {
      if (action.id == value) return action;
    }
    return null;
  }
}

const String developmentTestRunMethod = 'development_test_run';
