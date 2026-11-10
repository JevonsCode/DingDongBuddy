import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Temporary reminders keep the same shape and color with a dashed outline.
/// A [gradient] replaces the side color when a card carries several reminders.
class ReminderCardBorder extends RoundedRectangleBorder {
  const ReminderCardBorder({
    required this.temporary,
    this.gradient,
    super.side,
    super.borderRadius,
  });

  final bool temporary;
  final Gradient? gradient;

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (!temporary && gradient == null) {
      super.paint(canvas, rect, textDirection: textDirection);
      return;
    }
    if (side.style == BorderStyle.none || side.width == 0) return;
    final paint = side.toPaint();
    if (gradient != null) {
      paint.shader = gradient!.createShader(rect, textDirection: textDirection);
    }
    final rrect = borderRadius
        .resolve(textDirection)
        .toRRect(rect)
        .deflate(side.width / 2);
    if (!temporary) {
      canvas.drawRRect(rrect, paint);
      return;
    }
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 10) {
        canvas.drawPath(
          metric.extractPath(offset, math.min(offset + 6, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  ShapeBorder scale(double t) => ReminderCardBorder(
    temporary: temporary,
    gradient: gradient?.scale(t),
    side: side.scale(t),
    borderRadius: borderRadius * t,
  );

  // The inherited equality ignores these fields, which would skip repaints.
  @override
  bool operator ==(Object other) =>
      other is ReminderCardBorder &&
      other.temporary == temporary &&
      other.gradient == gradient &&
      other.side == side &&
      other.borderRadius == borderRadius;

  @override
  int get hashCode => Object.hash(temporary, gradient, side, borderRadius);
}
