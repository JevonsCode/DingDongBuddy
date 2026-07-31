# DingDong 0.9.3

This release makes Clipboard history easier to manage, gives users an explicit
privacy boundary for Agent access, and replaces ambiguous connection indicators
with verifiable status.

## Clipboard workflow and durable image history

- Adds a compact, searchable, multi-select source filter to
  **Resource Manager → Clipboard**. Only applications represented in the
  current history are offered.
- Changes `Command-R` on macOS and `Control-R` on Windows into a three-stage
  filter shortcut: open filters, reset active filters to All, then close them.
- Keeps the quick Clipboard panel lightweight by removing its duplicate
  monitoring switch; monitoring remains available from the tray menu.
- Stores copied image files as source paths without duplicating or deleting the
  originals. Screenshots and other raw bitmap data are persisted in managed
  local storage and follow Clipboard retention.
- Preserves managed image data for pinned or archived records and cleans it up
  when an ordinary record is deleted or expires.
- Adds direct open actions for available image and file records.

## Configurable workspace shortcuts and reliable settings

- Makes the Dynamic, Library, and Clipboard workspace shortcuts independently
  configurable from Settings.
- Uses safe defaults that preserve standard operating-system shortcuts:
  `Control-Q/W/E` on macOS and `Alt-Q/W/E` on Windows.
- Rejects duplicate workspace shortcuts, DingDong action conflicts, reserved
  system combinations, and unavailable global shortcuts without replacing the
  previous working value.
- Saves numeric settings when editing ends, so Clipboard item and day limits
  survive closing and reopening Settings without requiring Return.
- Reapplies the selected popup opacity after switching macOS Spaces.

## Safer local Agent access

- Adds **Allow Agents to read clipboard content**, off by default. Clipboard
  metadata remains available while content reads, capture, collection, and
  promotion are blocked.
- Keeps sensitive Clipboard records behind a second explicit request even after
  Agent content access is enabled.
- Redirects the loopback server root to the DingDong website and rejects
  cross-origin browser calls outside `/` and `/health`.
- Requires JSON for write requests, limits request bodies to 8 MiB, and rejects
  unsupported form-style or oversized requests before routing.
- Documents that these browser protections prevent web-page and accidental
  calls but do not authenticate another ordinary local application running as
  the same user.

## Clearer Agent connections and desktop polish

- Reorganizes Agent connections around the actual bound origin, preferred-port
  fallback, health checks, test receipts, and advanced API/MCP details.
- Replaces misleading green connection dots with evidence-based Agent Adapter
  summaries. YAML editing and revision comparison remain under
  **Advanced config**.
- Adds semantic labels and improves the smallest status text across navigation,
  Settings, Clipboard, Agent connections, and Resource Manager.
- Adds a direct **Resource Manager** entry above **Settings** in the tray menu.
- Adds a real macOS integration smoke test for occupied-port fallback,
  `/health`, and clean test-host shutdown.

Intel macOS and Windows packages remain beta.

---

本版本重点优化剪贴板历史管理、Agent 读取权限和连接状态表达，并修复设置持久化及
macOS 多空间透明度问题。

## 剪贴板流程与持久图片历史

- 在 **资源管理 → 剪贴板** 新增紧凑的来源筛选，可搜索、多选，并且只显示当前历史
  中真实出现过的应用。
- macOS 的 `Command-R` 和 Windows 的 `Control-R` 改为三段式筛选快捷键：打开筛选、
  将已启用筛选重置为“全部”，然后收起筛选。
- 删除快速剪贴板面板中重复的监听开关；开始或停止监听继续由托盘菜单负责。
- 复制图片文件时只保存源路径，不复制也不删除原文件；截图等原始位图会持久保存到
  DingDong 的本机托管目录，并遵守剪贴板保留上限。
- 置顶或归档记录的托管图片不会被自动清理；普通记录被删除或过期时会同步清理。
- 图片和文件记录新增直接打开操作。

## 可配置工作区快捷键与可靠设置

- 动态、资源库和剪贴板三个工作区快捷键现在可在设置中分别修改。
- 默认快捷键避免覆盖系统常用操作：macOS 使用 `Control-Q/W/E`，Windows 使用
  `Alt-Q/W/E`。
- 新组合与其他工作区、DingDong 已有操作、系统保留组合冲突，或全局快捷键无法注册
  时，会保留此前可用的值。
- 数字设置在结束编辑时自动保存，剪贴板条目上限和保留天数无需按回车也能跨窗口保留。
- 切换 macOS 空间后会重新应用用户选择的面板透明度。

## 更安全的本机 Agent 访问

- 新增 **允许 Agent 读取剪贴板正文**，默认关闭；关闭时元数据仍可用，但正文读取、
  API 采集、收集和提升都会被拒绝。
- 开启正文权限后，敏感记录仍需要调用方再次明确请求。
- 本机服务根路径会跳转 DingDong 官网；除 `/` 与 `/health` 外，跨源网页请求会被
  拒绝。
- 写请求必须使用 JSON，请求体上限为 8 MiB；表单式或超限请求会在路由前被拒绝。
- 文档明确区分安全边界：这些规则用于防网页和意外误调用，并不认证同一用户下运行的
  其他普通本机应用。

## 更清晰的 Agent 连接与桌面细节

- Agent 连接页围绕真实监听地址、首选端口回退、健康检查、测试回执和高级 API/MCP
  信息重新组织。
- Agent Adapter 不再用绿色圆点暗示真实连接，改为可验证的证据摘要；YAML 编辑和
  历史版本比较收进 **高级配置**。
- 为导航、设置、剪贴板、Agent 连接和资源管理补充语义标签，并提高过小状态文字字号。
- 托盘菜单在“设置”上方新增直接打开“资源管理”的入口。
- 新增真实 macOS 集成冒烟测试，覆盖端口被占用后的回退、`/health` 和测试宿主正常
  退出。

Intel macOS 与 Windows 安装包继续标记为 beta。
