import 'dart:math' as math;

import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:flutter/material.dart';

/// Density presets for the three modal jobs used across the desktop app.
enum DesktopDialogDensity { alert, chooser, editor }

/// Shared modal treatment for DingDong's compact desktop surfaces.
abstract final class DesktopDialogStyle {
  static const double radius = 14;
  static const double controlRadius = 7;
  static const EdgeInsets insetPadding = EdgeInsets.all(24);

  static RoundedRectangleBorder shape(ColorScheme colors) {
    return RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
  }

  static DialogThemeData theme(ColorScheme colors, TextTheme textTheme) {
    return DialogThemeData(
      backgroundColor: colors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 10,
      shadowColor: colors.shadow.withValues(alpha: 0.18),
      barrierColor: colors.scrim.withValues(alpha: 0.36),
      shape: shape(colors),
      insetPadding: insetPadding,
      clipBehavior: Clip.antiAlias,
      titleTextStyle: textTheme.titleMedium?.copyWith(
        color: colors.onSurface,
        fontSize: 17,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.28,
      ),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colors.onSurfaceVariant,
        fontSize: 13,
        height: 1.5,
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
        style:
            FilledButton.styleFrom(
              elevation: 0,
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: controlShape,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ).copyWith(
              animationDuration: Duration.zero,
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll<Color>(
                Colors.transparent,
              ),
              side: WidgetStateProperty.resolveWith<BorderSide>((states) {
                return states.contains(WidgetState.focused)
                    ? BorderSide(
                        color: colors.onPrimary.withValues(alpha: 0.8),
                        width: 1.5,
                      )
                    : BorderSide.none;
              }),
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: controlShape,
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ).copyWith(
              animationDuration: Duration.zero,
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll<Color>(
                Colors.transparent,
              ),
              side: WidgetStateProperty.resolveWith<BorderSide>((states) {
                return states.contains(WidgetState.focused)
                    ? BorderSide(
                        color: colors.primary.withValues(alpha: 0.78),
                        width: 1.5,
                      )
                    : BorderSide.none;
              }),
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              minimumSize: const Size(0, 34),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: controlShape,
              backgroundColor: colors.surfaceContainerHigh.withValues(
                alpha: 0.7,
              ),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ).copyWith(
              animationDuration: Duration.zero,
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll<Color>(
                Colors.transparent,
              ),
              side: WidgetStateProperty.resolveWith<BorderSide>((states) {
                if (states.contains(WidgetState.focused)) {
                  return BorderSide(
                    color: colors.primary.withValues(alpha: 0.78),
                    width: 1.5,
                  );
                }
                return BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.58),
                );
              }),
            ),
      ),
    );
  }

  static ButtonStyle destructiveButtonStyle(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return ButtonStyle(
      backgroundColor: WidgetStatePropertyAll<Color>(colors.error),
      foregroundColor: WidgetStatePropertyAll<Color>(colors.onError),
      splashFactory: NoSplash.splashFactory,
      overlayColor: const WidgetStatePropertyAll<Color>(Colors.transparent),
    );
  }
}

extension on DesktopDialogDensity {
  EdgeInsets get bodyPadding => switch (this) {
    DesktopDialogDensity.alert => const EdgeInsets.fromLTRB(20, 16, 20, 18),
    DesktopDialogDensity.chooser => const EdgeInsets.fromLTRB(20, 16, 20, 20),
    DesktopDialogDensity.editor => const EdgeInsets.fromLTRB(24, 20, 24, 24),
  };

  EdgeInsets get headerPadding => switch (this) {
    DesktopDialogDensity.alert => const EdgeInsets.fromLTRB(20, 18, 16, 14),
    DesktopDialogDensity.chooser => const EdgeInsets.fromLTRB(20, 18, 16, 15),
    DesktopDialogDensity.editor => const EdgeInsets.fromLTRB(24, 22, 18, 18),
  };

  EdgeInsets get footerPadding => switch (this) {
    DesktopDialogDensity.alert => const EdgeInsets.fromLTRB(20, 8, 20, 16),
    DesktopDialogDensity.chooser => const EdgeInsets.fromLTRB(20, 10, 20, 18),
    DesktopDialogDensity.editor => const EdgeInsets.fromLTRB(24, 12, 24, 22),
  };

  double get titleSize => switch (this) {
    DesktopDialogDensity.alert => 16,
    DesktopDialogDensity.chooser => 17,
    DesktopDialogDensity.editor => 18,
  };

  double get actionHeight => switch (this) {
    DesktopDialogDensity.alert => 34,
    DesktopDialogDensity.chooser => 34,
    DesktopDialogDensity.editor => 36,
  };
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
    this.bodyPadding,
    this.density = DesktopDialogDensity.chooser,
    this.dialogKey,
    super.key,
  });

  final Widget? header;
  final Widget body;
  final Widget? footer;
  final double width;
  final double? maxHeight;
  final EdgeInsetsGeometry? bodyPadding;
  final DesktopDialogDensity density;
  final Key? dialogKey;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Size viewport = MediaQuery.sizeOf(context);
    final double availableWidth = math.max(
      0,
      viewport.width - DesktopDialogStyle.insetPadding.horizontal,
    );
    final double resolvedWidth = math.max(0, math.min(width, availableWidth));
    final double availableHeight = math.max(
      0,
      viewport.height - DesktopDialogStyle.insetPadding.vertical,
    );
    final double resolvedMaxHeight = math.max(
      0,
      math.min(maxHeight ?? availableHeight, availableHeight),
    );

    return DesktopDialogTheme(
      child: Dialog(
        insetPadding: DesktopDialogStyle.insetPadding,
        elevation: 10,
        backgroundColor: colors.surfaceContainerLowest,
        surfaceTintColor: Colors.transparent,
        shadowColor: colors.shadow.withValues(alpha: 0.18),
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
                child: Padding(
                  padding: bodyPadding ?? density.bodyPadding,
                  child: body,
                ),
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
    this.density = DesktopDialogDensity.chooser,
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
  final DesktopDialogDensity density;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Widget? resolvedLeading = onBack == null
        ? leading
        : DesktopIconButton(
            tooltip: backTooltip ?? 'Back',
            onPressed: onBack,
            size: density == DesktopDialogDensity.editor ? 32 : 30,
            iconSize: 16,
            foregroundColor: colors.onSurfaceVariant,
            icon: const Icon(Icons.arrow_back_rounded),
          );

    return Container(
      padding: density.headerPadding,
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(
                  color: colors.outlineVariant.withValues(alpha: 0.55),
                ),
              )
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
                Semantics(
                  header: true,
                  child: DefaultTextStyle.merge(
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colors.onSurface,
                      fontSize: density.titleSize,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.28,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    child: title,
                  ),
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
              size: density == DesktopDialogDensity.editor ? 32 : 30,
              iconSize: 16,
              foregroundColor: colors.onSurfaceVariant,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

/// Consistent footer treatment with compact, right-aligned desktop actions.
final class DesktopDialogFooter extends StatelessWidget {
  const DesktopDialogFooter({
    required this.actions,
    this.fillActions = false,
    this.actionHeight,
    this.density = DesktopDialogDensity.chooser,
    this.showDivider = false,
    super.key,
  });

  final List<Widget> actions;
  final bool fillActions;
  final double? actionHeight;
  final DesktopDialogDensity density;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();
    final double resolvedActionHeight = actionHeight ?? density.actionHeight;

    final Widget actionRow;
    if (actions.length == 1) {
      actionRow = Align(
        alignment: Alignment.centerRight,
        child: SizedBox(height: resolvedActionHeight, child: actions.single),
      );
    } else if (fillActions) {
      actionRow = Row(
        children: <Widget>[
          for (int index = 0; index < actions.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: resolvedActionHeight,
                child: actions[index],
              ),
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
              (Widget action) =>
                  SizedBox(height: resolvedActionHeight, child: action),
            )
            .toList(growable: false),
      );
    }

    return Container(
      padding: density.footerPadding,
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                top: BorderSide(
                  color: Theme.of(
                    context,
                  ).colorScheme.outlineVariant.withValues(alpha: 0.55),
                ),
              )
            : null,
      ),
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
      density: DesktopDialogDensity.alert,
      maxHeight: scrollable ? MediaQuery.sizeOf(context).height - 48 : null,
      header: hasTitle
          ? DesktopDialogHeader(
              title: title!,
              density: DesktopDialogDensity.alert,
              showDivider: false,
            )
          : null,
      bodyPadding: EdgeInsets.fromLTRB(
        20,
        hasTitle ? 2 : 20,
        20,
        hasActions ? 16 : 20,
      ),
      body: scrollable ? SingleChildScrollView(child: body) : body,
      footer: hasActions
          ? DesktopDialogFooter(
              actions: actions!,
              density: DesktopDialogDensity.alert,
            )
          : null,
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
