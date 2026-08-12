# DingDong 1.4.0

DingDong 1.4.0 makes complete Agent Skill packages a first-class managed
resource. Each Agent can now use one explicit delivery plane—dynamic, native
global, or native project—while DingDong preserves ownership, scope, and
recovery guarantees. This release also brings a denser, calmer desktop resource
workflow and adds built-in native Skill targets for Grok Build and Pi.

## Complete Skill delivery

- Choose delivery independently for every supported Agent. Dynamic Skills load
  on demand through DingDong Bridge; native global Skills are copied to the
  Agent's user directory; native project Skills are copied only into selected,
  exact project directories.
- Native delivery copies the complete package, including scripts, references,
  assets, Agent metadata, and executable permissions. Receipt-based ownership,
  package digests, atomic staging, crash recovery, and drift detection prevent
  DingDong from overwriting or deleting user-owned content.
- Catalog and full-load resolution now share one fail-closed policy. Native
  transitions, uncertain remnants, and different artifacts with the same Skill
  name are withheld instead of being exposed twice through dynamic delivery.
- The legacy MCP Apps conversation-footer renderer and footer resources have
  been removed. Hosts now consume the Bridge-provided single-line Markdown,
  ANSI, or fallback presentation directly, eliminating a redundant tool and
  resource round trip.
- Resource Manager explains project-native delivery beside the control and
  opens the exact-project selector in place. Agents that are not installed stay
  folded by default, while any unavailable Agent with an existing configuration
  remains visible so it can be safely returned to dynamic delivery.
- Codex project-native Impeccable can optionally install its project Hook. Hook
  ownership is independent from Skill delivery, definitions from every loaded
  source are inventoried for duplicates, and Codex still requires the user to
  review the current definition in `/hooks`.

## More native Agent targets

- Grok Build and Pi join the built-in Agent Adapter catalog with their dedicated
  native global and project Skill directories.
- Their native Skill support is intentionally independent from DingDong Bridge:
  neither Adapter claims an MCP or Prompt integration that the Agent does not
  natively provide. Custom home-directory and Pi trust limitations are stated
  in the Adapter guide.

## Desktop resource workflow

- Resource Manager uses a quieter continuous-list workspace, responsive
  columns, compact filters, full-page editing, bulk actions, and guarded
  navigation when an editor contains unsaved changes.
- Clipboard categories now open in Resource Manager instead of stacking another
  editor over the compact popup. Clipboard rows expose focused detail views with
  complete metadata, source, groups, and copy actions.
- Device connection, shared dialogs, buttons, choices, disclosures, switches,
  permission guidance, and light/dark surfaces have been unified around the new
  compact desktop design system, with updated keyboard and visual-regression
  coverage.

Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.4.0 将完整的 Agent Skill 包提升为一等受管资源。现在，每个 Agent
都可以明确选择一种交付方式——动态、原生全局或原生项目——同时 DingDong 会持续
保证所有权、作用域与故障恢复安全。本版本还带来了更紧凑、更安静的桌面资源工作流，
并为 Grok Build 与 Pi 增加了内置原生 Skill 交付目标。

## 完整 Skill 交付

- 可以为每个受支持 Agent 独立选择交付方式。动态 Skill 通过 DingDong Bridge
  按需加载；原生全局会复制到 Agent 用户目录；原生项目只会复制到选中的精确项目
  目录。
- 原生交付会复制完整包，包括脚本、引用、资产、Agent 元数据和可执行权限。基于
  receipt 的所有权、包摘要、原子暂存、崩溃恢复与漂移检测，可避免 DingDong 覆盖
  或删除用户自有内容。
- Skill 目录与全文加载现在共用同一套 fail-closed 仲裁。原生切换中的不确定残留、
  以及同名但内容不同的包都会被抑制，不会再与动态交付重复暴露。
- 旧的 MCP Apps 对话页脚渲染工具与页脚资源已移除。Host 现在直接使用 Bridge
  返回的单行 Markdown、ANSI 或 fallback 呈现，不再需要额外的工具和资源往返。
- 资源管理会在交付控件旁直接解释“原生项目”，并就地打开精确项目选择器。未安装
  Agent 默认折叠；如果某个已配置 Agent 后来不可用，它仍会保持可见，以便安全切回
  动态交付。
- Codex 的 Impeccable 项目原生模式可以单独启用项目 Hook。Hook 所有权与 Skill
  交付彼此独立，DingDong 会盘点所有加载来源中的重复定义，而 Codex 仍要求用户在
  `/hooks` 中审查当前定义。

## 更多原生 Agent 目标

- Grok Build 与 Pi 加入内置 Agent Adapter 目录，并使用各自独立的原生全局与项目
  Skill 目录。
- 两者的原生 Skill 支持不会冒充 DingDong Bridge：在 Agent 没有对应原生能力时，
  Adapter 不会虚构 MCP 或 Prompt 集成。自定义主目录与 Pi 项目信任等边界已写入
  Adapter 指南。

## 桌面资源工作流

- 资源管理改为更安静的连续列表工作区，提供响应式列、紧凑筛选、完整页面编辑、
  批量操作，以及编辑内容未保存时的离开保护。
- 剪贴板分类现在会在资源管理中打开，不再叠加到紧凑弹窗上；剪贴板条目提供聚焦的
  详情视图，完整呈现元数据、来源、分组与复制操作。
- 设备连接、通用对话框、按钮、选择控件、折叠控件、开关、权限引导以及明暗表面，
  已统一到新的紧凑桌面设计系统，并补齐键盘与视觉回归覆盖。

Intel macOS 与 Windows 安装包继续标记为 beta。
