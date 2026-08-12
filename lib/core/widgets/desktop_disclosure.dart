import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A compact disclosure section that avoids ExpansionTile's native treatment.
class DesktopDisclosure extends StatefulWidget {
  const DesktopDisclosure({
    required this.title,
    required this.child,
    this.leading,
    this.initiallyExpanded = false,
    super.key,
  });

  final Widget title;
  final Widget child;
  final Widget? leading;
  final bool initiallyExpanded;

  @override
  State<DesktopDisclosure> createState() => _DesktopDisclosureState();
}

class _DesktopDisclosureState extends State<DesktopDisclosure>
    with SingleTickerProviderStateMixin {
  late bool _expanded = widget.initiallyExpanded;
  bool _hovered = false;
  bool _focused = false;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 160),
    value: _expanded ? 1 : 0,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Semantics(
          button: true,
          expanded: _expanded,
          onTap: _toggle,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: FocusableActionDetector(
              mouseCursor: SystemMouseCursors.click,
              shortcuts: const <ShortcutActivator, Intent>{
                SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
                SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
              },
              actions: <Type, Action<Intent>>{
                ActivateIntent: CallbackAction<ActivateIntent>(
                  onInvoke: (_) {
                    _toggle();
                    return null;
                  },
                ),
              },
              onShowFocusHighlight: (bool value) {
                if (_focused != value) setState(() => _focused = value);
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  decoration: BoxDecoration(
                    color: _hovered || _focused
                        ? colors.onSurface.withValues(alpha: 0.04)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: _focused
                          ? colors.primary.withValues(alpha: 0.58)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    children: <Widget>[
                      if (widget.leading != null) ...<Widget>[
                        widget.leading!,
                        const SizedBox(width: 9),
                      ],
                      Expanded(child: widget.title),
                      RotationTransition(
                        turns: Tween<double>(begin: 0, end: 0.5).animate(
                          CurvedAnimation(
                            parent: _controller,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        ClipRect(
          child: SizeTransition(
            sizeFactor: CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: widget.child,
            ),
          ),
        ),
      ],
    );
  }
}
