// ignore_for_file: implementation_imports

// One compatibility boundary for the pinned agent-installer revision. Its
// public API covers product install/remove, but not removal previews or edits
// of multiple scoped MCP resources. Both use the same upstream edit engine;
// DingDong retains resource selection, ownership journals and file locking.
export 'package:agent_installer/agent_installer.dart' show JsonEdit;
export 'package:agent_installer/src/components.dart' show buildWork, TextPart;
export 'package:agent_installer/src/text_edit.dart'
    show CodexToml, MarkdownBlock;
