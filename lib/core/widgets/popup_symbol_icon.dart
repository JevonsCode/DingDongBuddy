import 'package:flutter/material.dart';

/// Cross-platform rendering of the original DingDong SF Symbol artwork.
///
/// Symbols are exported once as monochrome PNG assets so macOS and Windows use
/// identical glyph geometry, optical weight, and sizing.
class PopupSymbolIcon extends StatelessWidget {
  const PopupSymbolIcon(
    this.symbol, {
    required this.size,
    required this.color,
    super.key,
  });

  final String symbol;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => Image.asset(
    'Assets/Symbols/$symbol.png',
    width: size,
    height: size,
    color: color,
    colorBlendMode: BlendMode.srcIn,
    filterQuality: FilterQuality.high,
    excludeFromSemantics: true,
  );
}
