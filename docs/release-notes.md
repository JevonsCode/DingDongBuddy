# DingDong 1.3.1

DingDong 1.3.1 makes its bounded install and update statistics easier to
understand and control, while keeping the release website aligned with the
packages that were actually published.

## Install and update statistics

- Anonymous install and update statistics are enabled by default without a
  startup prompt. The disclosure and switch now live under **Settings →
  Version**, next to update controls.
- DingDong sends at most one event after installation and one after each
  version or build transition. The event contains a random installation ID,
  app/build version, operating system, architecture, event type, and time.
- It sends no sessions, heartbeats, activity, feature usage, clipboard content,
  files, or Agent messages. The Cloudflare service stores only an HMAC of the
  random installation ID and does not persist client IP addresses.
- Existing users who previously disabled the statistics remain opted out, and
  disabling the switch removes any pending retry.
- The client and Cloudflare implementation remain fully open source.

## Release reliability

- The release website now deploys only after GitHub Release packages exist and
  checks out the exact release tag while satisfying the protected Pages
  environment's main-branch policy.
- Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.3.1 让范围严格受限的安装与更新统计更容易理解和控制，并确保发布官网
始终与真正已经上传的安装包保持一致。

## 安装与更新统计

- 匿名安装与更新统计默认开启，不再显示启动询问弹窗。完整说明与开关位于
  **设置 → 版本**，和更新操作放在一起。
- DingDong 最多在安装后发送一次事件，并在每次版本或构建号变化后发送一次事件。
  字段仅包含随机安装 ID、应用与构建版本、操作系统、处理器架构、事件类型和时间。
- 不发送会话、心跳、活跃状态、功能使用、剪贴板内容、文件或 Agent 消息。
  Cloudflare 服务只保存随机安装 ID 的 HMAC，不持久化客户端 IP 地址。
- 旧用户此前已经关闭统计时会继续保持关闭；关闭开关也会删除本地待重试事件。
- 客户端与 Cloudflare 实现继续完整开源。

## 发布可靠性

- GitHub Release 安装包存在后才会部署官网；部署会检出精确发布标签，同时满足受保护
  Pages 环境只允许 `main` 分支的策略。
- Intel macOS 与 Windows 安装包继续标记为 beta。
