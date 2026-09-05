# DingDongBuddy 全项目测试与 Android PWA 优化报告

日期：2026-09-05。测试、修改均在 `DingDongBuddy/` 内完成。所有手机传输内容和文件均为明确标记的合成测试数据。

本轮修复了大文件传输缓冲失控、断线后下载内存未释放、异步消息队列无上限、发送过程中草稿被清空、IndexedDB 异常清理和长设备名布局等问题。修改保留在本地工作区，未执行 Git 暂存、提交、推送或线上发布。PWA 应用版本仍为 1.5.5，资源缓存版本从 shell 39 更新至 40。

## 改了什么

| 问题 | 修复后的行为 | 主要文件 |
| --- | --- | --- |
| 原生 WebRTC 连续发送大文件时，发送缓冲过高，实测 25 MiB 下载失败 | 查询原生 DataChannel 缓冲；超过 1 MiB 等待排空，最多等待 15 秒；连接变化时停止旧发送 | `lib/features/device_link/data/device_link_session.dart` |
| 文件分块在直连和中继之间切换可能乱序 | PWA 固定 file.start 实际使用的通道对象；原生端在各帧前后校验会话、连接与传输方式；变化后停止并允许重新发起 | 原生与 PWA 文件传输模块 |
| 手机下载中断后仍保留已接收的二进制数据 | 所有可用连接断开时清理下载、计时器和旧内容；无新分块 60 秒后回收未完成下载 | `docs/app/app-content-transfer.js`、`app-connection.js` |
| 断线前开始的异步解密，可能在断线后重新填充列表 | 消息带有内容代次校验；断线后旧队列的结果不再生效；中继断开但直连仍有效时保留正常会话 | `docs/app/app-connection.js` |
| PWA 入站消息和 ICE 候选可能无限排队，占用手机内存 | PWA 单帧/加密封包限制 256 KiB；中继队列与解密队列分别限制 256 项、8 MiB；ICE 候选限制 256 项、1 MiB；超限关闭对应会话并提示重新连接 | `docs/app/app-codecs.js`、`app-connection.js` |
| 重复点击发送，以及发送期间继续输入，可能造成重复发送或草稿丢失 | 每会话只允许一个发送操作；按钮显示“发送中…”；仅清理实际发送的内容，保留后来输入的文字和新选文件 | `docs/app/app-content-transfer.js`、`app-rendering.js`、`app.js` |
| 浏览器中继上传缺少缓冲控制；文件读取失败显示底层错误 | 上传同时检查 WebRTC / WebSocket 缓冲和超时；读取失败提示重新选择；保存入口异常时立即释放 Blob URL | `docs/app/app-content-transfer.js` |
| IndexedDB 事务失败、中止或同步异常时，数据库连接可能不关闭 | 统一通过 finally 关闭；读操作等待事务完整结束；异常路径明确返回失败 | `docs/app/app-storage.js`、`service-worker.js` |
| 并发通知对去重账本读改写，可能覆盖其他通知记录 | Service Worker 串行更新账本，每次读取最新记录；保留相同通知的去重逻辑 | `docs/app/service-worker.js` |
| 长设备名挤压设置按钮、撑宽弹窗和发送说明 | 设置按钮保持 44 px；名称可换行，设置标题最多显示三行；发送目标单行省略；完整名称保留在可访问名称中 | `docs/app/styles.css` |
| 输入框和多个弹窗缺少明确的可访问名称 | 补齐 textarea 的 aria-label 和弹窗 aria-labelledby | `docs/app/index.html` |
| 中继已连接但电脑不在线时，一直显示连接中 | 收到中继 ready 后正确展示电脑离线，并在电脑加入后恢复连接 | `docs/app/app-connection.js` |

## Android 真机结果

设备为 2304FPN6DC，Android 16，Chrome 152，物理分辨率 1440 × 3200。使用 USB 调试连接真实手机；本地 Worker 通过 ADB reverse 提供修改后的 PWA。未使用 Android 模拟器。

主链路测试使用实际 Flutter `WebRtcDeviceLinkSession`、原生 WebRTC 和生产加密编码，在 macOS 与 Android Chrome 之间传输。测试宿主仅替代真实业务数据源，没有操作用户剪贴板或真实项目内容。辅助内存与列表压力场景使用显式 Node 测试宿主。

| 场景 | 结果 |
| --- | --- |
| 配对、连接、文字发送与回传 | 通过；原生直连与服务中继分别验证 |
| Android → macOS 上传 1 MiB 文件 | 32 个分块，完整接收，SHA-256 一致；文件由浏览器 File API 构造，用于验证传输与加密 |
| macOS → Android 下载文本文件 | 实际手机 Download 目录生成文件，内容和 SHA-256 一致 |
| macOS → Android 连续发送 25 MiB 文件 | 修复前现场观察到接收不完整，保留的状态记录为 serviceRelay；修复后约 20.8 秒完成，全程 localNetwork，无会话错误，实际手机文件大小和哈希一致 |
| PWA 最终变更后再次上传 1 MiB | 通过真实 Android Chrome 经中继发送给 Node 测试宿主，32 个分块、SHA-256 一致、无页面 JavaScript 异常 |
| 接收 8 MiB 文件中的 2 MiB 后断开宿主 | 修复后释放已接收缓冲，旧内容不再回填 |
| 切换剪贴板、Agent 页面和设置 30 轮 | DOM 节点、事件监听器无持续增长，见下表 |
| 断网后重新加载 | Service Worker 离线页面可打开，正确展示离线状态 |
| 正常竖屏 | 411 CSS px 宽度，页面无横向溢出 |
| 320 CSS px 窄屏、80 字符长设备名 | 真机 Chrome 中额外调整视口测试；页面宽 320，弹窗 clientWidth 与 scrollWidth 均为 282，设置按钮宽 44，标题约 71 px 高 |
| 实际旋转手机至横屏 | 873 × 298 CSS px 可用页面，scrollWidth 为 873，无横向溢出；测试后恢复原来的自动旋转设置 |
| Android 软键盘 | 实际系统截图确认输入框与发送按钮位于键盘上方；浏览器会平移 visual viewport，未把坐标差异误判为遮挡缺陷 |

25 MiB 文件的实际与预期 SHA-256 均为：

```text
c2d296ee70fec92d13d1821757ee6df0b7c1e42ae7577c5a2d98277d716a46b5
```

修复前的 JSON 未记录完整回退事件链，因此不将其单独作为“缓冲饱和导致回退”的充分证据；问题判断结合当时真机观察、发送代码和修复后压力复测。最后增加的原生文件生命周期保护由控制器与全量测试覆盖，未再次启动专用宿主重跑 25 MiB 场景。

## 内存优化证据

以下为 Chrome DevTools Protocol 对当前 PWA 页面的采样，采样包含垃圾回收。`backingStorageSize` 是字符串/ArrayBuffer 等后备存储指标，不能等同于整个 Chrome 或手机的总内存。

| 场景 | 修复前 | 修复后 |
| --- | ---: | ---: |
| 接收部分文件后，宿主断开，后备存储仍占用 | 2,258,838 B，约 2.15 MiB | 164,449 B，约 0.16 MiB |
| 修复后同一轮：断开前已有 2 MiB 数据 → 断开后 | — | 2,261,586 B → 164,449 B，释放约 2 MiB |

| 30 轮页面/弹窗操作 | 开始 | 结束 |
| --- | ---: | ---: |
| JavaScript usedSize | 899,560 B | 918,796 B |
| backingStorageSize | 170,915 B | 171,000 B |
| DOM 节点 | 717 | 716 |
| 事件监听器 | 46 | 46 |
| Document | 1 | 1 |

这是有限时长、有限数据量的稳定性验证，不代表所有长期运行场景都不存在泄漏。成功下载的 Blob URL 仍保留 30 秒后释放，以兼容浏览器保存流程；此次修复的是中断/异常时的不必要保留。

## 自动化测试与构建

| 检查 | 结果 | 证据 |
| --- | --- | --- |
| Flutter 静态分析 | 无问题 | `flutter-analyze-final-transfer-guard.log` |
| Flutter 全量单元、组件、Golden 测试 | 1034 通过、2 项环境性跳过、0 失败；基线为 1031 通过 | `flutter-test-full-final-transfer-guard.log` |
| 原生传输控制器回归 | 40/40 通过，包含传输方式变化时中止及重新发送 | `flutter-device-link-controller-transport-guard.log` |
| macOS 桌面发布验收集成 | 7/7 通过；该套件不覆盖文件传输，最后一次文件保护变更由上述全量与控制器测试覆盖 | `flutter-integration-desktop-release-acceptance-final.log` |
| Swift SelectionPlugin | 23/23 通过 | `swift-selection-plugin.log` |
| PWA 与中继 npm run check | 90/90 通过，包含 JavaScript 语法检查；基线为 58 项 | `npm-run-check-final.log` |
| macOS debug 构建 | 成功；恢复默认 lib/main.dart 入口，产物为 DingDong DEV.app | `flutter-build-macos-debug-final-transfer-guard.log` |
| Worker 发布 dry-run | 成功，仅验证打包和绑定，未发布 | `worker-dry-run.log` |
| Git diff 空白检查 | 通过 | `git diff --check` |

两个跳过项分别依赖 Windows 平台和未配置的 PI_EXECUTABLE。桌面集成过程中有应用前台激活警告，但全部 7 项测试完成并通过。

新增行为测试覆盖：发送去重、保留编辑中的草稿、替换文件、旧发送上下文失效、上传缓冲等待及中断、下载超时清理、文件异常提示、断线后异步内容隔离、保留仍有效的直连、离线状态、消息队列/帧/ICE 上限、IndexedDB 异常关闭、并发通知账本、原生 WebRTC 缓冲等待和断线中止，以及传输方式变化时禁止跨通道继续发送。

## 验证范围与剩余限制

- 本轮真机运行的是 Chrome 中的 PWA，验证了 Service Worker 和离线加载；未完成安装为独立主屏幕应用后的整套验收，也未完成系统文件选择器选取真实用户文件的端到端上传。
- 手机访问线上域名时出现过 `ERR_CONNECTION_CLOSED`，因此真机主要验证本地修改版本。桌面访问线上域名返回 HTTP 200；不能据此认定手机网络故障来自应用。线上推送、锁屏后台通知和公网跨网络连通性未作完成声明。
- 调试期间查询 Chrome 协议元数据时出现过一次 Chrome 原生 SIGTRAP 崩溃；Android 退出记录标记为 native crash，未标记 OOM。重启后继续完成传输测试，现有证据不能把该崩溃归因于 PWA。
- macOS 为本轮实际桌面执行平台；Windows 原生运行和 Pi 外部执行器测试受当前环境限制。没有为了消除依赖更新提示而批量升级依赖。
- 测试宿主、USB 转发和临时测试文件已清理，测试标签页已关闭，仅清除了 localhost:8795 测试站点的数据。原始日志和截图保留在本地 `build/quality-audit-2026-09-05/`。该目录受 Git 忽略，报告本身保留在 `reports/`。

## 证据与复查入口

本地证据目录：`build/quality-audit-2026-09-05/`。

- `native-android-e2e.json`、`native-relay-e2e.json`：原生与手机文字/上传验证。
- `android-final-upload.json`：最终 PWA 上传回归，使用 Node 测试宿主。
- `large-download-native.json`、`large-download-after.json`：25 MiB 修复前后对比。
- `download-memory-before.json`、`download-memory-after.json`：中断下载的内存对比。
- `interaction-memory.json`：30 轮操作内存与 DOM 计数。
- `pwa-offline.json`、`android-offline-after.png`：离线启动。
- `android-long-name-before.png`、`android-final-long-name-320.png`：长设备名修复前后。
- `android-keyboard-before-native.png`、`android-real-landscape.png`：实际 Android 屏幕截图。
- `pwa-review.md`：修复前的静态检查记录，不能用作最终缺陷清单。
- `*final*.log`：最终回归日志，最新原生回归使用 `final-transfer-guard` 后缀；`swift-selection-plugin.log`、`worker-dry-run.log`：原生插件与 Worker 构建验证。

协作执行使用 3 个原生 Codex Luna 辅助 Agent，分别负责测试与原生传输、PWA 连接审查、存储与 Service Worker；主 Agent 负责整合、Android 真机验证和报告。执行器未提供可核实的逐 Agent token 数，未作估算。
