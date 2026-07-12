import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:flutter/material.dart';

/// Shared enabled/paused indicator used across Dynamic and Resource Library.
class EnabledStatusIcon extends StatelessWidget {
  const EnabledStatusIcon({required this.enabled, this.size = 18, super.key});

  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) => PopupSymbolIcon(
    enabled ? 'enabled' : 'paused',
    size: size,
    color: enabled ? PopupStyle.success : PopupStyle.textTertiary,
  );
}
