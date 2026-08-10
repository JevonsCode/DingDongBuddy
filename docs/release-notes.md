# DingDong 1.3.3

DingDong 1.3.3 makes update checks more resilient and keeps the menu-bar buddy
legible across macOS light and dark appearances.

## More resilient update checks

- Desktop update checks now try the release metadata mirrored by DingDong's
  Cloudflare Worker first, then continue through the existing website and
  GitHub fallbacks when a source is unavailable.
- The Worker publishes the same `dingdong-release.json` used by the website and
  serves it with a no-cache policy so a newly deployed version can be discovered
  without waiting for stale metadata to expire.
- The extra source improves fallback coverage but does not guarantee
  reachability on every network or in every region.

## Adaptive macOS menu-bar contrast

- Normal, resting, and sleeping menu-bar states now select their `-w` or
  non-`-w` artwork from the current macOS appearance.
- Changing the system appearance refreshes the tray artwork immediately without
  restarting DingDong.
- Reminder states keep their white artwork over the colored reminder background,
  including the alternate animation frame.

Intel macOS and Windows packages remain marked as beta.

---

DingDong 1.3.3 提高了更新检查的容错能力，并让菜单栏伙伴在 macOS 浅色与深色
外观下都保持清晰可见。

## 更新检查更可靠

- 桌面端检查更新时会优先读取 DingDong Cloudflare Worker 上的发布元数据；该来源
  不可用时，仍会继续尝试原有官网与 GitHub 备用地址。
- Worker 与官网发布同一份 `dingdong-release.json`，并使用不缓存策略，减少新版本
  部署后仍读到旧元数据的情况。
- 新增来源可以提高兜底覆盖，但无法保证所有网络或地区都一定可访问。

## macOS 菜单栏自动适配明暗外观

- 普通、休息和睡眠状态会根据当前 macOS 外观选择 `-w` 或无 `-w` 的图标资源。
- 切换系统外观时，托盘图标会立即刷新，不需要重启 DingDong。
- 提醒状态有彩色背景，因此继续使用白色图标，包括第二帧动画。

Intel macOS 与 Windows 安装包继续标记为 beta。
