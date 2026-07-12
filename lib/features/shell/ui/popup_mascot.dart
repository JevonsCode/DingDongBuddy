import 'package:flutter/material.dart';

/// Clickable DingDong mascot with a short, center-pivot desktop animation.
class PopupMascot extends StatefulWidget {
  const PopupMascot({super.key});

  @override
  State<PopupMascot> createState() => _PopupMascotState();
}

class _PopupMascotState extends State<PopupMascot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _rotation =
      TweenSequence<double>(<TweenSequenceItem<double>>[
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 0, end: -0.13),
          weight: 18,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: -0.13, end: 0.12),
          weight: 24,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 0.12, end: -0.08),
          weight: 22,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: -0.08, end: 0.05),
          weight: 18,
        ),
        TweenSequenceItem<double>(
          tween: Tween<double>(begin: 0.05, end: 0),
          weight: 18,
        ),
      ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('popup-mascot'),
      behavior: HitTestBehavior.opaque,
      onTap: () => _controller.forward(from: 0),
      child: AnimatedBuilder(
        animation: _rotation,
        builder: (BuildContext context, Widget? child) => Transform.rotate(
          key: const Key('popup-mascot-transform'),
          angle: _rotation.value,
          child: child,
        ),
        child: Image.asset('Assets/AgentToolIcon.png', width: 34, height: 34),
      ),
    );
  }
}
