import 'package:dingdong/app/app_localizations.dart';
import 'package:flutter/material.dart';

/// A small, intentionally off-edge pin used to mark archived clipboard rows.
class ClipboardPinnedIndicator extends StatelessWidget {
  const ClipboardPinnedIndicator({
    required this.recordId,
    required this.keyPrefix,
    required this.color,
    this.size = 17,
    super.key,
  });

  final String recordId;
  final String keyPrefix;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.34,
      child: Tooltip(
        message: context.localized('Pinned', '已置顶'),
        child: Icon(
          key: Key('$keyPrefix-$recordId'),
          Icons.push_pin_rounded,
          size: size,
          color: color,
        ),
      ),
    );
  }
}
