import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/activity/ui/activity_repeat_count.dart';
import 'package:flutter/material.dart';

const Color clipboardCopyCountColor = Color(0xFF63B3E8);

/// Clipboard capture metadata using the same watermark language as Dynamic.
class ClipboardCopyCount extends StatelessWidget {
  const ClipboardCopyCount({
    required this.recordId,
    required this.count,
    this.fontSize = activityRepeatCountFontSize,
    super.key,
  });

  final String recordId;
  final int count;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.localized('Copied $count times', '已复制 $count 次'),
      child: ActivityRepeatCount(
        key: Key('clipboard-copy-count-$recordId'),
        count: count,
        foregroundColor: clipboardCopyCountColor.withValues(alpha: 0.78),
        fontSize: fontSize,
      ),
    );
  }
}
