import 'package:dingdong/app/app_locale.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';

/// Builds a short, actionable instruction for connecting the local MCP server.
String defaultMcpSetupPrompt({
  required AppLanguagePreference language,
  required String commandPath,
}) {
  return appLocalizationsFor(
    language,
  ).connectDingDongToCurrentAgent(commandPath);
}
