import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import 'companion_controller.dart';
import 'formatters.dart';
import 'tokens.dart';
import 'widgets.dart';

/// "收到的内容": items the computer shared (`.clipboard-card`).
class ClipboardPanel extends StatelessWidget {
  const ClipboardPanel({
    super.key,
    required this.controller,
    required this.computer,
  });

  final CompanionController controller;
  final ComputerView computer;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    final List<Map<String, Object?>> items = computer.items;
    final Set<String> pending = computer.pendingFiles;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: <Widget>[
        SectionHeading(
          title: '收到的内容',
          trailing: Text(
            computer.lastSyncAt == null
                ? '尚未同步'
                : formatTime(computer.lastSyncAt),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: t.textSecondary,
            ),
          ),
        ),
        if (items.isEmpty)
          const ListEmpty(
            image: 'assets/symbols/clipboard.png',
            title: '列表还是空的',
            body: '只有电脑主动发送，或为此设备开启自动发送后，新内容才会出现在这里。',
          )
        else
          for (final Map<String, Object?> item in items) ...<Widget>[
            _ClipboardCard(
              item: item,
              hostName: computer.hostName,
              showHostName: controller.computers.length > 1,
              connected: computer.connected,
              pending: pending.contains(item['id']),
              onCopy: () => controller.copyItem(item['id']! as String),
              onDownload: () => controller.sendForActive(
                'requestFile',
                <String, Object?>{'itemId': item['id']},
              ),
            ),
            const SizedBox(height: 9),
          ],
      ],
    );
  }
}

class _ClipboardCard extends StatelessWidget {
  const _ClipboardCard({
    required this.item,
    required this.hostName,
    required this.showHostName,
    required this.connected,
    required this.pending,
    required this.onCopy,
    required this.onDownload,
  });

  final Map<String, Object?> item;
  final String hostName;

  /// With several computers paired, each item names the one it came from.
  final bool showHostName;
  final bool connected;
  final bool pending;
  final VoidCallback onCopy;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    final String kind = item['kind'] as String? ?? 'text';
    final String? fileName = item['fileName'] as String?;
    final bool sensitive = item['sensitive'] == true;
    final String title = (item['title'] as String?)?.isNotEmpty == true
        ? item['title']! as String
        : kindLabel(kind);
    final String preview = sensitive
        ? '敏感内容未自动同步'
        : fileName != null
        ? '$fileName · ${formatBytes(item['fileSize'] as int?)}'
        : (item['preview'] as String?) ?? '内容不可用';
    final bool downloadable = item['downloadable'] != false;
    final Widget action = fileName != null
        ? _CardAction(
            label: !downloadable
                ? '过大'
                : pending
                ? '获取中…'
                : '下载',
            onPressed: downloadable && connected && !pending
                ? onDownload
                : null,
          )
        : _CardAction(
            label: '复制',
            icon: 'assets/symbols/copy.png',
            onPressed: sensitive || item['hasContent'] != true ? null : onCopy,
          );
    return Container(
      decoration: BoxDecoration(
        color: t.surface,
        border: Border.all(color: t.border),
        borderRadius: BorderRadius.circular(DingRadius.card),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: t.field,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: DingSymbol(symbolForKind(kind), opacity: 0.75),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: t.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preview,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.42,
                          color: t.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                action,
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: t.border)),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(switch (item['source']) {
                    final String source when showHostName =>
                      '$hostName · $source',
                    final String source => source,
                    _ => hostName,
                  }, style: TextStyle(fontSize: 10, color: t.textSecondary)),
                ),
                Text(
                  formatTime(parseDate(item['updatedAt'])),
                  style: TextStyle(fontSize: 10, color: t.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// `.card-copy`: the accent action on a clipboard card.
class _CardAction extends StatelessWidget {
  const _CardAction({required this.label, required this.onPressed, this.icon});

  final String label;
  final String? icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    final bool enabled = onPressed != null;
    final Color foreground = enabled ? t.onAccent : t.textSecondary;
    return Material(
      color: enabled ? t.accent : t.field,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onPressed,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Image.asset(
                  icon!,
                  width: 15,
                  height: 15,
                  color: foreground,
                  colorBlendMode: BlendMode.srcIn,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.section-heading`.
class SectionHeading extends StatelessWidget {
  const SectionHeading({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 0, 2, 11),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 19,
                  height: 1.25,
                  letterSpacing: -0.35,
                  fontWeight: FontWeight.w700,
                  color: t.text,
                ),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// `.list-empty`: dashed placeholder with a mascot or symbol.
class ListEmpty extends StatelessWidget {
  const ListEmpty({
    super.key,
    required this.image,
    required this.title,
    required this.body,
    this.compact = false,
  });

  final String image;
  final String title;
  final String body;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    return CustomPaint(
      painter: _DashedBorder(color: t.border, radius: DingRadius.card),
      child: Container(
        constraints: BoxConstraints(minHeight: compact ? 142 : 220),
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (image.contains('/symbols/'))
              DingSymbol(image, size: compact ? 42 : 52, opacity: 0.75)
            else
              DingMascot(image, size: compact ? 42 : 52),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: t.text,
              ),
            ),
            const SizedBox(height: 5),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: Text(
                body,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: t.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedBorder extends CustomPainter {
  const _DashedBorder({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final Path path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ).deflate(0.5),
      );
    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 4), paint);
        distance += 7;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorder old) =>
      old.color != color || old.radius != radius;
}
