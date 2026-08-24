# DingDong 维护热点拆分与回归报告

日期：2026-08-24
范围：此前《Studio、MCP、Prompt、内存与界面最终优化报告》中“仍然较大的维护热点”列出的全部 6 个文件。

## 结论

6 个维护热点均已按功能边界拆分完成。原入口文件合计由 13082 行降至 4794 行，减少 8288 行（约 63.4%）。公开入口、关键方法签名、持久化键、连接协议和界面行为保持不变；拆分后的模块带有职责边界注释，测试中的源码契约也已适配多文件结构。

本轮不是单纯搬运行数：Dart 侧利用同 library 的 `part` 保持私有边界和现有状态所有权，PWA 侧使用 ES module 工厂和显式依赖注入，避免新模块重新依赖全局变量。另删除了一个确认无调用的 IndexedDB 包装函数 `idbSet`。

## 拆分明细

| 原入口 | 拆分前 | 当前入口 | 变化 | 新模块与职责 |
| --- | ---: | ---: | ---: | --- |
| `resource_editor.dart` | 2701 | 1084 | -59.9% | `resource_editor_chrome.dart`（窗口框架）、`resource_editor_skill_section.dart`、`resource_editor_mcp_section.dart`、`resource_editor_delivery_section.dart`、`resource_editor_controls.dart` |
| `agent_resource_synchronizer.dart` | 1840 | 908 | -50.7% | `agent_resource_targets.dart`（目标发现）、`synchronized_resource_store.dart`（持久化）、`agent_resource_serialization.dart`、`agent_resource_concurrent_merge.dart` |
| `clipboard_manager_screen.dart` | 1739 | 547 | -68.5% | `clipboard_manager_actions.dart`、`clipboard_manager_filters.dart`、`clipboard_details_dialog.dart`、`clipboard_manager_rows.dart` |
| `main.dart` | 1519 | 687 | -54.8% | `main_system_maintenance.dart`、`main_settings_windows.dart`、`main_development_window.dart`、`main_clipboard_windows.dart`、`main_resource_window.dart` |
| `device_link_controller.dart` | 1294 | 376 | -70.9% | `device_link_agent_sync.dart`、`device_link_file_transfer.dart`、`device_link_session_protocol.dart`、`device_link_persistence.dart`、`device_link_support.dart` |
| `docs/app/app.js` | 3989 | 1192 | -70.1% | 11 个模块，覆盖编解码、格式化、存储、平台、安装、通知、渲染、连接、设置、配对和内容传输 |

## 设计与代码优化

### 资源编辑器

- 根状态只负责资源加载、编辑状态和保存编排，各资源类型 UI 不再挤在同一个文件。
- Skill、MCP 和交付配置拥有独立区域，后续修改一个资源类型时不必阅读另外两类实现。
- 通用表单控件与窗口框架集中，避免各段重复定义相同视觉规则。

### Agent 资源同步

- 目标发现、磁盘存储、文本序列化和并发三方合并形成独立边界。
- 保留同步器作为流程协调者，错误与问题汇总仍沿用原路径，避免改变对外结果。
- 并发合并逻辑从 I/O 代码中分离，便于单独理解冲突保留策略。

### 剪贴板管理器

- 批量/单项动作、筛选、详情弹窗和列表渲染分别维护。
- 屏幕根部只保留选择状态、数据流和页面级布局，降低修改弹窗或行样式时的影响范围。

### 应用启动与窗口入口

- `main.dart` 保留启动顺序、依赖装配和顶层分发。
- 系统维护及四类独立窗口拆到对应模块，窗口专属初始化不再干扰主启动路径。
- 资源管理器“首帧完成后再显示窗口”的顺序保持不变；对应打包契约测试改为读取实际所属模块。

### 设备连接控制器

- Agent 同步、文件传输、会话消息、持久化和辅助逻辑拆成 extension part，仍共享同一控制器私有状态。
- 公共控制器 API 未迁移，调用方无需感知文件拆分。
- 增加 `_notifyIfActive()` 作为受控通知入口，extension 不再直接触碰受保护的 `notifyListeners()`，分析器无需 lint 豁免。

### 手机 PWA

- `app.js` 现在负责初始状态和模块装配；功能代码拆为 11 个 ES modules。
- 模块通过工厂参数声明依赖，避免隐式全局耦合并减少循环依赖风险。
- Service Worker 预缓存清单、页面脚本版本及发布版本同步更新；shell 指纹升级到 35，旧缓存可以按既有升级流程替换。
- relay 源码契约测试会聚合模块源码，不会因文件拆分而失去对通知、配对和连接行为的保护。
- 删除未使用的 `idbSet`，保留仍被调用的 IndexedDB 读写入口。

## 浏览器运行时复核

静态测试通过后，又在隔离的本地浏览器环境实际加载模块化 PWA。该步骤发现并修复了 4 个只有浏览器初始化顺序才会暴露的问题：

1. 配对模块遗漏 `loadJson`、`base64UrlDecode` 和 `showToast` 依赖。
2. 渲染模块未导出 `scheduleAgentSeenAcknowledgement`。
3. 平台状态 `isIos` 在初始状态读取时出现暂时性死区。
4. 依赖运行时状态的 `isBrowserPwaLauncher` 被错误放入纯平台模块。

修复后验证了全新空状态、损坏二维码、已配对设备、标签切换、设置弹窗、图标背景切换、设备切换器以及删除确认的打开与取消。最终控制台没有错误或警告。测试没有申请真实通知权限、没有确认删除，也没有把本地假配对当作真机 Web Push 证据。

## 兼容与测试调整

- `device_link_relay/test/pwa-contract.test.js` 聚合新的 PWA modules、设备控制器 parts 和 `main.dart` parts，保持原源码契约覆盖。
- `test/packaging/desktop_identity_test.dart` 改为从 `main_resource_window.dart` 检查资源窗口首帧顺序；这是对文件归属变化的适配，不是放宽断言。
- Dart 拆分均位于原 library，私有类型、私有方法和现有测试可见性没有变化。
- PWA 对外 DOM、存储键、URL/hash 配对入口、Service Worker 消息与 relay 协议没有改名。

## 验证结果

| 验证项 | 最终结果 |
| --- | --- |
| 热点定向 Flutter 测试 | 89 项通过 |
| `flutter test` 全量回归 | 964 通过、2 个预期跳过、0 失败；包含全部 golden |
| `flutter analyze` | 0 问题（245.9 秒） |
| `dart fix --dry-run` | `Nothing to fix!` |
| PWA / relay `npm run check` | 52 / 52 通过 |
| JavaScript `node --check` | 所有 `app*.js` 与 `service-worker.js` 通过 |
| 浏览器 bundle | esbuild 成功生成 158.9 kB ESM bundle |
| 隔离浏览器运行时复核 | 新安装、坏二维码、已配对状态及关键弹窗通过，控制台 0 错误、0 警告 |
| macOS Debug | 成功生成 `build/macos/Build/Products/Debug/DingDong DEV.app` |
| macOS Release | 成功生成 `build/macos/Build/Products/Release/DingDong.app`（102.1 MB） |
| `git diff --check` | 通过 |

全量回归首轮曾有 1 条打包测试失败：测试仍从 `main.dart` 搜索已经拆到 `main_resource_window.dart` 的函数。调整测试读取位置后，该测试定点通过；发布前又补充了传输异常清理回归，最终全量回归 964 项全部通过，断言内容没有放宽。

Release 构建输出了 `objective_c` 与 `sqlite3` code asset 在不同架构下 framework 名称不一致的依赖警告，但最终打包成功。本轮没有修改这两个依赖；建议在后续依赖升级窗口继续跟踪其 build hook。

## 未冒充覆盖的边界

- 本轮没有使用生产 relay、真实手机或真实 Push 订阅，因此不声称覆盖 Android/iOS 锁屏通知和系统权限恢复。
- 本地浏览器配对数据是专门用于 UI 冒烟的假数据，没有发起真实设备删除或业务写操作。
- 本轮只处理原报告明确列出的 6 个热点；其他文件若未来因功能增长形成新热点，应按同样的职责边界和测试先行原则处理。
