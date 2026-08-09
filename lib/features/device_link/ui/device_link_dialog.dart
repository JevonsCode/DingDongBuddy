import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/features/device_link/data/device_link_session.dart';
import 'package:dingdong/features/device_link/domain/device_link_management.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:dingdong/features/device_link/ui/device_link_controller.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Full connection-management surface hosted by its own desktop window.
final class DeviceLinkManagerScreen extends StatelessWidget {
  const DeviceLinkManagerScreen({required this.controller, super.key});

  final DeviceLinkManagement controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        return Scaffold(
          key: const Key('device-link-manager-screen'),
          backgroundColor: Theme.of(context).colorScheme.surface,
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 920),
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints bounds) {
                    final Widget devices = _DevicesColumn(
                      controller: controller,
                    );
                    final Widget pairing = _PairingCard(controller: controller);
                    if (bounds.maxWidth < 700) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          devices,
                          const SizedBox(height: 18),
                          pairing,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(flex: 5, child: devices),
                        const SizedBox(width: 20),
                        Expanded(flex: 4, child: pairing),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DevicesColumn extends StatelessWidget {
  const _DevicesColumn({required this.controller});

  final DeviceLinkManagement controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _LocalDeviceCard(controller: controller),
        const SizedBox(height: 18),
        _SectionTitle(
          title: context.localized('Your devices', '已连接设备'),
          trailing: '${controller.devices.length}',
        ),
        const SizedBox(height: 9),
        if (controller.devices.isEmpty && controller.pendingPairing == null)
          _EmptyDevicesCard(controller: controller)
        else
          for (final LinkedDevice device in controller.devices) ...<Widget>[
            _DeviceCard(controller: controller, device: device),
            const SizedBox(height: 9),
          ],
      ],
    );
  }
}

final class DeviceShareDialog extends StatelessWidget {
  const DeviceShareDialog({
    required this.controller,
    required this.record,
    super.key,
  });

  final DeviceLinkController controller;
  final ClipboardRecord record;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (BuildContext context, _) {
        final List<LinkedDevice> connected = controller.devices
            .where((LinkedDevice value) => controller.isConnected(value.id))
            .toList(growable: false);
        return DesktopDialogFrame(
          dialogKey: const Key('device-share-dialog'),
          width: 400,
          maxHeight: 520,
          header: DesktopDialogHeader(
            title: Text(context.localized('Send to device', '发送到设备')),
            subtitle: Text(
              record.title.trim().isEmpty ? record.kind.name : record.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: const Icon(Icons.send_to_mobile_rounded, size: 21),
            onClose: () => Navigator.pop(context),
          ),
          body: connected.isEmpty
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const Icon(Icons.devices_other_rounded, size: 36),
                    const SizedBox(height: 12),
                    Text(
                      context.localized(
                        'No device is online. Connect one first.',
                        '当前没有在线设备，请先连接设备。',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    DesktopActionButton(
                      label: context.localized('Got it', '知道了'),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                )
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: connected.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (BuildContext context, int index) {
                    final LinkedDevice device = connected[index];
                    return DesktopActionButton(
                      key: Key('send-to-device-${device.id}'),
                      label: device.name,
                      icon: _deviceIcon(device.kind),
                      tone: index == 0
                          ? DesktopActionTone.primary
                          : DesktopActionTone.neutral,
                      height: 44,
                      onPressed: () => unawaited(() async {
                        try {
                          await controller.shareRecord(record, device.id);
                          controller.clearPendingShare();
                          if (context.mounted) Navigator.pop(context, true);
                        } on Object catch (error) {
                          if (!context.mounted) return;
                          final String message;
                          if (error is DeviceLinkTextTooLargeException) {
                            message = context.localized(
                              'Text is larger than 128 KiB and was not sent.',
                              '文本超过 128 KiB，未发送。',
                            );
                          } else if (error
                              is DeviceLinkFrameTooLargeException) {
                            message = context.localized(
                              'The encrypted message is larger than the '
                                  '256 KiB relay limit and was not sent.',
                              '内容加密后超过 256 KiB 中继上限，未发送。',
                            );
                          } else {
                            message = context.localized(
                              'The device disconnected before sending.',
                              '发送前设备已断开。',
                            );
                          }
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(message)));
                        }
                      }()),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _LocalDeviceCard extends StatelessWidget {
  const _LocalDeviceCard({required this.controller});

  final DeviceLinkManagement controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.computer_rounded,
              color: colors.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  controller.localDevice.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  context.localized('This computer · Host', '这台电脑 · 主机'),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.controller, required this.device});

  final DeviceLinkManagement controller;
  final LinkedDevice device;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final DeviceConnectionStatus status = controller.statusOf(device.id);
    final bool connected = status == DeviceConnectionStatus.connected;
    final bool connecting = status == DeviceConnectionStatus.connecting;
    final bool active = connected || connecting;
    return Container(
      key: Key('linked-device-${device.id}'),
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 11),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(_deviceIcon(device.kind), size: 21),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      device.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _statusLabel(context, status),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: connected
                            ? const Color(0xFF238558)
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: connected
                      ? const Color(0xFF2FA66D)
                      : colors.outlineVariant,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          CompactSwitchListTile(
            title: Text(context.localized('Auto send clipboard', '自动发送剪贴板')),
            subtitle: Text(
              context.localized(
                'This computer → ${device.name}',
                '这台电脑 → ${device.name}',
              ),
            ),
            value: device.autoSendClipboard,
            onChanged: (bool value) =>
                unawaited(controller.setAutoSendClipboard(device.id, value)),
          ),
          CompactSwitchListTile(
            title: Text(context.localized('Agent completion', 'Agent 完成提醒')),
            subtitle: Text(
              device.receiveAgentNotifications
                  ? device.vibrationEnabled
                        ? context.localized(
                            'Enabled · Phone vibration is on',
                            '已开启 · 手机端震动已开',
                          )
                        : context.localized(
                            'Enabled · Phone vibration is off',
                            '已开启 · 手机端震动已关',
                          )
                  : context.localized(
                      'Completion notifications are off for this device',
                      '此设备的完成提醒已关闭',
                    ),
            ),
            value: device.receiveAgentNotifications,
            onChanged: (bool value) =>
                unawaited(controller.setAgentNotifications(device.id, value)),
          ),
          const SizedBox(height: 3),
          Row(
            children: <Widget>[
              Expanded(
                child: DesktopActionButton(
                  key: Key('device-connection-${device.id}'),
                  label: connecting
                      ? context.localized('Stop connecting', '停止连接')
                      : connected
                      ? context.localized('Disconnect', '断开连接')
                      : context.localized('Reconnect', '重新连接'),
                  icon: active ? Icons.link_off_rounded : Icons.refresh_rounded,
                  compact: true,
                  onPressed: () => unawaited(
                    active
                        ? controller.disconnect(device.id)
                        : controller.reconnect(device.id),
                  ),
                ),
              ),
              const SizedBox(width: 7),
              DesktopActionButton(
                key: Key('device-delete-${device.id}'),
                label: context.localized('Delete', '删除'),
                icon: Icons.delete_outline_rounded,
                compact: true,
                tone: DesktopActionTone.danger,
                onPressed: () => unawaited(_confirmDelete(context)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => DesktopAlertDialog(
        title: Text(context.localized('Delete this device?', '删除这个设备？')),
        content: Text(
          context.localized(
            'Trust and directional settings will be revoked. Pair again to reconnect.',
            '将撤销信任和方向设置；下次连接需要重新扫码。',
          ),
        ),
        actions: <Widget>[
          DesktopActionButton(
            label: context.localized('Cancel', '取消'),
            onPressed: () => Navigator.pop(context, false),
          ),
          DesktopActionButton(
            label: context.localized('Delete', '删除'),
            tone: DesktopActionTone.danger,
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );
    if (confirmed == true) await controller.deleteDevice(device.id);
  }
}

class _PairingCard extends StatelessWidget {
  const _PairingCard({required this.controller});

  final DeviceLinkManagement controller;

  @override
  Widget build(BuildContext context) {
    final PendingDevicePairing? pairing = controller.pendingPairing;
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: pairing == null
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  context.localized('Connect a new device', '连接新设备'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  controller.canPair
                      ? context.localized(
                          'Open the camera on your phone and scan the QR code.',
                          '用手机相机扫描二维码即可连接。',
                        )
                      : context.localized(
                          'The DEV PWA endpoint is not configured in this build.',
                          '这个构建尚未配置 DEV PWA 地址。',
                        ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (controller.canPair) ...<Widget>[
                  const SizedBox(height: 7),
                  Text(
                    context.localized(
                      'Uses a local WebRTC connection when possible, with an '
                          'end-to-end encrypted relay fallback. The relay does not '
                          'store clipboard, file, or Agent content.',
                      '优先使用局域网 WebRTC 直连；无法直连时使用端到端加密中继。'
                          '中继不保存剪贴板、文件或 Agent 内容。',
                    ),
                    key: const Key('device-connection-mode-note'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 11),
                DesktopActionButton(
                  key: const Key('device-begin-pairing'),
                  label: context.localized('Show pairing QR', '显示连接二维码'),
                  icon: Icons.qr_code_2_rounded,
                  tone: DesktopActionTone.primary,
                  onPressed: controller.canPair
                      ? () => unawaited(controller.beginPairing())
                      : null,
                ),
              ],
            )
          : Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        context.localized('Scan to connect', '扫码连接'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      _statusLabel(context, controller.pairingStatus),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: 224,
                  height: 224,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: QrImageView(
                    key: const Key('device-pairing-qr'),
                    data: pairing.url.toString(),
                    version: QrVersions.auto,
                    errorCorrectionLevel: QrErrorCorrectLevel.M,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  context.localized(
                    'The pairing key stays inside the QR fragment.',
                    '连接密钥只存在于二维码片段中。',
                  ),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  context.localized(
                    'Local WebRTC is preferred; an end-to-end encrypted relay '
                        'keeps the connection available when direct access fails.',
                    '优先局域网 WebRTC 直连；直连失败时使用端到端加密中继保持连接。',
                  ),
                  key: const Key('device-pairing-connection-mode-note'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                DesktopActionButton(
                  key: const Key('device-cancel-pairing'),
                  label: context.localized('Cancel pairing', '取消连接'),
                  onPressed: () => unawaited(controller.cancelPairing()),
                ),
              ],
            ),
    );
  }
}

class _EmptyDevicesCard extends StatelessWidget {
  const _EmptyDevicesCard({required this.controller});

  final DeviceLinkManagement controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.devices_other_rounded, size: 32),
          const SizedBox(height: 8),
          Text(
            context.localized('No connected devices yet', '还没有已连接设备'),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 3),
          Text(
            context.localized(
              'Pairing does not copy content by itself.',
              '完成连接后也不会自动复制内容。',
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.trailing});

  final String title;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(trailing, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

IconData _deviceIcon(LinkedDeviceKind kind) => switch (kind) {
  LinkedDeviceKind.computer => Icons.computer_rounded,
  LinkedDeviceKind.phone => Icons.phone_iphone_rounded,
};

String _statusLabel(BuildContext context, DeviceConnectionStatus status) {
  return switch (status) {
    DeviceConnectionStatus.connecting => context.localized(
      'Connecting…',
      '连接中…',
    ),
    DeviceConnectionStatus.connected => context.localized('Online', '在线'),
    DeviceConnectionStatus.error => context.localized(
      'Connection error',
      '连接异常',
    ),
    DeviceConnectionStatus.disconnected => context.localized('Offline', '离线'),
  };
}
