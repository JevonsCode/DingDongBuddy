import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:flutter/material.dart';

/// First-run consent for install and upgrade statistics only.
final class LifecycleTelemetryConsentDialog extends StatelessWidget {
  const LifecycleTelemetryConsentDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return DesktopAlertDialog(
      key: const Key('lifecycle-telemetry-consent-dialog'),
      title: Text(
        context.localized(
          'Share anonymous install and upgrade statistics?',
          '允许发送匿名安装与升级统计？',
        ),
      ),
      content: Text(
        context.localized(
          'DingDong sends one event after a successful first launch or version upgrade. It includes a random installation ID, app version, operating system, and architecture. It never includes clipboard content, files, Agent messages, activity, or feature usage. You can turn this off in Settings at any time.',
          'DingDong 只会在首次成功启动或版本升级成功后发送一次事件，内容仅包含随机安装 ID、应用版本、操作系统和架构。不会发送剪贴板内容、文件、Agent 消息、活跃状态或功能使用情况。你可以随时在设置中关闭。',
        ),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      actions: <Widget>[
        DesktopActionButton(
          key: const Key('lifecycle-telemetry-decline'),
          onPressed: () => Navigator.of(context).pop(false),
          label: context.localized("Don't send", '不发送'),
          tone: DesktopActionTone.neutral,
        ),
        DesktopActionButton(
          key: const Key('lifecycle-telemetry-allow'),
          onPressed: () => Navigator.of(context).pop(true),
          label: context.localized('Allow', '允许'),
          tone: DesktopActionTone.primary,
        ),
      ],
    );
  }
}
