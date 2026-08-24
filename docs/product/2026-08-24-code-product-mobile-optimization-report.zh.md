# DingDong 全量代码、产品与手机端优化报告

日期：2026-08-24
基线：`codex/release-1.5.2` / `674879f`
环境：Flutter 3.44.6、Dart 3.12.2、Node.js 22.17.0

## 结论

本轮完成了代码可达性、静态质量、依赖安全、桌面弹窗、手机 PWA、通知链路、升级链路与关键交互的联合检查，并直接修复了已确认的问题。发布前最终自动化结果为：Flutter 964 项通过、2 项预期跳过、0 失败、0 点击警告；真实连接集成测试 1 项通过；PWA/中继 52 项通过；Flutter Analyze 0 问题；macOS Debug 与 Release 原生构建成功；生产依赖审计 0 漏洞。

审计范围内没有仍未处理的 P0/P1 级代码缺陷。仍需单独完成的主要工作是真机系统通知验收、Windows 原生人工验收，以及按计划拆分几个超大文件；这些边界在文末明确列出。

本报告落盘前，业务代码、测试与既有文档共修改 22 个文件，新增 768 行、删除 188 行；另删除 2 个废弃文件。本轮没有执行 Git add、commit、push 或部署。

## 已发现并修复的问题

| 级别 | 问题 | 用户影响 | 处理结果 |
| --- | --- | --- | --- |
| 高 | Agent 压缩推送与重连快照丢失 `notificationKind` / `needsUserAttention` | “需要你处理”可能在手机上退化成普通完成 | 全链路保留提醒语义，并增加回归测试 |
| 高 | PWA 主脚本升级后，其未带版本指纹的配对模块可能命中旧缓存 | 旧版本升级后可能出现模块导入失败，二维码流程无法启动 | 应用壳升级到 32；主脚本、样式、通知策略和配对模块统一指纹化 |
| 高 | 外部命令打开一次“剪贴板分类”后，切换工作区会重复打开旧弹窗 | 不可见弹窗遮罩会挡住侧栏点击 | 请求由父窗口精确消费一次；新增“弹窗不复现、导航可点击”回归断言 |
| 中 | 手机查看 Agent 提醒后不会回写已读状态 | 电脑未读数、手机角标可能长期不清 | 新增加密 `agent.seen` 协议，只确认实际展示的精确活动 ID |
| 中 | 系统通知没有清楚区分普通完成与等待用户处理 | 用户难以判断是否需要立即介入 | 标题、正文、操作按钮和震动请求按两类状态区分 |
| 中 | 手机删除设备使用浏览器原生 `confirm()` | 视觉不一致、无法按 DingDong 设计语言控制 | 替换为 DingDong 自有删除确认弹窗，并验证取消后回到设置 |
| 中 | 多个手机控件只有 17–42 px，部分开关缺少可访问名称，文件选择器不是语义按钮 | 触控和键盘可用性不足 | 核心触控目标统一到至少 44 px，补充焦点态、ARIA 名称和真实按钮语义 |
| 中 | 二维码配对只检查字段类型 | 异常 room、key 或 relay URL 能进入后续流程 | 增加长度、字符集、协议、凭据与 fragment 校验 |
| 低 | 运行卡片仍使用渐变、CSS 引用了不存在的 `--text-primary` | 偏离“安静、扁平、语义色”的产品理念 | 移除渐变，改用扁平语义背景并修复变量 |
| 低 | PWA 未声明 favicon | 本地和部分浏览器会请求不存在的 `/favicon.ico` | 复用正式 DingDong PWA 图标 |
| 低 | 原生剪贴板分享桥已无生产入口 | 增加维护面与原生通道噪声 | 删除 Dart 网关、对应测试与 macOS `shareText` 实现 |

## 手机通知优化

### 通知内容与优先级

- 普通完成显示“Agent 完成啦”，操作为“查看详情”，使用较短震动请求。
- 需要用户处理显示“Agent 需要你处理”，操作为“立即处理”，使用更明显的震动请求。
- 系统通知正文优先组合任务名称与结果/待处理详情，来源会进入标题，时间戳使用真实完成时间。
- 对不支持通知 actions 或 vibration 的系统分级降级，不影响基础通知显示。
- 手机卡片使用扁平的完成色/注意色，不再使用渐变，也不会把注意事项误写成普通完成。

### 已读与角标

- 手机仅在 Agent 标签实际可见、页面处于前台且设备在线时发送已读回执。
- 回执只携带当前渲染条目的精确 activity ID，去重、限长并限制单批最多 40 项。
- 电脑只更新已存在且未读的匹配活动；未知 ID、重复 ID 和延迟回执不会影响较新的活动。
- 支持 App Badge API 的浏览器同步未读数；Service Worker 创建后台通知时设置角标提示。

### 升级可靠性

- PWA 应用壳升级为 32。
- `styles.css`、`app.js`、`notification-policy.js`、`pairing-state.js` 使用同一应用壳版本指纹。
- 在真实 Chrome 旧缓存状态下复测：旧壳更新、新模块导入、二维码确认、主页、设置、删除确认均能正常工作。

## 界面与弹窗审计

### 桌面端

- 重新生成并检查 31 张桌面 golden 截图，覆盖主弹窗、资源管理、剪贴板分类、设置、深浅色和不同窗口尺寸。
- 所有直接 `showDialog` 路径均使用 DingDong 的 `DesktopAlertDialog` / `DesktopDialogFrame` 体系，没有残留默认 `AlertDialog`。
- 全局组件主题继续禁用 Material 默认 splash、圆形 ink 与无设计目的的 overlay；保留的是有明确语义的矩形悬停、聚焦和选中状态。
- 修复“剪贴板分类”旧请求在工作区重建后再次弹出、遮挡侧栏的问题，并把原先的测试警告升级为真实交互断言。

### 手机端

- 在 390 × 844 的真实 Chrome 视口复测未配对、配对确认、离线主页、设备切换、设置、删除确认与取消删除。
- 设备状态、设置、附件、发送、通知开关、震动开关、断开与删除等核心触控目标实测均至少为 44 px。
- 增加统一 `focus-visible`；开关补充可访问名称；附件入口改为真实按钮。
- 8–9 px 辅助文字提升到至少 10 px；修复未定义颜色变量。
- 删除确认改为产品内弹窗；危险操作、说明、取消与确认层级清晰。

视觉证据保存在本地 QA 目录：`.design-qa/audit-2026-08-24/`。其中包括桌面 31 图联系表、手机前后对比、最终设置和删除确认截图；该目录按项目约定不进入版本控制。

## 废弃代码与维护性

### 已删除

- `lib/platform/native_clipboard_share_gateway.dart`
- `test/platform/native_clipboard_share_gateway_test.dart`
- `macos/Runner/MainFlutterWindow.swift` 中废弃的 `sharingPicker` 属性与 `shareText` 方法通道

删除后全仓库已无 `native_clipboard_share_gateway` 或 `shareText` 引用，macOS 原生构建成功。

### 已完成的热点拆分

此前列出的维护热点均已按功能完成拆分，并保留原公开入口与行为。详细模块映射、代码优化和回归证据见 `docs/product/2026-08-24-maintenance-hotspot-refactor-report.zh.md`。

| 文件 | 拆分前 | 当前入口 | 已抽取职责 |
| --- | ---: | ---: | --- |
| `lib/features/library/ui/resource_editor.dart` | 2701 | 1084 | 窗口框架、各资源编辑区、交付配置和通用控件 |
| `lib/features/library/data/agent_resource_synchronizer.dart` | 1840 | 908 | 发现、持久化、序列化和并发合并 |
| `lib/features/clipboard/ui/clipboard_manager_screen.dart` | 1739 | 547 | 操作、筛选、详情弹窗和列表行 |
| `lib/main.dart` | 1519 | 687 | 系统维护及各独立窗口入口 |
| `lib/features/device_link/ui/device_link_controller.dart` | 1294 | 376 | 协议、文件、Agent 同步、持久化和支持工具 |
| `docs/app/app.js` | 3989 | 1192 | 11 个浏览器端职责模块 |

仓库扫描只发现一个 Flutter 生成的 Windows CMake TODO，以及 4 个有明确原因的 lint ignore；没有新增 `FIXME`、`HACK`、`@Deprecated` 或待迁移 API。`dart fix --dry-run` 没有建议的自动修复。

## 验证结果

| 验证项 | 结果 |
| --- | --- |
| `flutter analyze` | 0 问题，最终轮 153.1 秒 |
| `flutter test` | 964 通过、2 预期跳过、0 失败、0 点击警告 |
| 资源库单线程回归 | 205 通过；定位并修复了原弹窗遮挡警告 |
| PWA / relay `npm run check` | 52 / 52 通过 |
| Node 语法检查 | `app.js`、`service-worker.js` 通过 |
| `npm audit --omit=dev` | 0 漏洞（官方 npm registry） |
| `dart fix --dry-run` | 无可用修复 |
| `git diff --check` | 通过 |
| macOS Debug 构建 | `DingDong DEV.app` 构建成功 |
| 桌面视觉回归 | 31 张 golden 截图生成并人工检查 |
| 手机 Chrome 视觉/交互 | 关键页面和弹窗通过；最终核心触控目标均 ≥ 44 px |

自动化测试使用仓库既有的 fake、fixture 与 golden 数据；手机浏览器视觉巡检使用本地静态服务和本地配对测试数据，不代表生产中继或真实 Web Push 提供商已被调用。没有使用这些测试数据冒充真实用户、真实任务或生产通知结果。

## 修改文件清单

### 桌面与协议

- `lib/features/activity/ui/activity_controller.dart`：精确批量标记已读。
- `lib/features/device_link/ui/device_link_controller.dart`：已读协议、提醒语义保留与输入约束。
- `lib/features/clipboard/ui/clipboard_manager_screen.dart`：分类弹窗请求消费回调。
- `lib/features/library/ui/resource_manager_app.dart`：记录已消费请求，防止重建后重复弹窗。
- `lib/main.dart`：连接手机已读回执到 ActivityController。
- `macos/Runner/MainFlutterWindow.swift`：移除废弃分享通道。

### 手机 PWA

- `docs/app/app.js`：已读回执、角标、注意状态、删除弹窗、附件按钮、升级指纹。
- `docs/app/service-worker.js`：分类通知、操作、时间戳、震动降级与角标。
- `docs/app/notification-policy.js`：统一通知语义与文案生成。
- `docs/app/pairing-state.js`：严格二维码配对校验。
- `docs/app/index.html`：语义、设置文案、删除弹窗、favicon 与资源指纹。
- `docs/app/styles.css`：44 px 触控、焦点态、字体下限、扁平语义色与弹窗样式。
- `docs/app/version.json`：应用壳 32。

### 测试与说明

- `test/features/activity/activity_controller_test.dart`
- `test/features/device_link/device_link_controller_test.dart`
- `test/features/library/resource_manager_app_test.dart`
- `device_link_relay/test/pwa-contract.test.js`
- `README.md`
- `README.zh.md`
- `docs/product/manual-regression.md`

## 仍缺失或值得补充的功能

### P1：通知控制与真机发布门禁

1. 增加“普通完成”和“需要我处理”的独立开关、安静时段、稍后提醒/暂停提醒；目前只能整体开关 Agent 状态提醒。
2. 建立 Android 安装版 PWA 与 iPhone/iPad 主屏幕 PWA 的发布门禁：前台、后台、锁屏、权限拒绝后恢复、普通完成、等待处理、角标、点击跳转、系统震动全部留档。
3. 为 Service Worker 真实升级建立浏览器 E2E；本轮旧缓存模块问题证明单纯源码契约测试不足以覆盖缓存迁移。

### P2：行动闭环与信息管理

1. 为“需要你处理”提供安全的行动闭环：在具备稳定 conversation target 和明确授权时，跳转到对应对话或把处理请求交给桌面端；没有稳定目标时继续保持只读提醒。
2. 为 Agent 提醒增加按状态/来源筛选、只看未读和批量标记已读，避免长期使用后列表密度过高。
3. 按上面的热点表逐步拆分超大文件，并以现有 964 项测试作为迁移保护。

## 未覆盖边界

- 没有主动请求系统通知权限、订阅真实 Web Push 或触发真实手机震动，因为这些动作需要用户同意和真机系统状态。
- 没有完成锁屏 iOS/Android 真机通知验收；对应步骤已写入 `docs/product/manual-regression.md`。
- 当前环境完成了 macOS 构建与跨平台自动化，但没有 Windows 实机上的窗口、系统通知和弹窗视觉人工验收。
- 依赖解析提示 18 个版本受当前约束限制；生产依赖安全审计为 0 漏洞，因此本轮没有混入未经专项回归的主版本升级。

下一步最有价值的是用一台 Android 和一台 iPhone 跑新增的锁屏通知回归清单，并把系统权限、声音/震动和通知点击行为录入发布证据。
