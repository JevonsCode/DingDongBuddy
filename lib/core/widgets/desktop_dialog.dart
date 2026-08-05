import 'dart:math' as math;

import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:flutter/material.dart';

/// Shared modal treatment for DingDong's compact desktop surfaces.
abstract final class DesktopDialogStyle {
  static const double radius = 18;
  static const double controlRadius = 10;
  static const EdgeInsets insetPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 24,
  );

  static RoundedRectangleBorder shape(ColorScheme colors) {
    return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  }

  static DialogThemeData theme(ColorScheme colors, TextTheme textTheme) {
    return DialogThemeData(
      backgroundColor: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: colors.shadow.withValues(alpha: 0.14),
      barrierColor: colors.scrim.withValues(alpha: 0.32),
      shape: shape(colors),
      insetPadding: insetPadding,
      clipBehavior: Clip.antiAlias,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        color: colors.onSurface,
        fontSize: 18,
        height: 1.18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.35,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
        fontSize: 13,
        height: 1.5,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
    );
  }

  static ThemeData scopedTheme(ThemeData theme) {
    final ColorScheme colors = theme.colorScheme;
    final RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(controlRadius),
    );
    return theme.copyWith(
      dialogTheme: DesktopDialogStyle.theme(colors, theme.textTheme),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          elevation: 0,
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: controlShape,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: controlShape,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: controlShape,
          backgroundColor: colors.surfaceContainerHigh,
          side: BorderSide.none,
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  static ButtonStyle destructiveButtonStyle(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
      backgroundColor: colors.error,
      foregroundColor: colors.onError,
    );
  }
}

/// The modal canvas shared by simple alerts and richer feature dialogs.
///
/// A concrete width is resolved against the viewport instead of relying on
/// intrinsic sizing. This keeps short titles and multiline editors on the
/// same predictable desktop grid.
final class DesktopDialogFrame extends StatelessWidget {
  const DesktopDialogFrame({
    required this.body,
    this.header,
    this.footer,
    this.width = 440,
    this.maxHeight,
    this.bodyPadding = const EdgeInsets.fromLTRB(22, 18, 22, 20),
    this.dialogKey,
    super.key,
  });

  final Widget? header;
  final Widget body;
  final Widget? footer;
  final double width;
  final double? maxHeight;
  final EdgeInsetsGeometry bodyPadding;
  final Key? dialogKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Size viewport = MediaQuery.sizeOf(context);
    final double availableWidth = math.max(
      280,
      viewport.width - DesktopDialogStyle.insetPadding.horizontal,
    );
    final double resolvedWidth = math.min(width, availableWidth);
    final double availableHeight = math.max(
      240,
      viewport.height - DesktopDialogStyle.insetPadding.vertical,
    );
    final double resolvedMaxHeight = math.min(
      maxHeight ?? availableHeight,
      availableHeight,
    );

    return DesktopDialogTheme(
      child: Dialog(
        insetPadding: DesktopDialogStyle.insetPadding,
        elevation: 12,
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shadowColor: colors.shadow.withValues(alpha: 0.14),
        clipBehavior: Clip.antiAlias,
        shape: DesktopDialogStyle.shape(colors),
        child: ConstrainedBox(
          key: dialogKey,
          constraints: BoxConstraints(
            minWidth: resolvedWidth,
            maxWidth: resolvedWidth,
            maxHeight: resolvedMaxHeight,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ?header,
              Flexible(
                fit: FlexFit.loose,
                child: Padding(padding: bodyPadding, child: body),
              ),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// Standard title area for every full-featured desktop dialog.
final class DesktopDialogHeader extends StatelessWidget {
  const DesktopDialogHeader({
    required this.title,
    this.subtitle,
    this.leading,
    this.onBack,
    this.onClose,
    this.closeTooltip,
    this.backTooltip,
    this.showDivider = true,
    super.key,
  });

  final Widget title;
  final Widget? subtitle;
  final Widget? leading;
  final VoidCallback? onBack;
  final VoidCallback? onClose;
  final String? closeTooltip;
  final String? backTooltip;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Widget? resolvedLeading = onBack == null
        ? leading
        : DesktopIconButton(
            tooltip: backTooltip ?? 'Back',
            onPressed: onBack,
            size: 32,
            iconSize: 16,
            foregroundColor: colors.onSurfaceVariant,
            backgroundColor: colors.surfaceContainerHigh.withValues(
              alpha: 0.72,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 20, 16, 16),
      decoration: BoxDecoration(
        color: showDivider
            ? colors.surfaceContainerLow.withValues(alpha: 0.42)
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (resolvedLeading != null) ...<Widget>[
            resolvedLeading,
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DefaultTextStyle.merge(
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: colors.onSurface,
                    fontSize: 18,
                    height: 1.18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  child: title,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: 5),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (onClose != null) ...<Widget>[
            const SizedBox(width: 12),
            DesktopIconButton(
              tooltip: closeTooltip ?? 'Close',
              onPressed: onClose,
              size: 32,
              iconSize: 16,
              foregroundColor: colors.onSurfaceVariant,
              backgroundColor: colors.surfaceContainerHigh.withValues(
                alpha: 0.72,
              ),
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

/// Consistent footer treatment with equal-width actions.
final class DesktopDialogFooter extends StatelessWidget {
  const DesktopDialogFooter({
    required this.actions,
    this.fillActions = true,
    this.actionHeight = 38,
    super.key,
  });

  final List<Widget> actions;
  final bool fillActions;
  final double actionHeight;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final Widget actionRow;
    if (actions.length == 1) {
      actionRow = Align(
        alignment: Alignment.centerRight,
        child: SizedBox(
          width: 148,
          height: actionHeight,
          child: actions.single,
        ),
      );
    } else if (fillActions) {
      actionRow = Row(
        children: <Widget>[
          for (int index = 0; index < actions.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: SizedBox(height: actionHeight, child: actions[index]),
            ),
          ],
        ],
      );
    } else {
      actionRow = Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: actions
            .map(
              (Widget action) => SizedBox(height: actionHeight, child: action),
            )
            .toList(growable: false),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 18),
      child: actionRow,
    );
  }
}

/// Compact confirmation/editor dialog built on the same frame as rich modals.
final class DesktopAlertDialog extends StatelessWidget {
  const DesktopAlertDialog({
    this.title,
    this.content,
    this.actions,
    this.maxWidth = 420,
    this.scrollable = false,
    super.key,
  });

  final Widget? title;
  final Widget? content;
  final List<Widget>? actions;
  final double maxWidth;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final bool hasTitle = title != null;
    final bool hasActions = actions?.isNotEmpty ?? false;
    final Widget body = content ?? const SizedBox.shrink();
    return DesktopDialogFrame(
      width: maxWidth,
      maxHeight: scrollable ? MediaQuery.sizeOf(context).height - 48 : null,
      header: hasTitle
          ? DesktopDialogHeader(title: title!, showDivider: false)
          : null,
      bodyPadding: EdgeInsets.fromLTRB(
        22,
        hasTitle ? 2 : 20,
        22,
        hasActions ? 20 : 22,
      ),
      body: scrollable ? SingleChildScrollView(child: body) : body,
      footer: hasActions ? DesktopDialogFooter(actions: actions!) : null,
    );
  }
}

/// Limits dialog control styling to the modal subtree.
final class DesktopDialogTheme extends StatelessWidget {
  const DesktopDialogTheme({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: DesktopDialogStyle.scopedTheme(Theme.of(context)),
      child: child,
    );
  }
}
