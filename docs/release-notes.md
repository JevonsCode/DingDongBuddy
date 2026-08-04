# DingDong 1.0.0

DingDong 1.0 turns the clipboard, Agent resource library, and completion alerts
into one cohesive desktop workflow.

## Clipboard and sharing

- Links, files, folders, and images can be opened with the operating system from
  both their content icon and the redesigned Open action.
- Eligible clipboard text and links can be shared as a QR Code. Clicking the
  rendered code opens only the artwork in a separate resizable viewer; Escape
  returns focus to the detail preview so the next Escape closes it.
- Clipboard category management, search, filters, group controls, selection
  actions, and preview buttons now share the same compact desktop visual system.
- Old legacy archive compatibility is removed; pinned and explicit custom-group
  archives remain protected from automatic retention.

## Agent activity

- Repeated activity uses a bottom-aligned ×N watermark instead of a tag. Counts
  cap at 99+, newly revealed unread activity is pale orange, and acknowledged
  history returns to low-contrast gray.
- Activity and Resource Manager rows reserve the system-open slot consistently,
  keeping repeat counts and timestamps aligned.
- The local Agent connection card now leads with the port number and labels the
  connection as API | Agent.

## Prompt, Skill, and MCP management

- A shared component foundation replaces raw platform-looking tabs, fields,
  buttons, choice chips, sliders, disclosures, icon actions, and context menus
  across the app.
- Prompt, Skill, and MCP filters, trigger groups, imports, editors, and bulk
  actions use consistent spacing and interaction states.
- Native Agent configuration synchronization detects unrelated duplicate
  entries before writing, removes stale DingDong-managed tables safely, checks
  for concurrent changes, writes atomically, and verifies the result by reading
  it back.
- Usage-count-only resource updates no longer rewrite native Agent
  configuration. Explicit saves still force synchronization when requested.

## Documentation and website

- The README is reduced to the stable product, installation, compatibility,
  shortcut, privacy, and release contracts; changing procedures link to their
  canonical guides.
- The website presents the product as a clean macOS window with all five menu
  bar alert colors, plus a visual Prompt / Skill / MCP routing guide and
  practical examples of ordinary Agent requests.

Intel macOS and Windows packages remain beta.

---

DingDong 1.0 把剪贴板、Agent 资源库和任务完成提醒整理成一套连贯的桌面工作流。

## 剪贴板与分享

- 链接、文件、文件夹和图片都可以通过内容图标或重新设计的“打开”操作交给系统打开。
- 可编码的剪贴板文本和链接可以生成二维码；点击二维码后只会在独立、可缩放的窗口中
  放大图案。按 Escape 会先回到详情预览，再按一次即可继续关闭详情。
- 剪贴板分类管理、搜索、筛选、分组、批量选择和详情操作统一使用新的桌面组件样式。
- 删除旧的历史归档兼容逻辑；置顶和明确加入自定义分组的归档内容仍不会被自动清理。

## Agent 动态

- 重复动态改为底部对齐的 ×N 水印，超过 99 次显示 99+；刚显示的未读动态使用淡橙色，
  确认后恢复为低对比灰色。
- 动态与资源管理列表会统一预留系统打开图标的位置，重复次数和时间保持竖向对齐。
- 本地 Agent 连接卡片直接显示端口号，副标题改为“API | Agent 连接”。

## Prompt、Skill 与 MCP 管理

- 新的通用组件统一了全局 Tab、输入框、按钮、选择项、滑块、折叠项、图标操作和右键菜单，
  不再混用突兀的原生外观。
- Prompt、Skill、MCP 的筛选、触发组、导入、编辑和批量操作使用一致的间距与交互状态。
- 原生 Agent 配置同步会在写入前检查无关的重复项，安全移除 DingDong 托管的旧表，
  检测并发变化，原子写入并回读验证结果。
- 只有使用次数或最近使用时间变化时不再重写原生 Agent 配置；用户明确保存时仍会强制同步。

## 文档与官网

- README 收敛为稳定的产品、安装、兼容性、快捷键、隐私和发布契约；容易变化的步骤统一链接
  到权威指南。
- 官网以干净的 macOS 窗口展示产品和五种菜单栏提醒颜色，并补充 Prompt / Skill / MCP
  分发图例和普通对话示例。

Intel macOS 与 Windows 安装包继续标记为 beta。
