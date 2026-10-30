# Agent 接入组件

DingDong 在唤出面板和资源管理中复用同一个安装、更新及清理入口。

| 组件 | 固定提交 | 用途 |
| --- | --- | --- |
| [agent-installer](https://github.com/JevonsCode/agent-installer) | `9b3c9fb7e92e9e4c9dd5bf9c0e1ac4300704a033` | 检测客户端，预览和安装 MCP、Hooks、接入提示，清理对应 Agent 的 DingDong 接入配置 |
| [agent-session-launcher](https://github.com/JevonsCode/agent-session-launcher) | `dce8ab5bb68c750f52bb9b0409e8ac7cc52f544a`（0.3.1） | 校验会话目标并生成打开计划；读取共享的本机客户端扩展 |

资源同步的客户端路径以安装组件的目录为来源，并读取同一个本机扩展目录；明确保存过的旧版自定义 YAML 继续作为兼容覆盖。资源的 JSON、Codex TOML 和接入提示编辑复用安装组件的编辑器。DingDong 保留资源范围选择、锁、并发合并、原生 Skill 部署日志及回滚职责。

安装组件当前没有公开的清理预览接口。`agent_installer_edits.dart` 是唯一的兼容入口，复用固定提交中的组件编辑函数生成只读预览；展示文件和内容类型，不展示配置里的凭据。更新依赖时需同时验证预览与实际清理结果一致，以及同名但不属于 DingDong 的 MCP 不会被接管或删除。

DEV 使用真实检测和只读预览。安装与清理均不提供写入确认，网关也拒绝直接写入。正式版在用户核对改动并确认后执行，组件保存备份。

设置是否需要更新由每次打开面板时的检测结果决定。首次接入提示允许跳过，之后可从“唤出面板 → 动态 → Agent 连接”重新进入。

打开会话前仍由 DingDong 完成来源与 Codex 主会话检查；Cursor、Kiro 的工作目录回退由宿主保留。成功发送打开请求只表示系统接受了请求，不表示第三方客户端已恢复会话。`dingdong_notify` 必须明确传入当前 `conversationId`，不从上一次请求猜测。
