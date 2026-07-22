import 'package:dingdong/features/settings/domain/app_settings.dart';

/// Builds the copy-only instructions users give to a local Agent during setup.
String defaultMcpSetupPrompt({
  required AppLanguagePreference language,
  required String commandPath,
}) {
  final bool chinese = language == AppLanguagePreference.chinese;
  if (chinese) {
    return '''请把这台电脑上的 DingDong 接入当前 Agent 或 IDE，并启用持久的任务结束提醒：
1. 先确认当前会话运行在安装了 DingDong 的本机，并确认下面的可执行文件存在且可运行；远程或云端 Agent 不能使用这条本机路径：
   $commandPath
2. 找到当前客户端实际使用的用户级（全局）MCP 配置。保留其他所有配置，新增或修正一个名为 dingdong 的 STDIO MCP Server：
   - command 必须是完整的可执行文件路径：$commandPath
   - MCP Server 不要添加 args、环境变量或外层 shell；路径中即使有空格，也必须是一个完整的 command 值
3. 再使用当前客户端原生的“最终回复/任务结束”Hook 写入持久配置，不要只在当前对话里承诺通知。Hook 命令必须是：
   "$commandPath" --notify-stop --source "当前客户端名称"
   按客户端使用下面的用户级配置和事件：
   - Codex：~/.codex/config.toml 的 Stop command Hook；确保 [features] 下 hooks = true
   - Claude Code：~/.claude/settings.json 的 Stop command Hook
   - Cursor：~/.cursor/hooks.json 的 afterAgentResponse command Hook
   - Gemini CLI：~/.gemini/settings.json 的 AfterAgent command Hook
   - Kiro：MCP 使用 ~/.kiro/settings/mcp.json；Kiro CLI v3 优先使用 ~/.kiro/hooks 下的全局 Stop command Hook，旧版 CLI 使用当前可编辑自定义 Agent 的 hooks.stop；IDE 使用原生 Agent Stop shell-command Hook。若当前版本只支持项目级 Hook，未经用户明确同意不要修改项目文件，并说明限制
   如果不是以上客户端，先查清它是否有原生的本地任务结束 Hook；没有就只接入 MCP，并明确说明不支持自动结束提醒，不能编造配置。
4. 保留已有 Hook 和无关设置。重复接入时更新已有的 DingDong 项，不要重复添加同一个 MCP Server 或 Hook，也不要修改任何项目内文件。
5. 校验修改后的 TOML 或 JSON 能被当前客户端解析，再按客户端要求重新加载：
   - Codex：在 Settings → MCP servers 重启 dingdong，并在 /hooks 审核并信任新增或变化的 Hook
   - Claude Code：用 claude mcp list 和 /hooks 检查
   - Cursor：重新加载窗口并检查 Hooks 配置
   - Gemini CLI：执行 /mcp reload，并用 /hooks panel 检查
   - Kiro：执行 /mcp 检查 MCP，并用 /hooks 检查当前会话实际加载的 Stop Hook
6. 接入后必须区分三类资源的运行语义，不能把 Skill 或 MCP 候选当成 Prompt 执行：
   - Prompt：所有命中的 Prompt 都是必须自动应用的指令，并以完整正文提供；全局、始终生效的 Prompt 会直接进入 Codex 的 AGENTS.md 或 Claude Code 的 CLAUDE.md 托管区块
   - Skill：由 Agent 根据 description 判断是否匹配，只有匹配当前任务时才加载或使用完整 Skill；未限定范围的 Skill 全局同步，严格项目 Skill 只同步到项目内原生 Skill 目录；Skill 摘要不是指令
   - MCP：配置后只代表工具可用，只有任务确实需要时才调用对应 MCP 工具；MCP 摘要不是指令，也不代表每轮都要调用
   - 用户明确要求“通过 DingDong 给某项目安装 Skill”时，依次使用 dingdong_install_skill、dingdong_upsert_trigger_group 和 dingdong_bind_resource_scope，并启用 strictProjectSkill；不要用全局 Skill 加路由提示冒充项目隔离
7. 分别验证两条链路，不能只验证 MCP：
   - 结束 Hook：用当前 shell 把 {"summary":"DingDong 任务结束提醒已接入"} 作为 JSON 标准输入传给第 3 步的 Hook 命令，确认 DingDong 收到这条提醒
   - MCP：确认工具列表里出现 dingdong_notify，然后立即调用一次，message 为“DingDong MCP 已接入”，source 为当前客户端名称
8. 最后只报告：改了哪些用户级配置文件、MCP 是否可用、结束 Hook 是否已配置（Codex 还要说明是否已信任）、两项测试是否成功。任何一步失败时都保留原有配置并返回原始错误，不要猜测。''';
  }
  return '''Connect DingDong on this computer to the current agent or IDE and enable durable task-completion alerts:
1. Confirm that this session is running locally on the computer where DingDong is installed, and verify that this executable exists and can run. A remote or cloud agent cannot use this local path:
   $commandPath
2. Find the user-level (global) MCP configuration actually used by the current client. Preserve every existing entry, then add or repair a STDIO MCP server named dingdong:
   - command must be this complete executable path: $commandPath
   - do not add args, environment variables, or a wrapper shell to the MCP server; a path containing spaces must remain one complete command value
3. Configure the client's native final-response or task-completion hook as a durable setting. Do not merely promise to notify in this conversation. The hook command must be:
   "$commandPath" --notify-stop --source "Current client name"
   Use the matching user-level configuration and event:
   - Codex: a Stop command hook in ~/.codex/config.toml; ensure hooks = true under [features]
   - Claude Code: a Stop command hook in ~/.claude/settings.json
   - Cursor: an afterAgentResponse command hook in ~/.cursor/hooks.json
   - Gemini CLI: an AfterAgent command hook in ~/.gemini/settings.json
   - Kiro: use ~/.kiro/settings/mcp.json for MCP; prefer a global Stop command hook under ~/.kiro/hooks with Kiro CLI v3, or hooks.stop in the active editable custom Agent on older CLI versions; in the IDE use its native Agent Stop shell-command hook. If this version only supports a project hook, do not modify project files without explicit user permission and report the limitation
   For another client, first verify whether it provides a native local task-completion hook. If it does not, configure MCP only and report that automatic completion alerts are unsupported instead of inventing a setting.
4. Preserve all existing hooks and unrelated settings. When reconnecting, update the existing DingDong entries instead of duplicating the MCP server or hook. Do not modify project files.
5. Validate the resulting TOML or JSON, then reload the client as required:
   - Codex: restart dingdong under Settings → MCP servers, then review and trust the new or changed hook in /hooks
   - Claude Code: inspect claude mcp list and /hooks
   - Cursor: reload the window and inspect the Hooks configuration
   - Gemini CLI: run /mcp reload and inspect /hooks panel
   - Kiro: inspect MCP with /mcp and verify the Stop hook actually loaded for the current session with /hooks
6. Keep the three resource types semantically distinct after connection. Never execute Skill or MCP candidates as if they were Prompts:
   - Prompt: every active Prompt is a required instruction, delivered in full and applied automatically; global always-on Prompts are placed directly in DingDong-managed Codex AGENTS.md and Claude Code CLAUDE.md blocks
   - Skill: the Agent matches its description first and loads or uses the complete Skill only when it fits the current task; unscoped Skills are synchronized globally, while strict project Skills are synchronized only into native Skill directories inside that project; a Skill summary is not an instruction
   - MCP: configuration makes tools available, but call an MCP tool only when the task actually needs it; an MCP summary is not an instruction and does not require a call on every turn
   - When the user explicitly asks to install a Skill through DingDong for one project, use dingdong_install_skill, dingdong_upsert_trigger_group, then dingdong_bind_resource_scope with strictProjectSkill enabled; never imitate project isolation with a global Skill plus a routing hint
7. Test both paths; testing MCP alone is not enough:
   - Completion hook: using the current shell, pipe {"summary":"DingDong task-completion hook is connected"} as JSON stdin to the hook command from step 3 and confirm that DingDong receives it
   - MCP: confirm dingdong_notify appears in the tool list, then call it once with message "DingDong MCP is connected" and source set to the current client name
8. Finally report only the user-level configuration files changed, whether MCP is available, whether the completion hook is configured (and trusted for Codex), and whether both tests succeeded. If any step fails, preserve the existing configuration and return the original error instead of guessing.''';
}
