import 'package:flutter/material.dart';

/// Oversized, low-contrast repeat metadata that reads like a row watermark.
class ActivityRepeatCount extends StatelessWidget {
  const ActivityRepeatCount({
    required this.count,
    this.foregroundColor,
    this.fontSize = 28,
    this.verticalOffset = 0,
    super.key,
  });

  final int count;
  final Color? foregroundColor;
  final double fontSize;
  final double verticalOffset;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: Offset(0, verticalOffset),
      child: Text(
        count > 99 ? '99+' : '×$count',
        style: TextStyle(
          color: foregroundColor ?? colors.onSurface.withValues(alpha: 0.13),
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.8,
          height: 1,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
