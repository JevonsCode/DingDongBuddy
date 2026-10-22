import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/features/device_link/domain/device_link_management.dart';
import 'package:dingdong/features/device_link/domain/file_transfer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class FileTransferList extends StatelessWidget {
  const FileTransferList({
    super.key,
    required this.controller,
    this.showHistory = false,
  });
  final bool showHistory;
  final DeviceLinkManagement controller;

  @override
  Widget build(BuildContext context) {
    final manager = controller;
    if (manager is! FileTransferManagement) return const SizedBox.shrink();
    final transfers = (manager as FileTransferManagement).fileTransfers;
    if (transfers.isEmpty) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    final active = transfers.where((view) => !view.terminal);
    final completed = transfers.where((view) => view.terminal).toList()
      ..sort(
        (a, b) => (b.finishedAt ?? b.createdAt).compareTo(
          a.finishedAt ?? a.createdAt,
        ),
      );
    final visible = [...active, if (showHistory) ...completed];
    if (visible.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!showHistory) ...[
          Text(
            context.l10n.fileTransfers,
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
        ],
        for (final view in visible)
          Container(
            key: ValueKey((view.deviceId, view.sending, view.id)),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.outlineVariant)),
            ),
            child: _TransferRow(
              view: view,
              controller: controller,
              manager: manager as FileTransferManagement,
            ),
          ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class FileTransferHistoryDialog extends StatelessWidget {
  const FileTransferHistoryDialog({required this.controller, super.key});
  final DeviceLinkManagement controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final manager = controller;
      final empty =
          manager is! FileTransferManagement ||
          (manager as FileTransferManagement).fileTransfers.isEmpty;
      return DesktopDialogFrame(
        dialogKey: const Key('device-transfer-history-dialog'),
        width: 620,
        maxHeight: 660,
        header: DesktopDialogHeader(
          title: Text(context.l10n.fileTransferHistory),
          leading: const Icon(Icons.history_rounded, size: 21),
          onClose: () => Navigator.pop(context),
        ),
        body: SingleChildScrollView(
          child: empty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Text(context.l10n.noFileTransferHistory),
                  ),
                )
              : FileTransferList(controller: controller, showHistory: true),
        ),
      );
    },
  );
}

class _TransferRow extends StatelessWidget {
  const _TransferRow({
    required this.view,
    required this.controller,
    required this.manager,
  });
  final FileTransfer view;
  final DeviceLinkManagement controller;
  final FileTransferManagement manager;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final strings = context.l10n;
    final device =
        view.deviceName ??
        controller.devices
            .where((device) => device.id == view.deviceId)
            .firstOrNull
            ?.name ??
        view.deviceId;
    final paused = const ['paused', 'waiting', 'failed'].contains(view.status);
    final direction = view.sending
        ? strings.transferSendingTo(device)
        : strings.transferReceivingFrom(device);
    final status = view.detail.isEmpty
        ? strings.fileTransferStatus(view.status)
        : strings.fileTransferIssue(view.detail);
    final speed = view.status == 'transferring' && view.bytesPerSecond > 0
        ? ' · ${_bytes(view.bytesPerSecond.round())}/s'
        : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              view.sending
                  ? Icons.upload_file_outlined
                  : Icons.download_outlined,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                view.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              view.terminal ? status : '${(view.progress * 100).floor()}%',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          view.terminal
              ? '$direction · ${_bytes(view.size)}'
              : '$direction · ${_bytes(view.bytes)} / ${_bytes(view.size)}$speed',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          DateFormat.yMd(
            Localizations.localeOf(context).toLanguageTag(),
          ).add_Hm().format((view.finishedAt ?? view.createdAt).toLocal()),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        if (!view.terminal) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: view.progress,
            minHeight: 4,
            borderRadius: BorderRadius.circular(4),
            color: paused ? colors.onSurfaceVariant : colors.primary,
            semanticsLabel: view.name,
            semanticsValue: '${(view.progress * 100).floor()}%',
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Text(
                    status,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              if (!view.terminal) ...[
                DesktopActionButton(
                  compact: true,
                  style: DesktopActionButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    side: BorderSide.none,
                    foregroundColor: colors.primary,
                  ),
                  onPressed: () => manager.controlFileTransfer(
                    view.id,
                    view.deviceId,
                    paused ? 'resume' : 'pause',
                  ),
                  child: Text(
                    paused ? strings.resumeTransfer : strings.pauseTransfer,
                  ),
                ),
                const SizedBox(width: 4),
                DesktopActionButton(
                  compact: true,
                  style: DesktopActionButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    side: BorderSide.none,
                    foregroundColor: colors.primary,
                  ),
                  onPressed: () => manager.controlFileTransfer(
                    view.id,
                    view.deviceId,
                    'cancel',
                  ),
                  child: Text(strings.cancelTransfer),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

String _bytes(int value) {
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var bytes = value.toDouble();
  var unit = 0;
  while (bytes >= 1024 && unit < units.length - 1) {
    bytes /= 1024;
    unit++;
  }
  return '${bytes.toStringAsFixed(unit == 0 || bytes >= 100 ? 0 : 1)} ${units[unit]}';
}
