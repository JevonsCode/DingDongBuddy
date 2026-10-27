import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Temporary reminders keep the same shape and color with a dashed outline.
class ReminderCardBorder extends RoundedRectangleBorder {
  const ReminderCardBorder({
    required this.temporary,
    super.side,
    super.borderRadius,
  });

  final bool temporary;

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (!temporary) {
      super.paint(canvas, rect, textDirection: textDirection);
      return;
    }
    if (side.style == BorderStyle.none || side.width == 0) return;
    final path = Path()
      ..addRRect(
        borderRadius
            .resolve(textDirection)
            .toRRect(rect)
            .deflate(side.width / 2),
      );
    for (final metric in path.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 10) {
        canvas.drawPath(
          metric.extractPath(offset, math.min(offset + 6, metric.length)),
          side.toPaint(),
        );
      }
    }
  }

  @override
  ShapeBorder scale(double t) => ReminderCardBorder(
    temporary: temporary,
    side: side.scale(t),
    borderRadius: borderRadius * t,
  );
}
