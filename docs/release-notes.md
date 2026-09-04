# DingDong 1.5.5

DingDong 1.5.5 fixes workspace shortcut switching and macOS tray badge alignment,
and removes redundant code.

- Refines macOS tray unread badges with balanced horizontal padding and vertically centered counts.
- Fixes stuck shortcut hints after releasing Ctrl and restores consecutive Ctrl+Q/W/E workspace switching.
- Consolidates duplicate UUID and clipboard shortcut handling, and removes unused code and website icons.

---

# DingDong 1.5.5

DingDong 1.5.5 修复工作区快捷键切换与 macOS 托盘徽标对齐，并清理冗余代码。

- 调整 macOS 托盘未读徽标的左右留白，使数字垂直居中。
- 修复松开 Ctrl 后快捷键提示仍残留、连续 Ctrl+Q/W/E 切换失效的问题。
- 合并重复 UUID 与剪贴板快捷键处理，清理无用代码和闲置网页图标。

---

# DingDong 1.5.5

DingDong 1.5.5 corrige los atajos de cambio de vista y la alineación de los
distintivos de macOS, y elimina código redundante.

- Ajusta los distintivos de no leídos de macOS con márgenes equilibrados y números centrados verticalmente.
- Corrige la ayuda de atajos que quedaba visible al soltar Ctrl y permite cambios consecutivos con Ctrl+Q/W/E.
- Consolida el código duplicado de UUID y atajos del portapapeles, y elimina código e iconos web sin uso.

---

# DingDong 1.5.4

DingDong 1.5.4 brings optional system selection tools to macOS, connects trusted
computers, and tightens the interaction and lifecycle paths used by Agent work.

- Enable **System selection tools** in Settings to copy, translate or explain
  selected text. This is off by default and requires Accessibility permission
  for the running DingDong app. Translation and explanation need your own
  available model service; no model or API credit is bundled.
- Model credentials are isolated by provider and origin in the macOS Keychain.
  Disabling the feature cancels monitoring and pending requests; changing
  providers clears unsaved Token input. Do not run the standalone selection
  helper alongside the built-in host.
- Link another computer and choose automatic, local-network or encrypted-service
  transport. New computer links start with automatic clipboard sync and Agent
  reminders off; explicit sends remain under your control.
- Agent session-start acknowledgement clears the matching conversation's unread
  reminders. Clipboard keyboard actions and settings-window synchronization keep
  their state when switching or reopening views.
- Mobile read receipts clear the corresponding tray count, per-device relay
  settings also apply to background push, and unrelated completion events no
  longer consume a running conversation. Project-native Skills establish an
  exact scope that also works for Agents using dynamic delivery.
- MCP search accepts its documented `all` filter while keeping clipboard data
  private. Closed windows release their callbacks, and the mobile page reports
  copy failures and prevents duplicate pairing submissions.
- Shared Swift sources replace duplicate copies, unused interfaces are removed,
  and native-host interaction journeys join the release checks. The README and
  website also link to the DingDong Codex Pet project (repository access required).

All supported desktop packages use the stable `latest` release channel. System
selection tools are macOS-only; the other desktop changes also apply to Windows.

---

# DingDong 1.5.4

DingDong 1.5.4 为 macOS 加入可选的系统划词工具，支持可信电脑之间互联，
并改进 Agent 工作中的交互和会话状态处理。

- 在设置中开启“系统级划词”，即可复制、翻译或解释选中的文本。功能默认关闭，
  需要为当前 DingDong 应用授予辅助功能权限；翻译和解释需要自行配置可用模型服务，
  不附带模型或 API 额度。
- 模型 Token 按 Provider 和服务来源隔离存入 macOS 钥匙串。关闭功能会取消监听与
  未完成请求；切换 Provider 会清空未保存的 Token。不要同时运行独立划词助手。
- 可以连接另一台电脑，并选择自动、局域网或加密服务传输。新电脑连接的自动剪贴板
  同步和 Agent 提醒默认关闭；主动发送仍由用户控制。
- Agent 会话启动确认只清除对应会话的未读提醒；剪贴板键盘操作和设置窗口同步
  在切换、关闭和重开后保持状态。
- 手机已读回执同步清除对应托盘计数，自定义设备中继同样用于后台推送；不同会话
  的完成事件不会误结束已有任务。项目原生 Skill 自动绑定精确项目范围，也能供其他
  使用动态投递的 Agent 在该项目中加载。
- MCP 搜索支持声明的 `all` 筛选，并继续隔离剪贴板内容。关闭窗口会释放回调；
  手机页面会提示复制失败，并避免重复提交配对。
- 合并重复 Swift 源码、删除未使用接口，并增加真实桌面宿主的交互验收。README
  与官网同时增加 DingDong Codex Pet 项目链接，访问该仓库需要权限。

全部受支持的桌面安装包使用正式版 `latest` 通道。系统划词仅支持 macOS，
其他桌面改进也适用于 Windows。

---

# DingDong 1.5.4

DingDong 1.5.4 incorpora herramientas opcionales de selección de texto en macOS,
conecta ordenadores de confianza y mejora las interacciones y el estado de Agent.

- Las herramientas de selección están desactivadas inicialmente y requieren
  permiso de Accesibilidad. Copiar no necesita modelo; traducir y explicar
  requieren un servicio configurado por el usuario, sin modelos ni créditos incluidos.
- Las credenciales se separan por proveedor y origen en el Llavero de macOS.
  Desactivar cancela la monitorización y las solicitudes; cambiar de proveedor
  borra el Token que aún no se haya guardado. Utiliza un solo asistente de selección.
- Los enlaces entre ordenadores permiten transporte automático, de red local o
  mediante el servicio cifrado. La sincronización automática del portapapeles y
  los avisos de Agent empiezan desactivados para cada nuevo equipo.
- La confirmación al abrir una sesión solo marca sus propios avisos como vistos.
  Mejoran los atajos, la persistencia de ajustes y las comprobaciones de escritorio;
  se elimina código redundante y se enlaza DingDong Codex Pet (requiere acceso).
- Los recibos móviles actualizan el contador de la bandeja y las notificaciones
  usan el servidor de cada dispositivo. Las Skills nativas del proyecto conservan
  un ámbito exacto también para otros Agents con entrega dinámica.
- La búsqueda MCP admite `all` sin exponer el portapapeles. Se liberan las
  devoluciones de llamada al cerrar ventanas, se informan los errores de copia
  y se evitan confirmaciones duplicadas de emparejamiento.

Los paquetes compatibles usan el canal estable `latest`. La selección del sistema
es exclusiva de macOS; los demás cambios de escritorio también llegan a Windows.

---

# DingDong 1.5.3

DingDong 1.5.3 hardens fresh-install startup, scoped Agent resources, mobile
alerts, file transfer, and long-running memory use. It also splits the largest
desktop and PWA maintenance hotspots without changing their public contracts.

## Keep startup and Agent resource delivery dependable

- Fresh installations now start device linking from the already-loaded Settings
  snapshot, avoiding an early localization read before Settings is ready.
- Project- and repository-scoped MCPs remain installed for matching Agent
  sources, while the Bridge evaluates their task context at runtime.
- MCP initialization and native Agent prompts now share one canonical Bridge
  guide, and delivery metrics are recorded in one atomic receipt.

## Bound file transfer, queues, and memory

- Phone uploads stream in order to temporary files, allow at most three
  concurrent transfers, and clean up malformed, interrupted, or timed-out data.
- Encrypted device input has an explicit bounded queue; Agent history caches,
  MCP responses, Skill downloads, and package hashing now have bounded or
  streaming paths instead of retaining complete histories or files.

## Make mobile alerts and PWA upgrades more trustworthy

- Completion and attention semantics survive live delivery, reconnection, and
  Web Push. The phone acknowledges only the exact visible activity IDs and keeps
  supported app badges in sync.
- Notification copy, actions, and requested vibration distinguish completed
  work from work needing attention, with capability-safe fallbacks.
- PWA shell 35 modularizes browser responsibilities, validates pairing input
  more strictly, improves touch and keyboard accessibility, and replaces the
  native device-delete confirmation with a DingDong dialog.

All supported desktop packages are published through GitHub's stable `latest`
channel.

---

# DingDong 1.5.3

DingDong 1.5.3 加固全新安装启动、Agent 作用域资源、手机提醒、文件传输与长期运行
内存边界，并在不改变公开契约的前提下拆分桌面端和 PWA 的主要维护热点。

## 让启动与 Agent 资源交付更可靠

- 全新安装从依赖层已加载的 Settings 快照启动设备连接，避免 Settings 尚未就绪时
  过早读取本地化导致启动失败。
- 项目与仓库作用域 MCP 会继续安装到匹配的 Agent 来源，再由 Bridge 在运行时结合
  当前任务上下文完成精确判断。
- MCP 初始化和 Agent 原生 Prompt 共用一份 Bridge 权威指南；交付指标通过一次原子
  回执写入，减少漂移和并发冲突。

## 为文件传输、队列和内存建立硬边界

- 手机上传按顺序流式写入临时文件，最多同时处理三个传输；字段异常、断线或超时都会
  清理未完成文件。
- 加密设备输入使用明确的有界队列；Agent 历史缓存、MCP 响应、Skill 下载与包摘要
  改为有上限或流式路径，不再长期保留完整历史或文件。

## 让手机提醒与 PWA 升级更可信

- 普通完成与需要处理语义贯穿实时消息、重连和 Web Push；手机只回写实际可见活动的
  精确 ID，并在系统支持时同步应用角标。
- 通知文案、操作与震动请求会区分“已完成”和“需要处理”，不支持的系统安全降级。
- PWA shell 35 拆分浏览器职责，加强配对输入校验、触控和键盘可访问性，并用 DingDong
  自有弹窗替代设备删除的浏览器原生确认框。

全部受支持的桌面安装包都通过 GitHub 正式版 `latest` 通道发布。

---

# DingDong 1.5.3

DingDong 1.5.3 refuerza el inicio de instalaciones nuevas, los recursos de
Agent con alcance, los avisos móviles, la transferencia de archivos y los
límites de memoria. También divide los mayores puntos de mantenimiento del
escritorio y la PWA sin cambiar sus contratos públicos.

## Inicio y entrega de recursos más fiables

- Las instalaciones nuevas inician el enlace de dispositivos desde la
  configuración ya cargada y evitan leer la localización antes de tiempo.
- Los MCP con alcance de proyecto o repositorio siguen instalados para los
  orígenes de Agent compatibles; el Bridge evalúa después el contexto real.
- La inicialización MCP y los prompts nativos comparten una guía canónica, y las
  métricas de entrega se guardan con un único recibo atómico.

## Límites para archivos, colas y memoria

- Las cargas del teléfono se escriben en orden en archivos temporales, con un
  máximo de tres transferencias simultáneas y limpieza ante errores o cortes.
- La entrada cifrada usa una cola acotada; el historial de Agent, las respuestas
  MCP, las descargas de Skill y los resúmenes de paquetes usan límites o flujos.

## Avisos móviles y actualizaciones PWA más fiables

- La semántica de finalización o atención se conserva en mensajes en vivo,
  reconexiones y Web Push. El teléfono confirma solo los identificadores
  visibles exactos y sincroniza la insignia cuando el sistema lo permite.
- El texto, las acciones y la vibración solicitada distinguen el trabajo
  terminado del que necesita atención, con degradación segura por capacidad.
- PWA shell 35 modulariza el navegador, valida mejor el emparejamiento, mejora
  la accesibilidad táctil y de teclado, y usa un diálogo propio para eliminar.

Todos los paquetes de escritorio compatibles se publican mediante el canal
estable `latest` de GitHub.

---

# DingDong 1.5.2

DingDong 1.5.2 removes two intermittent interruptions from everyday Agent and
clipboard work: internal Codex jobs no longer surface as user reminders after
they disappear, and Command-number quick paste now follows the same reliable
preview-dismissal path as double-click and Return.

## Quieter Agent activity and reliable quick paste

- Ephemeral Codex background jobs that return the exact `thread not loaded`
  protocol result are classified as non-persisted background activity instead
  of ordinary completions. Unrelated App Server failures still fail open so
  genuine user-thread reminders are not silently hidden.
- Command-number clipboard shortcuts now dismiss an open preview before
  restoring and pasting the selected item, matching double-click and Return.
- Regression tests protect both notification classification and clipboard
  shortcut ordering.

All supported desktop packages are published through GitHub's stable `latest`
channel.

---

# DingDong 1.5.2

DingDong 1.5.2 修复两个会打断日常 Agent 与剪贴板工作的偶发现象：Codex 内部临时
任务停止并消失后不再冒充用户提醒；Command + 数字快速粘贴也会走与双击、回车一致
的可靠预览关闭流程。

## 更安静的 Agent 动态与更可靠的快速粘贴

- 对明确返回 `thread not loaded` 的 Codex 临时后台任务，按未持久化后台活动处理，
  不再生成普通完成提醒。其他 App Server 异常仍保持开放式容错，避免静默漏掉真正的
  用户任务提醒。
- Command + 数字剪贴板快捷键会先关闭已打开的预览，再恢复并粘贴目标记录，行为与
  双击、回车保持一致。
- 新增回归测试，覆盖提醒分类和剪贴板快捷键的执行顺序。

全部受支持的桌面安装包都通过 GitHub 正式版 `latest` 通道发布。

---

# DingDong 1.5.2

DingDong 1.5.2 elimina dos interrupciones intermitentes: las tareas internas
efímeras de Codex ya no aparecen como avisos del usuario al desaparecer, y el
pegado rápido con Command y un número sigue ahora la misma ruta fiable que el
doble clic y Retorno.

## Actividad más silenciosa y pegado rápido fiable

- Las tareas efímeras de Codex que devuelven exactamente `thread not loaded`
  se clasifican como actividad de fondo no persistida. Otros fallos de App
  Server siguen abiertos para no ocultar avisos reales del usuario.
- Los atajos de Command y número cierran primero la vista previa y después
  restauran y pegan el elemento, igual que el doble clic y Retorno.
- Las pruebas de regresión protegen la clasificación de avisos y el orden de
  ejecución de los atajos del portapapeles.

Todos los paquetes de escritorio compatibles se publican mediante el canal
estable `latest` de GitHub.

---

# DingDong 1.5.1

DingDong 1.5.1 restores update discovery for installed 1.4.6 clients. The
public release feed is backward-compatible again while newer clients keep
localized release notes.

## Keep installed clients on the update path

- The public `notes` field remains an English array that DingDong 1.4.6 and
  1.5.0 can decode safely.
- Localized notes move to the additive `notesByLanguage` field. DingDong 1.5.1
  accepts the legacy array, the 1.5.0 localized object, and the new split
  schema.
- Regression tests now enforce the 1.4.6 metadata contract so future feed
  changes cannot silently strand installed clients.

All supported desktop packages are published through GitHub's stable `latest`
channel.

---

# DingDong 1.5.1

DingDong 1.5.1 恢复已安装 1.4.6 客户端的更新检查。公开发布元数据重新保持向后
兼容，同时让新客户端继续显示多语言更新日志。

## 让旧客户端继续留在更新通道上

- 公开 `notes` 字段保留为英文数组，让 DingDong 1.4.6 和 1.5.0 都能安全解析。
- 多语言日志移到新增的 `notesByLanguage` 字段。DingDong 1.5.1 同时兼容旧数组、
  1.5.0 的多语言对象和新的拆分结构。
- 新增 1.4.6 元数据契约回归测试，防止未来调整再次让已安装客户端无法更新。

全部受支持的桌面安装包都通过 GitHub 正式版 `latest` 通道发布。

---

# DingDong 1.5.1

DingDong 1.5.1 restaura la búsqueda de actualizaciones para los clientes 1.4.6
instalados. Los metadatos públicos vuelven a ser compatibles y los clientes
nuevos conservan las notas localizadas.

## Mantener los clientes instalados en el canal de actualización

- El campo público `notes` sigue siendo una lista en inglés que DingDong 1.4.6
  y 1.5.0 pueden decodificar de forma segura.
- Las notas localizadas pasan al campo adicional `notesByLanguage`. DingDong
  1.5.1 acepta la lista antigua, el objeto localizado de 1.5.0 y el nuevo
  esquema dividido.
- Las pruebas de regresión protegen el contrato de metadatos de 1.4.6 para que
  futuros cambios no aíslen a clientes instalados.

Todos los paquetes de escritorio compatibles se publican mediante el canal
estable `latest` de GitHub.

---

# DingDong 1.5.0

DingDong 1.5.0 makes Agent resource use visible, adds exact conversation
Token totals where client evidence supports them, and moves the desktop app to
a centralized English, Simplified Chinese, and Spanish localization system.

## See what Prompts, Skills, and MCPs actually did

- Resource cards and configuration details show separate candidate, loaded,
  and real-call counts instead of combining availability with confirmed use.
- The Dynamic view explains repeated `×N` reminders and cumulative Token use
  on hover. Truncated summary cards also reveal their complete text on hover.
- Exact conversation Token totals are enabled by default for supported Codex,
  Claude Code, and Pi sessions. Unsupported or unverifiable clients are omitted
  instead of estimated.

## Let Agents configure DingDong safely

- A concise “connect DingDong to the current Agent” instruction replaces the
  older client-by-client setup prompt.
- Managed tools can search, create, update, and scope Prompt and MCP resources;
  complete Skills continue through their dedicated package installation flow.
- Strict parsing, atomic writes, project identity checks, and recoverable
  transactions protect managed Prompt, Skill, MCP, scope, and trigger changes.

## Use the app in three languages with less overhead

- User-facing Flutter copy is centralized and generated for English,
  Simplified Chinese, and Spanish, including native macOS windows, tray menus,
  permission dialogs, setup text, and language-aware update notes.
- Settings can open DingDong-managed data and image-cache locations; clearing
  only removes DingDong's own cache and never deletes external source files.
- SQL-side aggregation, count queries, and bounded conversation-log scans lower
  transient memory use on large histories while preserving exact results.
- The website and mobile PWA now demonstrate Token usage, Agent-managed
  resources, and the 1.5.0 stable download channel. The PWA shell advances to 28.

All supported desktop packages are published through GitHub's stable `latest`
channel.

---

# DingDong 1.5.0

DingDong 1.5.0 让 Agent 资源的真实使用过程可见，在客户端证据可靠时展示
精确会话 Token 总量，并把桌面端迁移到统一管理的英语、简体中文与西班牙语架构。

## 看清 Prompt、Skill 与 MCP 真的做了什么

- 资源卡片和配置详情分别展示候选、加载与真实调用次数，不再把“可用”和“已使用”
  混在一起。
- 动态页悬停说明 `×N` 重复提醒次数与累计 Token 用量；被省略的顶部摘要也可悬停
  查看完整内容。
- Codex、Claude Code 与 Pi 的已支持会话默认显示准确 Token 总量；不支持或无法验证
  的客户端会省略，不进行估算。

## 让 Agent 安全配置 DingDong

- 用一句简短的“把 DingDong 接入当前 Agent”替代过去逐客户端展开的长提示词。
- 托管工具可以搜索、创建、修改 Prompt 和 MCP 并绑定作用域；完整 Skill 仍走专用
  Package 安装流程。
- 严格解析、原子写入、项目身份校验与可恢复事务共同保护 Prompt、Skill、MCP、
  作用域和触发组修改。

## 三种语言，更低运行开销

- Flutter 用户文案集中管理并生成英语、简体中文、西班牙语版本，覆盖 macOS 原生窗口、
  托盘菜单、权限弹窗、接入文案与按当前语言显示的更新日志。
- 设置可以打开 DingDong 自己的数据与图片缓存位置；清理只删除 DingDong 自有缓存，
  不会删除外部来源文件。
- SQL 聚合、COUNT 查询与有界会话日志扫描降低大历史记录下的瞬时内存占用，同时保持
  结果准确。
- 官网与手机 PWA 同步展示 Token 用量、Agent 管理资源和 1.5.0 正式版下载入口；PWA
  Shell 升级到 28。

全部受支持的桌面安装包都已通过 GitHub 正式版 `latest` 通道发布。

---

# DingDong 1.5.0

DingDong 1.5.0 hace visible el uso real de los recursos de Agent, muestra
el total exacto de Tokens cuando el cliente aporta evidencia compatible y
centraliza la interfaz en inglés, chino simplificado y español.

## Recursos observables y configuración segura

- Las tarjetas y los detalles separan candidatos, cargas y llamadas reales de
  Prompt, Skill y MCP.
- Actividad explica `×N`, el total acumulado de Tokens y el texto completo al
  pasar el puntero; Codex, Claude Code y Pi muestran datos exactos compatibles.
- Los Agents pueden buscar, crear, actualizar y limitar Prompt y MCP; los Skills
  completos conservan su flujo seguro de instalación de paquetes.

## Localización y menor uso de memoria

- Los textos de Flutter, las ventanas nativas de macOS, los menús, los permisos
  y las notas de versión siguen ahora el idioma elegido.
- Ajustes puede abrir las carpetas administradas por DingDong y limpiar solo su
  propia caché, sin borrar archivos externos.
- Las agregaciones SQL y el análisis acotado de registros reducen la memoria
  temporal en historiales grandes.
- El sitio y la PWA muestran el canal estable 1.5.0; la PWA avanza a Shell 28.

Todos los paquetes de escritorio compatibles se publican mediante el canal
estable `latest` de GitHub.

---

# DingDong 1.4.6

DingDong 1.4.6 makes managed Agent resources observable, adds exact
conversation Token usage for supported clients, and hardens global and
project-scoped configuration updates.

## See how managed resources are used

- Resource Library cards and detail views now show the evidence DingDong can
  actually observe: Prompt activation, Skill candidacy and full loading, and
  MCP candidacy and real tool calls.
- Counts and latest timestamps stay attached to each resource, so users can
  distinguish availability from confirmed loading or invocation without
  opening another management tab.

## Show exact conversation Token usage when requested

- A new setting, off by default, appends a compact exact session total to the
  DingDong reply footer for supported Codex, Claude Code, and Pi conversations.
- Repeated Agent reminders keep the compact `×N` mark; hovering it shows the
  exact reminder count and cumulative Token total. Unsupported or unverifiable
  clients are omitted instead of estimated.
- When the setting is off, DingDong does not read local conversation usage
  files.

## Make managed configuration safer

- Prompt, Skill, MCP, scope, and trigger-group persistence now uses strict JSON
  parsing, atomic compare-and-update writes, repository identity normalization,
  and a recoverable transaction journal for cross-file changes.
- Agent synchronization rejects unsafe or ambiguous paths and preserves
  unrelated user configuration during concurrent updates.
- Pi project-native Skill discovery is covered by a real client integration
  test, while unsupported MCP and Bridge capabilities remain explicitly
  disabled.

Intel macOS and Windows packages remain marked as beta.

---

# DingDong 1.4.6

DingDong 1.4.6 让受管 Agent 资源的使用证据可见，为已支持的客户端增加
精确会话 Token 用量，并加固全局与项目作用域的配置更新链路。

## 看清受管资源如何被使用

- 资源库列表与详情会展示 DingDong 能真实观测的证据：Prompt 激活、
  Skill 进入候选与完整加载、MCP 进入候选与真实工具调用。
- 次数和最近时间直接跟随资源展示，无需新开 Tab 就能分辨“可用”、
  “已加载”和“已调用”。

## 按需展示精确会话 Token

- 新增默认关闭的设置开关；开启后，Codex、Claude Code 和 Pi 的已支持会话
  会在 DingDong 回复页脚后显示紧凑的精确累计用量。
- 重复提醒继续保持简洁的 `×N`；悬停时同时展示精确提醒次数和累计
  Token。不支持或无法验证的 Agent 不会估算。
- 关闭开关时，DingDong 不读取本地会话用量文件。

## 让受管配置更安全

- Prompt、Skill、MCP、作用域与触发组的持久化现在使用严格 JSON 解析、
  原子比较更新、仓库身份归一化，以及可恢复的跨文件事务日志。
- Agent 同步会拒绝不安全或含糊路径，并在并发更新时保留无关的用户配置。
- Pi 项目原生 Skill 发现已纳入真实客户端集成测试；不支持的 MCP 和
  Bridge 能力继续明确保持关闭。

Intel macOS 与 Windows 安装包继续标记为 beta。

---

# DingDong 1.4.5

DingDong 1.4.5 gives users finer control over Agent notifications, keeps the
installed PWA and browser surfaces from competing for background notifications,
and makes desktop update discovery more reliable.

## Put Agent notifications under user control

- Settings now independently control Agent completion notifications, requests
  for user attention, and subagent activity notifications.
- Agent updates that need confirmation, a choice, or takeover are labeled as
  waiting for input in the activity feed and device notifications.

## Keep the installed PWA and browser H5 separate

- When the PWA is installed, the browser page becomes a focused launcher with
  one action to open the DingDong app; the browser surface no longer receives
  Agent notifications.
- PWA notification permission checks stay in a loading state until the
  asynchronous browser permission result settles, avoiding a transient false
  “not allowed” state during startup.

## Keep desktop release status fresh

- DingDong still checks for updates at startup and now retries in the
  background every seven hours while it is running, keeping the version dot
  synchronized with the published release metadata.

Intel macOS and Windows packages remain marked as beta.

---

# DingDong 1.4.5

DingDong 1.4.5 让 Agent 通知更可控，也让已安装的 PWA 与浏览器页面各司其职，
同时让桌面端的版本更新发现更加可靠。

## Agent 通知交给用户选择

- 设置中可以分别控制 Agent 完成提醒、需要用户处理的提醒，以及子 Agent
  活动提醒。
- 需要确认、选择或接管的 Agent 更新会在活动记录和设备通知中标记为“需要你处理”。

## 已安装 PWA 后保持浏览器页面安静

- 安装 PWA 后，浏览器页面只保留一个唤起 DingDong App 的按钮；浏览器页面不再
  接收 Agent 通知。
- PWA 启动时会先显示“检查中”，等异步权限查询稳定后再显示真实权限状态，
  不会再短暂误显示“没有权限”。

## 让桌面版本状态持续更新

- 启动时仍会立即检查更新，并在运行期间每七小时后台重试一次，让版本号旁的
  更新小圆点及时反映线上发布的版本元数据。

Intel macOS 与 Windows 安装包继续标记为 beta。

---

# DingDong 1.4.4

DingDong 1.4.4 makes the resource receipt at the end of supported Agent replies
truthful about MCP use and helps existing Agent connections pick up the new
protocol.

## Know when an MCP was actually called

- An MCP now receives `*` only after one of its configured tools reaches a
  terminal result. Availability and tool discovery alone never add the marker.
- The MCP marker means **called**, not necessarily **succeeded**. Error results
  still prove that a real call took place.
- DingDong validates each call receipt against the managed resource ID, server
  identity, Codex tool prefix, enabled state, and current project scope before
  replacing the matching footer item.
- Prompt items stay unmarked. DingDong can observe delivery, but it cannot
  reliably prove whether a model followed a Prompt semantically.

## Refresh existing Agent connections safely

- Existing installations that have already opened Agent access now show a
  revision-aware update badge and setup notice when the connection instructions
  change.
- The Agent setup panel can copy the current instructions and mark that revision
  as updated; brand-new installations start at the latest revision without a
  false warning.
- The built-in DingDong configuration Skill, managed Agent bootstrap, API
  reference, website, and bilingual READMEs now describe the same Skill-load and
  MCP-call evidence rules.

Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.4.4 让支持的 Agent 在回复末尾留下的资源小票可以真实反映 MCP 调用，
并帮助已有 Agent 连接及时拿到新协议。

## MCP 真实调用后才加星号

- MCP 只有在其已配置工具拿到最终结果后才会带 `*`；仅仅可用、列出工具或发现工具
  都不会加星号。
- MCP 的 `*` 表示“调用过”，不表示“调用成功”；错误结果仍然能证明真实调用发生过。
- DingDong 会按托管资源 ID、Server 身份、Codex 工具前缀、启用状态与当前项目作用域
  校验调用回执，再替换资源小票中的对应条目。
- Prompt 继续不加 `*`：系统可以观察到送达，却无法可靠证明模型在语义上真正遵循。

## 安全刷新已有 Agent 接入

- 已经打开过 Agent 接入的旧安装会在接入协议升级时看到版本化更新角标与提示；全新
  安装直接采用最新版，不会产生误提醒。
- Agent 接入面板可复制最新指令并标记该版本已更新。
- 内置 DingDong 配置 Skill、托管 Agent 引导、API 文档、官网与中英文 README 统一
  使用相同的 Skill 加载和 MCP 调用证据规则。

Intel macOS 与 Windows 安装包继续标记为 beta。
