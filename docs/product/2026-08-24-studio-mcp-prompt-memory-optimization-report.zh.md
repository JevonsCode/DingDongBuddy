# DingDong Studio、MCP、Prompt、内存与界面最终优化报告

日期：2026-08-24
基线：`codex/release-1.5.2` / `674879f`
环境：Flutter 3.44.6、Dart 3.12.2、Node.js 22.17.0、macOS
关联报告：[全量代码、产品与手机端优化报告](./2026-08-24-code-product-mobile-optimization-report.zh.md)

## 最终结论

本轮把代码静态质量、废弃代码、Studio 资源链路、MCP 配置、Prompt 注入、Bridge 运行时作用域、手机通知、文件传输、内存上限、桌面弹窗、手机 PWA 和首次启动放在同一条真实路径中检查，并直接修复了已确认的问题。

审计范围内没有遗留的 P0/P1 级已知代码缺陷。最严重的三个问题已经处理：全新数据目录首次启动会在 Settings 初始化前读取本地化而崩溃；带项目/仓库作用域的 MCP 会在 Bridge 有机会匹配前被错误地从 Agent 原生配置排除；手机上传文件会把完整 25 MiB 内容按块长期留在 Dart 堆中且并发数没有上限。

最终验证结果：Flutter 964 项通过、2 项按平台预期跳过；真实连接集成测试 1 项通过；PWA/relay 52 项通过；`flutter analyze` 0 问题；`dart fix --dry-run` 无建议；31 张桌面 golden 全部通过；macOS Release 构建成功；生产依赖审计 0 漏洞；`git diff --check` 通过。报告记录形成时尚未执行 Git add、commit、push 或部署。

## 已发现并修复的问题

| 级别 | 问题 | 影响 | 修复 |
| --- | --- | --- | --- |
| 高 | 首次启动时 `DeviceLinkController.start()` 可能早于 `SettingsViewModel` 初始化读取本地化 | 全新安装直接出现 `LateInitializationError`，窗口无法正常完成启动 | 复用依赖层已加载的启动 Settings 快照；ViewModel 尚未就绪时使用安全的启动语言，加载完成后无缝切回实时设置，且不增加一次偏好读取 |
| 高 | 项目路径/仓库作用域 MCP 在 Agent 原生同步阶段按缺失运行时上下文判断为不匹配 | MCP 根本没有安装进客户端，Bridge 后续即使匹配项目也无法调用 | 原生同步只用 source-only 规则选择客户端；项目/仓库规则保留 MCP 安装，由 Bridge 在具体任务上下文中判定 |
| 高 | 手机文件上传把全部 base64 解码块保存在内存 Map 中，且传输数无界 | 单传输可额外持有约 25 MiB，多传输可叠加，并在异常中留下悬挂状态 | 32 KiB 顺序写入随机临时 `.part` 文件；最多 3 个并发；严格校验设备、ID、顺序、块大小和总大小；断线、超时、异常、结束时清理 |
| 中 | WebSocket 与解密消息用不断延长的 Future 链串行化，没有明确背压和队列上限 | 消费速度落后时可持续保留闭包和消息体 | WebSocket 使用 `asyncMap` 背压；加密入站队列上限 16，关闭时取消订阅并等待 drain |
| 中 | Agent session/handoff 首次访问会把全部历史资源反序列化到常驻 Map | 长期使用后应用堆随历史记录增长 | 常驻缓存只保留最新 100 条，列表保持最新优先；修改旧 ID 时做定向持久化查找，不牺牲兼容性 |
| 中 | Bridge 同一任务分别记录 Prompt 使用和 Skill/MCP 候选，可能完整读取、重写资源库两次 | Studio 资源多时增加 CPU、分配与并发写冲突窗口 | 新增原子 delivery receipt，一次串行读改写同时更新使用和候选指标 |
| 中 | MCP HTTP 每个调用新建客户端并一次性读取无限响应 | 重复建立连接，异常本地响应可能占用过量内存 | 复用带超时的 `HttpClient`；响应硬上限 16 MiB；stdio MCP 退出时强制关闭客户端 |
| 中 | 在线 Skill 文件下载和包摘要计算把整个文件读入内存 | 大资源包安装、升级、校验时产生尖峰 | 真实网络下载直接流式写盘；SHA-256 使用 `openRead()` 分块计算；失败删除未完成文件 |
| 中 | MCP 初始化说明和 Agent 原生 Prompt block 各自维护整段 Bridge 规则 | Prompt、Skill、MCP、footer 语义容易静默漂移 | 新建 canonical `agent_bridge_guidance.dart`，MCP initialize 与原生同步共同使用；契约测试锁定关键语义 |
| 中 | 手机查看 Agent 提醒后电脑端未同步已读，普通完成与需处理提醒语义可能在压缩/重连中丢失 | 未读数、角标长期不准，紧急程度不清楚 | 精确 `agent.seen` ID 回执；完成/需处理语义贯穿实时、快照和 Push；标题、正文、动作、时间戳、角标与震动请求分级 |
| 中 | 手机删除设备使用原生 `confirm()`，部分控件小于 44 px、语义标签不完整 | 风格割裂且影响触控/键盘/辅助功能 | 改为 DingDong 自有确认弹窗；核心触控目标至少 44 px；补齐 ARIA、焦点和真实按钮语义 |
| 低 | 手机通知引导硬编码粉色；默认卡片、选中 tab、状态点和输入框存在装饰阴影/光晕 | 偏离 Quiet Workbench 的扁平、克制和语义色理念 | 改用 accent token；普通卡片和选择态以边框/背景表达；移除装饰阴影；保留清晰矩形键盘焦点 |
| 低 | 手机离线重连每 30 秒把无诊断内容的 WebSocket `Event` 写成 console error | 长期产生开发日志噪声并保留无价值日志对象 | 忽略无 payload 的网络 `error` Event，协议、加密等真实异常继续记录 |

## Studio、MCP 与 Prompt 链路

### 当前正确的职责边界

1. Agent 每个用户任务开始调用 `dingdong_bridge`，成功结果是该任务的唯一 Prompt 与动态 Skill 快照；上一任务状态不可复用。
2. 原生 Agent 文件只保存稳定的 Bridge 启动说明，不写入动态 Prompt 正文。
3. Prompt 在 Bridge 响应中完整返回并作为必需指令；Skill 只先返回候选元数据，匹配任务后再加载完整 `SKILL.md`；MCP 只返回工具引用，真实调用后才能确认使用。
4. source-only Trigger Group 决定 MCP 安装到哪些 Agent；项目、仓库和任务规则必须等待 Bridge 拿到工作区、repository 和 task 后再判断。
5. footer 只按返回的 `lineToken`、符号和 replacement item 合并一次；Prompt 不伪造使用星号，Skill 仅完整加载后标记，MCP 仅真实调用达到终态后标记。

### 本轮具体改动

- `lib/features/agent_api/domain/agent_bridge_guidance.dart`：新增唯一 canonical 指南。
- `lib/features/agent_api/data/mcp_server.dart`：`initialize.instructions` 改为 canonical 指南。
- `lib/features/library/data/agent_resource_synchronizer.dart`：Agent Prompt block 使用同一指南；MCP 原生同步采用 source/runtime 两阶段作用域策略。
- `lib/features/library/domain/resource_scope_policy.dart`：新增 `resourceCanSyncToAgentSource`，避免运行时规则提前移除 MCP。
- `lib/features/agent_api/data/agent_bridge.dart`、`resource_repository.dart`：一次原子 receipt 同时记录 Prompt 使用与 Skill/MCP 候选。
- 契约测试覆盖 authoritative snapshot、`expand="prompts"`、Skill 动态加载、MCP 真实调用确认、footer merge、project-scoped MCP 安装和一次写事务。

## 内存优化与可证明上限

| 路径 | 优化前 | 优化后 |
| --- | --- | --- |
| 手机 → 电脑文件 | 每个传输最多约 25 MiB 解码块常驻；并发无上限 | 最多 3 个传输；有效负载直接写盘；堆中主要保留当前 32 KiB 解码块及协议临时对象 |
| 加密设备消息 | Future 链可无限增长 | 明确队列上限 16，并有消费背压 |
| Agent session/handoff | 可把全部历史常驻内存 | 每类最新 100 条，旧 ID 定向读取 |
| Bridge 指标 | 同任务最多两次完整资源库读改写 | 一次序列化事务 |
| MCP HTTP | 每请求一个客户端；响应无上限 | 复用客户端；响应最多 16 MiB；进程退出关闭 |
| 在线 Skill 下载 | 单文件完整 `Uint8List` | 网络流直接写盘 |
| Skill 包摘要 | 单文件完整 `readAsBytes()` | SHA-256 分块流式计算 |
| PWA Agent/Clipboard 列表 | 已有上限，继续保留 | Agent 50、Clipboard 50；未扩大常驻数据 |

进程观测只作为基线，不冒充优化后的精确收益：审计期间已安装的旧 1.5.2 主进程 RSS 随运行状态约为 28–43 MiB；外部 Agent 启动的 `dingdong_mcp` 单进程约 2.6–2.8 MiB，观察到 9–13 个并存。MCP 进程数量由各 Agent 客户端会话生命周期决定，本轮没有通过强制 idle 退出破坏 stdio MCP 稳定性。新的 Release 构建没有为了测量而接入用户真实数据目录，因此报告不宣称一个未经同场景采样的 RSS 降幅；本轮可确认的是上述数据结构和 I/O 峰值已经有自动化保护的硬边界。

## 手机通知与 PWA

- 普通完成：显示“Agent 完成啦”、上下文正文、“查看详情”和较短震动请求。
- 需要处理：显示“Agent 需要你处理”、“立即处理”和更明显的震动请求。
- 通知使用真实完成时间、DingDong icon/badge，并按浏览器能力降级 actions、badge、vibration。
- 页面只在 Agent tab 真实可见且前台时确认实际渲染的 activity ID；桌面只修改存在且未读的匹配项。
- PWA shell 升级到 33，样式、主脚本、通知策略和 pairing-state 同步指纹化，避免旧 Service Worker 混用模块。
- 二维码对 room、secret、relay 协议、凭据和 fragment 做严格校验。
- 删除确认、通知诊断、设置、配对、离线、Agent 空态和主页面均完成 390 × 844 浏览器实测。

## 弹窗与视觉审计

### 桌面

- 实际运行当前构建，检查 Dynamic 首屏和 Resource Library；首次启动空数据路径成功。
- 全量 golden 覆盖 31 张参考图，包括资源管理器、资源编辑/详情、剪贴板分类、设置、深浅主题、紧凑与宽窗口。
- 默认 Material 圆形 splash/ink/ripple 没有回流；弹窗继续使用 DingDong 的 `DesktopAlertDialog` / `DesktopDialogFrame`。
- 原“剪贴板分类”请求在工作区重建后重复打开并留下不可见遮罩的问题已修复，并有真实导航回归。

### 手机

| 步骤 | 状态 | 结论 |
| --- | --- | --- |
| 未配对首屏 | 通过 | 品牌、输入、说明和主动作层级清楚 |
| 配对确认 | 通过 | 设备身份、风险说明、取消/确认完整 |
| 通知权限被拒绝 | 通过 | 自有诊断弹窗，不依赖浏览器原生丑弹窗 |
| 离线主页面 | 通过 | 离线、通知引导、内容 tab 和发送区层级清楚 |
| Agent 空态 | 通过 | 正在运行与完成记录分区明确 |
| 设置 | 通过 | 更新、通知、震动、图标、断开和删除可访问 |
| 删除确认 | 通过 | 危险动作层级明确，取消可恢复设置 |
| 视觉收敛复核 | 通过 | 粉色 one-off、默认卡片阴影、选中浮起和输入光晕已移除 |

截图保存在 `docs/product/audit-screenshots/2026-08-24/`；无效的旧构建误截图已删除，没有混入证据。

## 已删除的废弃代码

- 删除 `lib/platform/native_clipboard_share_gateway.dart`。
- 删除 `test/platform/native_clipboard_share_gateway_test.dart`。
- 删除 macOS `MainFlutterWindow.swift` 中已无入口的 `sharingPicker`、`shareText` 和对应 method-channel 分支。

仓库已无上述 Dart 网关和原生 `shareText` 引用；macOS Debug 与 Release 构建均成功。

## 已完成的维护热点拆分

原报告列出的 6 个热点已经按职责完成拆分。入口文件继续承担状态编排和稳定公开 API，具体实现移入有边界注释的 Dart part 或显式依赖注入的 PWA 模块，没有仅为缩短文件而打散同一职责。

| 文件 | 拆分前 | 当前入口 | 新模块数 | 完成的职责边界 |
| --- | ---: | ---: | ---: | --- |
| `lib/features/library/ui/resource_editor.dart` | 2701 | 1084 | 5 | 窗口框架、Skill、MCP、交付配置、通用控件 |
| `lib/features/library/data/agent_resource_synchronizer.dart` | 1840 | 908 | 4 | 目标发现、持久化、序列化、并发合并 |
| `lib/features/clipboard/ui/clipboard_manager_screen.dart` | 1739 | 547 | 4 | 操作、筛选、详情弹窗、列表行 |
| `lib/main.dart` | 1519 | 687 | 5 | 系统维护、设置窗口、开发窗口、剪贴板窗口、资源窗口 |
| `lib/features/device_link/ui/device_link_controller.dart` | 1294 | 376 | 5 | Agent 同步、文件传输、会话协议、持久化、支持工具 |
| `docs/app/app.js` | 3989 | 1192 | 11 | 编解码、格式化、存储、平台、安装、通知、渲染、连接、设置、配对、内容传输 |

6 个入口文件合计由 13082 行降至 4794 行，减少 8288 行（约 63.4%）；完整映射、兼容策略和回归证据见 `docs/product/2026-08-24-maintenance-hotspot-refactor-report.zh.md`。

扫描结果只有 Flutter Windows 模板中的 1 个生成 TODO、3 个本地化生成文件 ignore 和 4 个有意的构造器 lint ignore；没有发现新增 `FIXME`、`HACK`、`@Deprecated` 或可自动迁移代码。

## 仍缺失或建议补充的功能

### P1：发布门禁与通知控制

1. 用一台 Android 安装版 PWA 和一台 iPhone/iPad 主屏幕 PWA 完成前台、后台、锁屏、权限拒绝后恢复、普通完成、等待处理、角标、点击跳转、声音/震动的真机矩阵。
2. 增加普通完成/需要处理两个独立开关、安静时段、稍后提醒和临时暂停；目前只有整体 Agent 提醒开关。
3. 为 Service Worker 从旧 shell 升级建立真实浏览器 E2E，自动验证缓存迁移和配对不丢失。

### P2：行动闭环、管理与性能证据

1. 在具备稳定 conversation target 且用户明确授权时，让“需要你处理”直接跳到对应 Agent 对话；否则保持只读提醒。
2. Agent 提醒增加来源/状态筛选、只看未读和批量已读。
3. 在正式数据副本上用 DevTools/VM Service 做冷启动、空闲、5,000 剪贴板项、10,000 资源和连续文件传输的 heap/RSS 同场景对比，给出真实百分位而非估算。
4. 增加 Windows 实机上的原生弹窗、通知、托盘、窗口尺寸和辅助功能验收。
5. 增加 Studio 内“当前 MCP 子进程与所属 Agent 会话”只读诊断，帮助识别外部客户端长期保留的 MCP 进程；不要由 DingDong 擅自终止它们。

## 验证结果

| 验证项 | 结果 |
| --- | --- |
| `flutter analyze` | 0 问题 |
| `dart fix --dry-run` | Nothing to fix |
| `flutter test` | 964 通过、2 预期跳过、0 失败 |
| 桌面 golden | 31 张参考图全部通过 |
| PWA/relay `npm run check` | 52 / 52 通过 |
| `npm audit --omit=dev --registry=https://registry.npmjs.org` | 0 漏洞 |
| `git diff --check` | 通过 |
| macOS Debug | 成功，当前构建已用空数据目录启动并截图 |
| macOS Release | 成功，`DingDong.app` 102.1 MB |
| 手机浏览器 | 390 × 844 关键路径、弹窗和第二轮视觉复核通过 |

Release 构建仍报告 `objective_c` 与 `sqlite3` code asset 在不同架构使用不同 framework 名称的上游 warning，但产物打包成功。这是依赖提供方的兼容性维护项，不是本轮业务代码失败。依赖解析还提示 18 个受当前约束限制的新版本；本轮没有把未经专项回归的依赖升级混入功能修复。

自动化测试使用仓库既有 fake、fixture 与 golden；手机视觉测试使用本地静态服务和本地假配对，不代表生产中继、真实 Web Push 提供商或真实系统震动已被调用。对应真机步骤已经补入 `docs/product/manual-regression.md`。
