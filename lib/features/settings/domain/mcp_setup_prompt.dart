import 'package:dingdong/features/settings/domain/app_settings.dart';

/// Builds the editable instructions users give to an Agent during MCP setup.
String defaultMcpSetupPrompt({
  required AppLanguagePreference language,
  required String commandPath,
}) {
  final bool chinese = language == AppLanguagePreference.chinese;
  if (chinese) {
    return '''请在当前 Agent 或 IDE 中接入 DingDong MCP，并完成下面的配置与验证：
1. 找到当前 Agent 或 IDE 实际使用的全局 MCP 配置文件和格式
2. 新增一个名为 dingdong 的 STDIO MCP Server，command 必须完整使用这个可执行文件路径：$commandPath
3. 不要添加 args、环境变量或外层 shell；路径中即使有空格，也必须作为一个完整的 command 值
4. 保留其他所有 MCP 配置和无关设置，不要修改 DingDong 项目文件
5. 按当前 Agent 的要求重新加载 MCP 配置或重启客户端，确认工具列表里已经出现 dingdong_notify
6. 连接成功后，立即调用一次 dingdong_notify：
   - message: DingDong MCP 已接入，之后任务完成时会通知你
   - source: 当前 Agent 名称
7. 从现在起，每个新任务开始时先调用 dingdong_bridge；任务完成、被阻塞或需要用户处理时，在最终回复前调用一次 dingdong_notify，不要在处理中重复通知
8. 最后只说明修改了哪个配置文件、是否看到 dingdong_notify、测试通知是否成功；如失败，保留已有配置并返回原始错误，不要猜测''';
  }
  return '''Connect DingDong MCP to the current agent or IDE, then complete this configuration and verification:
1. Find the global MCP configuration file and schema actually used by the current agent or IDE
2. Add a global STDIO MCP server named dingdong whose command is this exact executable path: $commandPath
3. Do not add args, environment variables, or a wrapper shell; keep a path containing spaces as one complete command value
4. Preserve every unrelated MCP entry and setting, and do not modify the DingDong project files
5. If required, reload or restart the MCP client, then confirm that dingdong_notify appears in the available tool list
6. As soon as the connection succeeds, call dingdong_notify once with:
   - message: DingDong MCP is connected; future task completions will notify you
   - source: the current agent name
7. From now on, call dingdong_bridge at the start of each new user task. When a task is complete, blocked, or waiting for user attention, call dingdong_notify once before the final response; do not send repeated notifications while working
8. Finally, report only the configuration file changed, whether dingdong_notify was available, and whether the test notification succeeded. If setup fails, preserve the existing configuration and report the original error instead of guessing''';
}
