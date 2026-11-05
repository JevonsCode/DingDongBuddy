import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:flutter/material.dart';

/// The shared list overlay: place it after the scrollable in a [Stack].
/// Appears after one viewport; the caller owns and disposes [controller].
class DesktopBackToTop extends StatelessWidget {
  const DesktopBackToTop({required this.controller, this.buttonKey, super.key});

  final ScrollController controller;
  final Key? buttonKey;

  @override
  Widget build(BuildContext context) => Positioned(
    right: 12,
    bottom: 12,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (!controller.hasClients ||
            !controller.position.hasContentDimensions ||
            controller.offset <= controller.position.viewportDimension) {
          return const SizedBox.shrink();
        }
        final colors = PopupStyle.of(context);
        return DesktopIconButton(
          key: buttonKey,
          tooltip: context.l10n.backToTop,
          icon: const Icon(Icons.vertical_align_top_rounded),
          size: 32,
          iconSize: 18,
          foregroundColor: colors.textSecondary,
          backgroundColor: colors.background,
          borderColor: colors.border,
          onPressed: () {
            if (!controller.hasClients) return;
            if (MediaQuery.disableAnimationsOf(context)) {
              controller.jumpTo(0);
            } else {
              unawaited(
                controller.animateTo(
                  0,
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                ),
              );
            }
          },
        );
      },
    ),
  );
}
