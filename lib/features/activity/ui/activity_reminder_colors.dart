import 'package:dingdong/features/activity/domain/agent_activity.dart';
import 'package:flutter/material.dart';

/// Reminder colors of one conversation, in the order they first arrived.
List<Color> activityReminderColors(AgentActivity activity) => <Color>[
  for (final color in activity.reminderColors)
    Color(0xff000000 | color.rgbValue),
];

/// Evenly spaced left-to-right blend, or null for a single color.
LinearGradient? activityReminderGradient(
  List<Color> colors, {
  Alignment begin = Alignment.centerLeft,
  Alignment end = Alignment.centerRight,
}) => colors.length < 2
    ? null
    : LinearGradient(begin: begin, end: end, colors: colors);

/// Paints [child]'s opaque pixels with the conversation's reminder gradient.
class ActivityReminderTint extends StatelessWidget {
  const ActivityReminderTint({
    required this.colors,
    required this.child,
    super.key,
  });

  final List<Color> colors;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final LinearGradient? gradient = activityReminderGradient(
      colors,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    if (gradient == null) {
      return child;
    }
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: gradient.createShader,
      child: child,
    );
  }
}
