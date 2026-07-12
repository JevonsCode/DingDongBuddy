import 'package:dingdong/features/settings/domain/app_settings.dart';

/// Builds the editable instructions users give to an Agent during MCP setup.
String defaultMcpSetupPrompt({
  required AppLanguagePreference language,
  required String commandPath,
}) {
  final bool chinese = language == AppLanguagePreference.chinese;
  if (chinese) {
    return '''请帮我把 DingDong 接入当前 Agent：
1. 将 $commandPath 注册为名为 dingdong 的全局 STDIO MCP Server；不要安装资源库里记录的其他 MCP
2. 启动后检查 dingdong_bridge 和 dingdong_notify 是否可用
3. 每次用户任务开始时，先调用 dingdong_bridge，source 填当前 Agent 名称，task 填简短任务摘要，并应用返回的 active.prompts
4. Skill 或 MCP 引用只在任务确实需要时再按 id 加载全文；不要默认读取剪贴板内容
5. 整项用户任务完成、阻塞或需要我决策时，只调用一次 dingdong_notify；不要传 sound，让 DingDong 使用设置里选择的声音
6. 完成配置后说明修改了哪个配置文件，并执行一次连接检查；不要打包或发布 DingDong''';
  }
  return '''Connect DingDong to the current agent:
1. Register $commandPath as a global STDIO MCP server named dingdong; do not install other MCP references from the Library
2. Verify that dingdong_bridge and dingdong_notify are available
3. At the start of every user task, call dingdong_bridge with the current agent name as source and a short task summary, then apply active.prompts
4. Load full Skill or MCP content by id only when the task needs it; do not read clipboard content by default
5. Call dingdong_notify once when the whole task is complete, blocked, or needs a decision; omit sound so DingDong uses the selected Settings sound
6. Report the config file changed and run one connection check; do not package or publish DingDong''';
}
