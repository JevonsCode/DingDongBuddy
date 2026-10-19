import 'package:dingdong_link_protocol/dingdong_link_protocol.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'companion_controller.dart';
import 'tokens.dart';
import 'widgets.dart';

/// `#pairing-link-dialog`.
Future<String?> showPasteLinkDialog(BuildContext context) async {
  final TextEditingController input = TextEditingController();
  final ClipboardData? clip = await Clipboard.getData(Clipboard.kTextPlain);
  if (clip?.text?.contains('#pair=') == true) input.text = clip!.text!.trim();
  if (!context.mounted) return null;
  String? error;
  final String? result = await showDingDialog<String>(
    context,
    title: '粘贴连接链接',
    children: (BuildContext context) {
      final DingTokens t = DingTokens.of(context);
      return <Widget>[
        StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: 14),
              Text(
                '在电脑 DingDong 的“连接设备”里生成手机二维码，点“复制连接链接”，'
                '把链接发到手机，再粘贴到这里。',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.55,
                  color: t.textSecondary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '连接链接',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: t.textSecondary,
                ),
              ),
              const SizedBox(height: 7),
              DingTextField(
                controller: input,
                hint: 'https://…/app/#pair=…',
                keyboardType: TextInputType.url,
              ),
              if (error != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(error!, style: TextStyle(fontSize: 13, color: t.danger)),
              ],
              DialogActions(
                children: <Widget>[
                  DingButton(
                    label: '取消',
                    style: DingButtonStyle.quiet,
                    expand: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  DingButton(
                    label: '连接',
                    expand: true,
                    onPressed: () {
                      final String text = input.text.trim();
                      try {
                        DevicePairingPayload.parseInput(text);
                        Navigator.of(context).pop(text);
                      } on Object {
                        setState(() => error = '这不是有效的 DingDong 连接链接，请重新复制。');
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ];
    },
  );
  input.dispose();
  return result;
}

/// `#device-switcher-dialog`.
Future<void> showDeviceSwitcher(
  BuildContext context,
  CompanionController controller, {
  required VoidCallback onPaste,
  required VoidCallback onScan,
}) {
  final int online = controller.computers
      .where((ComputerView c) => c.connected)
      .length;
  return showDingDialog<void>(
    context,
    eyebrow: '连接的电脑',
    title: '选择当前设备',
    summary: '$online 台在线 · 共 ${controller.computers.length} 台电脑',
    children: (BuildContext context) {
      final DingTokens t = DingTokens.of(context);
      return <Widget>[
        Container(
          margin: const EdgeInsets.fromLTRB(1, 14, 1, 10),
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          decoration: BoxDecoration(
            color: t.accentSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '通过端到端加密中继连接电脑。中继不保存剪贴板、文件或 Agent 内容。',
            style: TextStyle(fontSize: 10, height: 1.55, color: t.accent),
          ),
        ),
        for (final ComputerView computer in controller.computers) ...<Widget>[
          _SwitcherItem(
            computer: computer,
            active: computer.room == controller.active?.room,
            onTap: () {
              controller.select(computer.room);
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 7),
        ],
        const SizedBox(height: 5),
        Text(
          '添加电脑：在另一台电脑的 DingDong“连接设备”中打开二维码。新设备会加入列表，不会替换现有设备。',
          style: TextStyle(fontSize: 10, height: 1.55, color: t.textSecondary),
        ),
        DialogActions(
          children: <Widget>[
            DingButton(
              label: '粘贴链接',
              style: DingButtonStyle.quiet,
              expand: true,
              onPressed: () {
                Navigator.of(context).pop();
                onPaste();
              },
            ),
            DingButton(
              label: '扫码添加',
              expand: true,
              onPressed: () {
                Navigator.of(context).pop();
                onScan();
              },
            ),
          ],
        ),
      ];
    },
  );
}

class _SwitcherItem extends StatelessWidget {
  const _SwitcherItem({
    required this.computer,
    required this.active,
    required this.onTap,
  });

  final ComputerView computer;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    final String status = computer.connected
        ? '在线 · 端到端加密中继'
        : computer.connecting
        ? '连接中'
        : computer.replaced
        ? '已在其他地方连接'
        : '离线';
    return Material(
      color: active ? t.accentSoft : t.surfaceSoft,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(11),
        side: BorderSide(color: active ? t.accentBorder : t.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
          child: Row(
            children: <Widget>[
              const DingSymbol(
                'assets/symbols/manage.png',
                size: 24,
                opacity: 0.76,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      computer.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: t.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: <Widget>[
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: computer.connected
                                ? t.success
                                : t.offlineDot,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: 10,
                            color: t.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                active ? '当前' : '切换',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: t.accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `#settings-dialog`, plus the native-only rows: channel sounds, background
/// running and per-channel test reminders.
Future<void> showSettingsDialog(
  BuildContext context,
  CompanionController controller,
  ComputerView initial,
) {
  return showDingDialog<void>(
    context,
    eyebrow: '当前设备',
    title: initial.displayName,
    children: (BuildContext dialogContext) => <Widget>[
      ListenableBuilder(
        listenable: controller,
        builder: (BuildContext context, _) {
          final ComputerView computer = controller.computers.firstWhere(
            (ComputerView c) => c.room == initial.room,
            orElse: () => initial,
          );
          final bool alerts = controller.alertsEnabled;
          final bool ringing = alerts && controller.notificationsGranted;
          final String alertStatus = !alerts
              ? '已关闭 · 列表照常同步，手机不响铃'
              : controller.notificationsGranted
              ? '已开启 · 完成与需要处理分别使用独立铃声'
              : '系统通知未允许，打开开关授权';
          final String computerStatus = computer.agentNotificationsEnabled
              ? '这台电脑的 Agent 完成或需要你处理时提醒'
              : '已关闭，这台电脑不会再提醒这台手机';
          void setAlerts(String key, bool value) =>
              controller.send(<String, Object?>{'cmd': 'alerts', key: value});
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const _SectionLabel('本机 · 所有电脑'),
              SettingRow(
                title: '手机通知',
                subtitle: alertStatus,
                trailing: DingSwitch(
                  semanticLabel: '手机通知',
                  value: ringing,
                  onChanged: (bool value) {
                    if (value && !controller.notificationsGranted) {
                      controller.enableNotifications();
                    }
                    setAlerts('enabled', value);
                  },
                ),
              ),
              SettingRow(
                title: '完成时提醒',
                subtitle: 'Agent 完成一轮任务',
                trailing: DingSwitch(
                  semanticLabel: '完成时提醒',
                  value: controller.completionAlertsEnabled,
                  onChanged: ringing
                      ? (bool value) => setAlerts('completion', value)
                      : null,
                ),
              ),
              SettingRow(
                title: '需要你处理时提醒',
                subtitle: 'Agent 在等你确认或回答',
                trailing: DingSwitch(
                  semanticLabel: '需要你处理时提醒',
                  value: controller.attentionAlertsEnabled,
                  onChanged: ringing
                      ? (bool value) => setAlerts('attention', value)
                      : null,
                ),
              ),
              const _SectionLabel('这台电脑'),
              SettingRow(
                title: '接收这台电脑的提醒',
                subtitle: computerStatus,
                trailing: DingSwitch(
                  semanticLabel: '接收这台电脑的提醒',
                  value: computer.agentNotificationsEnabled,
                  onChanged: (bool value) => controller.send(<String, Object?>{
                    'cmd': 'settings',
                    'room': computer.room,
                    'agentNotificationsEnabled': value,
                  }),
                ),
              ),
              SettingRow(
                title: '提醒时震动',
                subtitle: '实际触感仍受手机系统设置控制',
                trailing: DingSwitch(
                  semanticLabel: '提醒时震动',
                  value: computer.vibrationEnabled,
                  onChanged: (bool value) => controller.send(<String, Object?>{
                    'cmd': 'settings',
                    'room': computer.room,
                    'vibrationEnabled': value,
                  }),
                ),
              ),
              SettingRow(
                title: '铃声与振动',
                subtitle: '“Agent 完成”和“Agent 需要你处理”是两个系统通知渠道，可分别设置',
                trailing: DingButton(
                  label: '设置',
                  style: DingButtonStyle.small,
                  onPressed: () => CompanionController.native
                      .invokeMethod<bool>('openNotificationSettings'),
                ),
              ),
              SettingRow(
                title: '测试提醒',
                subtitle: '在本机各发一条，检查铃声、振动和锁屏显示；不受上面的开关影响',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    DingButton(
                      label: '完成',
                      style: DingButtonStyle.small,
                      onPressed: () => controller.send(<String, Object?>{
                        'cmd': 'test',
                        'kind': 'completion',
                      }),
                    ),
                    const SizedBox(width: 6),
                    DingButton(
                      label: '需处理',
                      style: DingButtonStyle.small,
                      onPressed: () => controller.send(<String, Object?>{
                        'cmd': 'test',
                        'kind': 'attention',
                      }),
                    ),
                  ],
                ),
              ),
              SettingRow(
                title: '后台运行',
                subtitle: controller.batteryUnrestricted
                    ? '已允许后台运行${controller.isXiaomi ? '；请确认“自启动”已打开' : ''}'
                    : '可能被系统休眠，锁屏后提醒会延迟',
                trailing: DingButton(
                  label: '检查',
                  style: DingButtonStyle.small,
                  onPressed: () => showBackgroundHelp(context, controller),
                ),
              ),
              const SettingRow(
                title: '版本',
                subtitle: 'DingDong Android 0.2.0 · 原生通知',
                trailing: SizedBox.shrink(),
              ),
              DialogActions(
                children: <Widget>[
                  DingButton(
                    label: computer.manualDisconnect ? '重新连接' : '断开连接',
                    style: DingButtonStyle.quiet,
                    expand: true,
                    onPressed: () => controller.send(<String, Object?>{
                      'cmd': computer.manualDisconnect
                          ? 'reconnect'
                          : 'disconnect',
                      'room': computer.room,
                    }),
                  ),
                  DingButton(
                    label: '删除设备',
                    style: DingButtonStyle.danger,
                    expand: true,
                    onPressed: () async {
                      final bool confirmed = await _confirmDelete(
                        context,
                        computer.hostName,
                      );
                      if (!confirmed) return;
                      controller.send(<String, Object?>{
                        'cmd': 'remove',
                        'room': computer.room,
                      });
                      if (dialogContext.mounted) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ],
  );
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14, bottom: 2),
    child: Eyebrow(text),
  );
}

Future<bool> _confirmDelete(BuildContext context, String hostName) async {
  final bool? result = await showDingDialog<bool>(
    context,
    eyebrow: '连接设备',
    title: '删除这台电脑？',
    children: (BuildContext context) {
      final DingTokens t = DingTokens.of(context);
      return <Widget>[
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Image.asset(
              'assets/symbols/delete.png',
              width: 28,
              height: 28,
              color: t.danger,
              colorBlendMode: BlendMode.srcIn,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '删除“$hostName”后，手机会清除它的连接与通知设置。以后仍可重新扫描电脑上的二维码连接。',
                style: TextStyle(fontSize: 13, height: 1.55, color: t.text),
              ),
            ),
          ],
        ),
        DialogActions(
          children: <Widget>[
            DingButton(
              label: '取消',
              style: DingButtonStyle.quiet,
              expand: true,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            DingButton(
              label: '删除设备',
              style: DingButtonStyle.danger,
              expand: true,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ];
    },
  );
  return result == true;
}

/// Background-running checklist (HyperOS autostart and battery policy).
Future<void> showBackgroundHelp(
  BuildContext context,
  CompanionController controller,
) {
  return showDingDialog<void>(
    context,
    eyebrow: '后台运行',
    title: '让提醒在锁屏后也能送达',
    children: (BuildContext context) {
      final DingTokens t = DingTokens.of(context);
      Widget step(String number, String text) => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              '$number.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: t.accent,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(fontSize: 13, height: 1.55, color: t.text),
              ),
            ),
          ],
        ),
      );
      return <Widget>[
        step('1', '允许 DingDong 不受电池优化限制。'),
        if (controller.isXiaomi) ...<Widget>[
          step('2', '在“自启动管理”里打开 DingDong。'),
          step('3', '在应用详情 → 省电策略里选择“无限制”。'),
        ],
        DialogActions(
          children: <Widget>[
            DingButton(
              label: '电池优化',
              style: DingButtonStyle.quiet,
              expand: true,
              onPressed: () => CompanionController.native.invokeMethod<bool>(
                'requestBatteryExemption',
              ),
            ),
            if (controller.isXiaomi)
              DingButton(
                label: '自启动',
                expand: true,
                onPressed: () => CompanionController.native.invokeMethod<bool>(
                  'openAutostart',
                ),
              )
            else
              DingButton(
                label: '应用详情',
                expand: true,
                onPressed: () => CompanionController.native.invokeMethod<bool>(
                  'openAppDetails',
                ),
              ),
          ],
        ),
        if (controller.isXiaomi)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: DingButton(
              label: '打开省电策略',
              style: DingButtonStyle.quiet,
              expand: true,
              onPressed: () => CompanionController.native.invokeMethod<bool>(
                'openAppDetails',
              ),
            ),
          ),
      ];
    },
  );
}
