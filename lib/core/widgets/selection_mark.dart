import 'package:flutter/material.dart';

/// Compact multi-select indicator without the heavy outlined checkbox look.
class SelectionMark extends StatelessWidget {
  const SelectionMark({required this.selected, this.size = 18, super.key});

  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? colors.primary : colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutBack,
        scale: selected ? 1 : 0.72,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          opacity: selected ? 1 : 0,
          child: Icon(
            Icons.check_rounded,
            size: size * 0.72,
            color: colors.onPrimary,
          ),
        ),
      ),
    );
  }
}
