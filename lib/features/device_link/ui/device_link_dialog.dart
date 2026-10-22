import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/features/device_link/data/device_link_session.dart';
import 'package:dingdong/features/device_link/domain/device_link_management.dart';
import 'package:dingdong/features/device_link/domain/device_link_models.dart';
import 'package:dingdong/features/device_link/domain/lan_computer_management.dart';
import 'package:dingdong/features/device_link/ui/device_link_controller.dart';
import 'package:dingdong/features/device_link/ui/file_transfer_list.dart';
import 'package:dingdong/features/device_link/ui/lan_computer_pairing_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        final ColorScheme colors = Theme.of(context).colorScheme;
        return Scaffold(
          key: const Key('device-link-manager-screen'),
          backgroundColor: colors.surface,
          body: FocusTraversalGroup(
            policy: OrderedTraversalPolicy(),
            child: SingleChildScrollView(
              key: const Key('device-link-manager-scroll-view'),
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      _WorkspaceHeader(controller: controller),
                      const SizedBox(height: 18),
                      if (controller.devices.isEmpty) ...[
                        _PairingCard(controller: controller),
                        const SizedBox(height: 20),
                        _LocalDeviceCard(controller: controller),
                      ] else ...[
                        _DevicesColumn(controller: controller),
                        const SizedBox(height: 20),
                        _PairingCard(controller: controller),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({required this.controller});

  final DeviceLinkManagement controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.devices_other_rounded,
            size: 21,
            color: colors.primary,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  context.l10n.connectedDevices,
                  key: const Key('device-link-manager-title'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                controller.localDevice.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        DesktopActionButton(
          key: const Key('device-transfer-history-open'),
          label: context.l10n.fileTransferHistory,
          icon: Icons.history_rounded,
          compact: true,
          onPressed: () => unawaited(
            showDialog<void>(
              context: context,
              builder: (_) => FileTransferHistoryDialog(controller: controller),
            ),
          ),
        ),
      ],
    );
  }
}

class _DevicesColumn extends StatelessWidget {
  const _DevicesColumn({required this.controller});
  final DeviceLinkManagement controller;

  @override
  Widget build(BuildContext context) {
    final connected = controller.devices
        .where((d) => controller.isConnected(d.id))
        .toList();
    final history = controller.devices
        .where((d) => !controller.isConnected(d.id))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: context.l10n.onlineDevices,
          trailing: '${connected.length}',
        ),
        const SizedBox(height: 9),
        if (connected.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              context.l10n.noDevicesOnline,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        for (final device in connected) ...[
          _DeviceCard(
            key: ValueKey(device.id),
            controller: controller,
            device: device,
          ),
          const SizedBox(height: 9),
        ],
        if (history.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle(
            title: context.l10n.connectionHistory,
            trailing: '${history.length}',
          ),
          const SizedBox(height: 9),
          for (final device in history) ...[
            _DeviceCard(
              key: ValueKey(device.id),
              controller: controller,
              device: device,
            ),
            const SizedBox(height: 9),
          ],
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
            title: Text(context.l10n.sendToDevice),
            subtitle: Text(
              record.title.trim().isEmpty ? record.kind.name : record.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            leading: const Icon(Icons.send_to_mobile_rounded, size: 21),
            onClose: () => Navigator.pop(context),
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FileTransferList(controller: controller),
                connected.isEmpty
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(Icons.devices_other_rounded, size: 36),
                          const SizedBox(height: 12),
                          Text(
                            context.l10n.noDeviceIsOnlineConnectOneFirst,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          DesktopActionButton(
                            label: context.l10n.gotIt,
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      )
                    : ListView.separated(
                        physics: const NeverScrollableScrollPhysics(),
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
                            onPressed:
                                controller.fileTransfers.any(
                                  (transfer) =>
                                      transfer.deviceId == device.id &&
                                      transfer.itemId == record.id &&
                                      !transfer.terminal,
                                )
                                ? null
                                : () => unawaited(() async {
                                    try {
                                      await controller.shareRecord(
                                        record,
                                        device.id,
                                      );
                                      controller.clearPendingShare();
                                      if (context.mounted &&
                                          record.filePaths.isEmpty) {
                                        Navigator.pop(context, true);
                                      }
                                    } on Object catch (error) {
                                      if (!context.mounted) return;
                                      final String message;
                                      if (error
                                          is DeviceLinkTextTooLargeException) {
                                        message = context
                                            .l10n
                                            .textIsLargerThan128KiBAndWasNotSent;
                                      } else if (error
                                          is DeviceLinkFrameTooLargeException) {
                                        message = context
                                            .l10n
                                            .theEncryptedMessageIsLargerThanThe256KiBRelayLimitAndWas_3231b01c;
                                      } else if (error
                                          is DeviceLinkFileUnavailableException) {
                                        message = context
                                            .l10n
                                            .sharedFileIsNoLongerAvailable;
                                      } else if (error
                                          is DeviceLinkFileTooLargeException) {
                                        message = context
                                            .l10n
                                            .sharedFileIsLargerThan25MiB;
                                      } else {
                                        message = context
                                            .l10n
                                            .theDeviceDisconnectedBeforeSending;
                                      }
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(content: Text(message)),
                                      );
                                    }
                                  }()),
                          );
                        },
                      ),
              ],
            ),
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
      key: const Key('device-local-device'),
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.outlineVariant)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.computer_rounded,
              color: colors.onSurfaceVariant,
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
                  context.l10n.thisComputerHost,
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

class _DeviceCard extends StatefulWidget {
  const _DeviceCard({
    required this.controller,
    required this.device,
    super.key,
  });

  final DeviceLinkManagement controller;
  final LinkedDevice device;

  @override
  State<_DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<_DeviceCard> {
  bool? _expanded;
  DeviceLinkManagement get controller => widget.controller;
  LinkedDevice get device => widget.device;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final DeviceConnectionStatus status = controller.statusOf(device.id);
    final bool connected = status == DeviceConnectionStatus.connected;
    final bool connecting = status == DeviceConnectionStatus.connecting;
    final bool active = connected || connecting;
    final bool expanded = _expanded ?? connected;
    final _StatusPalette statusPalette = _statusPalette(colors, status);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        key: Key('linked-device-${device.id}'),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: colors.outlineVariant)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _deviceIcon(device.kind),
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: device.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                      children: <InlineSpan>[
                        if (device.platformLabel.isNotEmpty)
                          TextSpan(
                            text: '  ${device.platformLabel}',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              fontSize: 12,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    key: Key('device-name-${device.id}'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(
                  status: status,
                  statusKey: Key('device-status-${device.id}'),
                  palette: statusPalette,
                ),
                const SizedBox(width: 6),
                DesktopIconButton(
                  key: Key('device-connection-${device.id}'),
                  tooltip: connecting
                      ? context.l10n.stopConnecting
                      : connected
                      ? context.l10n.disconnect
                      : context.l10n.reconnect,
                  icon: Icon(
                    active ? Icons.link_off_rounded : Icons.refresh_rounded,
                  ),
                  onPressed: () => unawaited(
                    active
                        ? controller.disconnect(device.id)
                        : controller.reconnect(device.id),
                  ),
                ),
                Semantics(
                  expanded: expanded,
                  child: DesktopIconButton(
                    key: Key('device-settings-toggle-${device.id}'),
                    tooltip: context.l10n.settings,
                    selected: expanded,
                    icon: Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                    ),
                    onPressed: () => setState(() => _expanded = !expanded),
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              _DeviceSettingRow(
                key: Key('device-auto-send-${device.id}'),
                title: context.l10n.autoSendClipboard,
                subtitle: context.l10n.thisComputerName(device.name),
                semanticLabel: context.l10n
                    .autoSendClipboardFromThisComputerToName(device.name),
                value: device.autoSendClipboard,
                onChanged: (bool value) => unawaited(
                  controller.setAutoSendClipboard(device.id, value),
                ),
              ),
              if (device.kind == LinkedDeviceKind.phone)
                _DeviceSettingRow(
                  key: Key('device-agent-notifications-${device.id}'),
                  title: context.l10n.agentCompletion,
                  subtitle: device.receiveAgentNotifications
                      ? device.vibrationEnabled
                            ? context.l10n.enabledPhoneVibrationIsOn
                            : context.l10n.enabledPhoneVibrationIsOff
                      : context.l10n.completionNotificationsAreOffForThisDevice,
                  semanticLabel: context.l10n
                      .agentCompletionNotificationsForName(device.name),
                  value: device.receiveAgentNotifications,
                  onChanged: (bool value) => unawaited(
                    controller.setAgentNotifications(device.id, value),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: device.kind == LinkedDeviceKind.computer
                        ? Text(
                            context.l10n.lanComputerOnly,
                            key: Key('device-transport-${device.id}'),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: colors.onSurfaceVariant),
                          )
                        : const SizedBox.shrink(),
                  ),
                  DesktopIconButton(
                    key: Key('device-delete-${device.id}'),
                    tooltip: context.l10n.delete,
                    foregroundColor: colors.error,
                    icon: const Icon(Icons.delete_outline_rounded),
                    onPressed: () => unawaited(_confirmDelete(context)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => DesktopAlertDialog(
        title: Text(context.l10n.deleteThisDevice),
        content: Text(
          context
              .l10n
              .trustAndDirectionalSettingsWillBeRevokedPairAgainTo_f59587ea,
        ),
        actions: <Widget>[
          DesktopActionButton(
            label: context.l10n.cancel,
            onPressed: () => Navigator.pop(context, false),
          ),
          DesktopActionButton(
            label: context.l10n.delete,
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
    final Widget content = pairing == null
        ? _PairingStart(controller: controller)
        : _PairingQr(controller: controller, pairing: pairing);
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        key: const Key('device-pairing-panel'),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            content,
            if (controller.canPair || pairing != null) ...<Widget>[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              _SecurityNote(pairingVisible: pairing != null),
            ],
          ],
        ),
      ),
    );
  }
}

class _PairingStart extends StatelessWidget {
  const _PairingStart({required this.controller});

  final DeviceLinkManagement controller;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primary.withValues(alpha: 0.11),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.qr_code_2_rounded,
                size: 21,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Semantics(
                    header: true,
                    child: Text(
                      context.l10n.connectANewDevice,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    controller.canPair
                        ? context
                              .l10n
                              .createAQRCodeThenScanItWithTheDeviceYouTrust
                        : context
                              .l10n
                              .theDEVPWAEndpointIsNotConfiguredInThisBuild,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: <Widget>[
            Expanded(
              child: DesktopActionButton(
                key: const Key('device-begin-pairing'),
                label: context.l10n.showPairingQR,
                semanticLabel: context.l10n.showQRCodeToPairATrustedDevice,
                icon: Icons.qr_code_2_rounded,
                tone: DesktopActionTone.primary,
                autofocus: controller.canPair,
                onPressed: controller.canPair
                    ? () => unawaited(controller.beginPairing())
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: DesktopActionButton(
                key: const Key('device-join-computer'),
                label: context.l10n.connectAnotherComputer,
                icon: Icons.computer_rounded,
                onPressed: controller is LanComputerManagement
                    ? () => unawaited(_showComputerPairingDialog(context))
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _showComputerPairingDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) => LanComputerPairingDialog(
        controller: controller as LanComputerManagement,
      ),
    );
  }
}

class _PairingQr extends StatelessWidget {
  const _PairingQr({required this.controller, required this.pairing});

  final DeviceLinkManagement controller;
  final PendingDevicePairing pairing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final _StatusPalette statusPalette = _statusPalette(
      colors,
      controller.pairingStatus,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  context.l10n.scanToConnect,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            _StatusBadge(
              status: controller.pairingStatus,
              statusKey: const Key('device-pairing-status'),
              palette: statusPalette,
            ),
          ],
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double qrSize = constraints.maxWidth
                .clamp(184.0, 208.0)
                .toDouble();
            return Center(
              child: Semantics(
                key: const Key('device-pairing-qr'),
                image: true,
                label: context.l10n.pairingQRCodeForName(
                  controller.localDevice.name,
                ),
                child: ExcludeSemantics(
                  child: Container(
                    width: qrSize,
                    height: qrSize,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colors.outlineVariant.withValues(alpha: 0.7),
                      ),
                    ),
                    child: QrImageView(
                      data: pairing.url.toString(),
                      version: QrVersions.auto,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          context.l10n.scanWithTheDeviceYouWantToTrust,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        DesktopActionButton(
          key: const Key('device-copy-computer-link'),
          label: context.l10n.copyLinkForAnotherComputer,
          icon: Icons.copy_rounded,
          onPressed: () => unawaited(_copyPairingLink(context)),
        ),
        const SizedBox(height: 8),
        DesktopActionButton(
          key: const Key('device-cancel-pairing'),
          label: context.l10n.cancelPairing,
          semanticLabel: context.l10n.cancelDevicePairing,
          icon: Icons.close_rounded,
          onPressed: () => unawaited(controller.cancelPairing()),
        ),
      ],
    );
  }

  Future<void> _copyPairingLink(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: pairing.url.toString()));
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.pairingLinkCopied)));
  }
}

class _SecurityNote extends StatelessWidget {
  const _SecurityNote({required this.pairingVisible});

  final bool pairingVisible;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(Icons.lock_outline_rounded, size: 15, color: colors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            pairingVisible
                ? context
                      .l10n
                      .theKeyStaysInTheQRWebRTCIsPreferredTheEncryptedRelay_ca235c45
                : context
                      .l10n
                      .webrtcIsPreferredTheEndToEndEncryptedRelayFallbackStores_816753f3,
            key: const Key('device-connection-mode-note'),
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

class _DeviceSettingRow extends StatefulWidget {
  const _DeviceSettingRow({
    required this.title,
    required this.subtitle,
    required this.semanticLabel,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String subtitle;
  final String semanticLabel;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  State<_DeviceSettingRow> createState() => _DeviceSettingRowState();
}

class _DeviceSettingRowState extends State<_DeviceSettingRow> {
  late final FocusNode _focusNode;
  bool _focused = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: widget.semanticLabel);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _toggle() {
    final ValueChanged<bool>? onChanged = widget.onChanged;
    if (onChanged == null) return;
    if (!_focusNode.hasFocus) _focusNode.requestFocus();
    onChanged(!widget.value);
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool enabled = widget.onChanged != null;
    return FocusableActionDetector(
      focusNode: _focusNode,
      enabled: enabled,
      mouseCursor: enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      shortcuts: const <ShortcutActivator, Intent>{
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            _toggle();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (bool value) {
        if (_focused != value) setState(() => _focused = value);
      },
      onShowHoverHighlight: (bool value) {
        if (_hovered != value) setState(() => _hovered = value);
      },
      child: Semantics(
        container: true,
        button: true,
        enabled: enabled,
        toggled: widget.value,
        label: widget.semanticLabel,
        onTap: enabled ? _toggle : null,
        child: ExcludeSemantics(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _toggle : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: _hovered || _focused
                    ? colors.surfaceContainerHigh.withValues(alpha: 0.72)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: _focused ? colors.primary : Colors.transparent,
                  width: _focused ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.title,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: colors.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  ExcludeSemantics(
                    child: CompactSwitch(value: widget.value, onChanged: null),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.status,
    required this.statusKey,
    required this.palette,
  });

  final DeviceConnectionStatus status;
  final Key statusKey;
  final _StatusPalette palette;

  @override
  Widget build(BuildContext context) {
    final String label = _statusLabel(context, status);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          key: statusKey,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: palette.dot,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: palette.foreground,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
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

_StatusPalette _statusPalette(
  ColorScheme colors,
  DeviceConnectionStatus status,
) {
  return switch (status) {
    DeviceConnectionStatus.connected => _StatusPalette(
      foreground: colors.primary,
      background: colors.primary.withValues(alpha: 0.1),
      dot: colors.primary,
    ),
    DeviceConnectionStatus.connecting => _StatusPalette(
      foreground: colors.onTertiaryContainer,
      background: colors.tertiaryContainer,
      dot: colors.tertiary,
    ),
    DeviceConnectionStatus.error => _StatusPalette(
      foreground: colors.onErrorContainer,
      background: colors.errorContainer,
      dot: colors.error,
    ),
    DeviceConnectionStatus.disconnected => _StatusPalette(
      foreground: colors.onSurfaceVariant,
      background: colors.surfaceContainerHigh,
      dot: colors.outline,
    ),
  };
}

final class _StatusPalette {
  const _StatusPalette({
    required this.foreground,
    required this.background,
    required this.dot,
  });

  final Color foreground;
  final Color background;
  final Color dot;
}

String _statusLabel(BuildContext context, DeviceConnectionStatus status) {
  return switch (status) {
    DeviceConnectionStatus.connecting => context.l10n.connecting,
    DeviceConnectionStatus.connected => context.l10n.online,
    DeviceConnectionStatus.error => context.l10n.connectionError,
    DeviceConnectionStatus.disconnected => context.l10n.offline,
  };
}
