import 'dart:async';

import 'package:dingdong/features/shell/domain/tray_buddy_controller.dart';
import 'package:flutter/material.dart';

const Duration popupMascotTapWindow = Duration(seconds: 5);
const Duration popupMascotThinkingDuration = Duration(seconds: 2);

/// Clickable DingDong mascot with state artwork and a hidden third-click pose.
class PopupMascot extends StatefulWidget {
  const PopupMascot({
    required this.shakeRevision,
    required this.state,
    super.key,
  });

  final int shakeRevision;
  final TrayBuddyState state;

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
  Timer? _tapWindowTimer;
  Timer? _thinkingTimer;
  int _tapCount = 0;
  bool _showThinking = false;

  @override
  void didUpdateWidget(covariant PopupMascot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shakeRevision != widget.shakeRevision) {
      _shake();
    }
  }

  @override
  void dispose() {
    _tapWindowTimer?.cancel();
    _thinkingTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    _shake();
    if (_tapCount == 0) {
      _tapWindowTimer?.cancel();
      _tapWindowTimer = Timer(popupMascotTapWindow, () => _tapCount = 0);
    }
    _tapCount += 1;
    if (_tapCount < 3) {
      return;
    }
    _tapCount = 0;
    _tapWindowTimer?.cancel();
    _thinkingTimer?.cancel();
    setState(() => _showThinking = true);
    _thinkingTimer = Timer(popupMascotThinkingDuration, () {
      if (mounted) {
        setState(() => _showThinking = false);
      }
    });
  }

  void _shake() {
    _controller.forward(from: 0);
  }

  String get _assetPath {
    if (_showThinking) {
      return 'Assets/DingDongIP/thinking.png';
    }
    return switch (widget.state) {
      TrayBuddyState.normal => 'Assets/DingDongIP/AgentToolIcon.png',
      TrayBuddyState.reminder => 'Assets/DingDongIP/ding.png',
      TrayBuddyState.resting => 'Assets/DingDongIP/rest.png',
      TrayBuddyState.sleeping => 'Assets/DingDongIP/sleeping.png',
    };
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('popup-mascot'),
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _rotation,
        builder: (BuildContext context, Widget? child) => Transform.rotate(
          key: const Key('popup-mascot-transform'),
          angle: _rotation.value,
          child: child,
        ),
        child: Image.asset(
          _assetPath,
          key: const Key('popup-mascot-image'),
          width: 34,
          height: 34,
        ),
      ),
    );
  }
}
