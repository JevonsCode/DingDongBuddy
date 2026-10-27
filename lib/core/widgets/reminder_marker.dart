import 'dart:math' as math;
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/settings/domain/reminder_profile.dart';
import 'package:flutter/material.dart';

/// Native macOS reminder bubbles are 22-point status-bar height minus 2.
const double reminderMarkerDiameter = 20;

String reminderDescription(BuildContext context, ReminderProfile? p) {
  final strings = context.l10n;
  final name = switch (p?.id) {
    'completion' => strings.agentCompletionNotifications,
    'attention' => strings.needsYourInput2,
    _ => p?.name ?? strings.reminderDefinitionUnavailable,
  };
  final sound = switch (p?.sound) {
    'default' => strings.dingdongClassic,
    'dingSoft' => strings.dingdongSoft,
    'dingBright' => strings.dingdongBright,
    'dingCrisp' => strings.dingdongCrisp,
    'dingDeep' => strings.dingdongDeep,
    'system' => strings.systemSound,
    'muted' => strings.muted,
    'custom' => p?.customSoundPath?.split(RegExp(r'[/\\]')).last ?? 'custom',
    _ => '',
  };
  return [
    name,
    if (p?.temporary == true) strings.reminderTemporary,
    if (p?.description.isNotEmpty == true) p!.description,
    if (sound.isNotEmpty) sound,
  ].join('\n');
}

class ReminderMarker extends StatelessWidget {
  const ReminderMarker({
    this.profile,
    this.diameter = reminderMarkerDiameter,
    super.key,
  });
  final ReminderProfile? profile;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final definition = reminderDescription(context, p);
    return Tooltip(
      message: definition,
      child: Semantics(
        label: definition,
        child: CustomPaint(
          size: Size.square(diameter),
          painter: _MarkerPainter(
            color: p == null
                ? Theme.of(context).colorScheme.outlineVariant
                : Color(0xff000000 | p.color.rgbValue),
            temporary: p?.temporary ?? false,
          ),
        ),
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  const _MarkerPainter({required this.color, required this.temporary});
  final Color color;
  final bool temporary;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 0.75;
    canvas.drawCircle(center, radius, Paint()..color = color);
    if (temporary) {
      final paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      final rect = Rect.fromCircle(center: center, radius: radius - 0.5);
      for (var i = 0; i < 10; i++) {
        canvas.drawArc(rect, i * math.pi / 5, math.pi / 8, false, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_MarkerPainter oldDelegate) =>
      color != oldDelegate.color || temporary != oldDelegate.temporary;
}
