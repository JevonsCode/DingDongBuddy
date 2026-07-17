import 'package:dingdong/features/settings/domain/app_settings.dart';

/// Builds the copy-only instructions users give to an Agent during setup.
String defaultMcpSetupPrompt({
  required AppLanguagePreference language,
  required String commandPath,
}) {
  final bool chinese = language == AppLanguagePreference.chinese;
  if (chinese) {
    return '''请为当前 Agent 或 IDE 完成 DingDong 接入，同时配置 MCP 和持久的任务结束提醒：
1. 找到当前 Agent 或 IDE 实际使用的全局 MCP 配置文件和格式
2. 新增一个名为 dingdong 的 STDIO MCP Server，command 必须完整使用这个可执行文件路径：$commandPath
3. 不要添加 args、环境变量或外层 shell；路径中即使有空格，也必须作为一个完整的 command 值
4. 保留其他所有 MCP 配置和无关设置，不要修改 DingDong 项目文件
5. 再配置当前客户端原生的任务结束 Hook，让每次任务结束时执行下面这条命令；这是持久配置，不要只把它写成当前对话里的要求：
   "$commandPath" --notify-stop
   - 如果当前客户端是 Codex：在同一个全局 ~/.codex/config.toml 中保留已有 Hook，并新增一个 Stop command Hook；确保 [features] 下 hooks = true
   - 重复接入时先检查，不能重复添加相同的 DingDong Hook
   - 如果当前客户端不支持任务结束 Hook，明确说明不支持，不要编造配置
6. 按当前客户端要求重新加载或重启。Codex 需要在 Settings → MCP servers 点击 Restart，并在 /hooks 中审核并信任新增的 DingDong Hook
7. 重启后确认工具列表里已经出现 dingdong_notify，然后立即调用一次 dingdong_notify：
   - message: DingDong MCP 已接入，任务结束提醒已启用
   - source: 当前 Agent 名称
8. 最后只说明修改了哪个配置文件、MCP 是否可用、结束 Hook 是否已配置并信任、测试通知是否成功；如失败，保留已有配置并返回原始错误，不要猜测''';
  }
  return '''Connect DingDong to the current agent or IDE, configuring both MCP and a durable task-completion alert:
1. Find the global MCP configuration file and schema actually used by the current agent or IDE
2. Add a global STDIO MCP server named dingdong whose command is this exact executable path: $commandPath
3. Do not add args, environment variables, or a wrapper shell; keep a path containing spaces as one complete command value
4. Preserve every unrelated MCP entry and setting, and do not modify the DingDong project files
5. Also configure the client's native task-completion hook to run this command whenever a task stops. Make it a durable client setting, not an instruction that exists only in this conversation:
   "$commandPath" --notify-stop
   - For Codex, preserve existing hooks and add a Stop command hook in the same global ~/.codex/config.toml; ensure hooks = true under [features]
   - Check for an existing identical DingDong hook before adding one, so reconnecting never creates duplicates
   - If the client has no task-completion hook, report that limitation instead of inventing a configuration
6. Reload or restart as required. In Codex, select Restart under Settings → MCP servers, then review and trust the new DingDong hook in /hooks
7. After restart, confirm that dingdong_notify appears in the tool list, then call it once with:
   - message: DingDong MCP is connected and task-completion alerts are enabled
   - source: the current agent name
8. Finally, report only the configuration file changed, whether MCP is available, whether the completion hook is configured and trusted, and whether the test notification succeeded. If setup fails, preserve the existing configuration and report the original error instead of guessing''';
}
