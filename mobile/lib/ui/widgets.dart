import 'package:flutter/material.dart';

import 'tokens.dart';

// Building blocks matching the PWA's components (docs/app/styles.css).

enum DingButtonStyle { primary, quiet, danger, small, smallAccent }

class DingButton extends StatelessWidget {
  const DingButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = DingButtonStyle.primary,
    this.icon,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final DingButtonStyle style;
  final String? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    final bool small =
        style == DingButtonStyle.small || style == DingButtonStyle.smallAccent;
    final (Color background, Color foreground) = switch (style) {
      DingButtonStyle.primary ||
      DingButtonStyle.smallAccent => (t.accent, t.onAccent),
      DingButtonStyle.danger => (t.danger, Colors.white),
      DingButtonStyle.quiet ||
      DingButtonStyle.small => (t.field, t.textSecondary),
    };
    final bool enabled = onPressed != null;
    final Widget child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Image.asset(
            icon!,
            width: 15,
            height: 15,
            color: foreground,
            colorBlendMode: BlendMode.srcIn,
          ),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: small ? 12 : 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(DingRadius.button),
        child: InkWell(
          borderRadius: BorderRadius.circular(DingRadius.button),
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: small ? 40 : 44),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: small ? 11 : 14),
              child: Center(widthFactor: expand ? null : 1, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.icon-button`: 44px square on the field color.
class DingIconButton extends StatelessWidget {
  const DingIconButton({
    super.key,
    required this.semanticLabel,
    required this.onPressed,
    this.asset,
    this.glyph,
  });

  final String semanticLabel;
  final VoidCallback onPressed;
  final String? asset;
  final String? glyph;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    return Semantics(
      button: true,
      label: semanticLabel,
      child: Material(
        color: t.field,
        borderRadius: BorderRadius.circular(11),
        child: InkWell(
          borderRadius: BorderRadius.circular(11),
          onTap: onPressed,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Center(
              child: asset != null
                  ? DingSymbol(asset!)
                  : Text(
                      glyph ?? '',
                      style: TextStyle(fontSize: 20, color: t.textSecondary),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.offline-banner` / `.notification-onboarding`.
class DingBanner extends StatelessWidget {
  const DingBanner({
    super.key,
    required this.title,
    required this.body,
    this.image,
    this.action,
    this.accent = false,
  });

  final String title;
  final String body;
  final String? image;
  final Widget? action;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent ? t.accentSoft : t.surfaceSoft,
        border: Border.all(color: accent ? t.accentBorder : t.border),
        borderRadius: BorderRadius.circular(DingRadius.banner),
      ),
      child: Row(
        children: <Widget>[
          if (image != null) ...<Widget>[
            DingMascot(image!, size: 42),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.4,
                    color: t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...<Widget>[const SizedBox(width: 10), action!],
        ],
      ),
    );
  }
}

/// `.switch-control`: 38x22 track, 14px thumb.
class DingSwitch extends StatelessWidget {
  const DingSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    required this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    return Semantics(
      toggled: value,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              width: 38,
              height: 22,
              decoration: BoxDecoration(
                color: value ? t.accent : t.field,
                border: Border.all(color: value ? t.accent : t.border),
                borderRadius: BorderRadius.circular(11),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 140),
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value ? t.onAccent : t.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.text-input`.
class DingTextField extends StatelessWidget {
  const DingTextField({
    super.key,
    required this.controller,
    this.hint,
    this.maxLength,
    this.keyboardType,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String? hint;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(DingRadius.input),
      borderSide: BorderSide(color: color),
    );
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: keyboardType,
      maxLength: maxLength,
      style: TextStyle(fontSize: 14, color: t.text),
      decoration: InputDecoration(
        counterText: '',
        hintText: hint,
        hintStyle: TextStyle(color: t.textSecondary),
        filled: true,
        fillColor: t.surfaceSoft,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 14,
        ),
        enabledBorder: border(t.border),
        focusedBorder: border(t.accent),
      ),
    );
  }
}

/// `.settings-dialog` with its `.dialog-header`.
Future<T?> showDingDialog<T>(
  BuildContext context, {
  String? eyebrow,
  required String title,
  String? summary,
  required List<Widget> Function(BuildContext context) children,
}) {
  return showDialog<T>(
    context: context,
    barrierColor: const Color(0x611A1E21),
    builder: (BuildContext context) {
      final DingTokens t = DingTokens.of(context);
      return Dialog(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DingRadius.sheet),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: t.border)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (eyebrow != null) Eyebrow(eyebrow),
                            const SizedBox(height: 3),
                            Text(
                              title,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 19,
                                height: 1.25,
                                letterSpacing: -0.35,
                                fontWeight: FontWeight.w700,
                                color: t.text,
                              ),
                            ),
                            if (summary != null) ...<Widget>[
                              const SizedBox(height: 5),
                              Text(
                                summary,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: t.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      DingIconButton(
                        semanticLabel: '关闭',
                        glyph: '×',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
                ...children(context),
              ],
            ),
          ),
        ),
      );
    },
  );
}

/// Two equal buttons at the bottom of a dialog (`.dialog-actions`).
class DialogActions extends StatelessWidget {
  const DialogActions({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Row(
        children: <Widget>[
          for (int index = 0; index < children.length; index += 1) ...<Widget>[
            if (index > 0) const SizedBox(width: 8),
            Expanded(child: children[index]),
          ],
        ],
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.65,
      color: DingTokens.of(context).accent,
    ),
  );
}

/// `.setting-row`: title, secondary text and a trailing control.
class SettingRow extends StatelessWidget {
  const SettingRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final DingTokens t = DingTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 1),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: t.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.4,
                    color: t.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          trailing,
        ],
      ),
    );
  }
}

/// The PWA's dark pill toast above the composer.
void showDingToast(BuildContext context, String text) {
  final OverlayState overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (BuildContext context) => Positioned(
      left: 20,
      right: 20,
      bottom: MediaQuery.paddingOf(context).bottom + 145,
      child: IgnorePointer(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF222629),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: Color(0x1A1F262B),
                  blurRadius: 44,
                  offset: Offset(0, 16),
                ),
              ],
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(const Duration(milliseconds: 2600), entry.remove);
}

/// A monochrome symbol from assets/symbols. Light mode draws it as the PWA
/// does (black at reduced opacity); dark mode tints it to the text color.
class DingSymbol extends StatelessWidget {
  const DingSymbol(
    this.asset, {
    super.key,
    this.size = 19,
    this.opacity = 0.72,
  });

  final String asset;
  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Opacity(
      opacity: opacity,
      child: Image.asset(
        asset,
        width: size,
        height: size,
        color: dark ? DingTokens.of(context).text : null,
        colorBlendMode: dark ? BlendMode.srcIn : null,
      ),
    );
  }
}

/// A navy-outlined DingDong mascot drawing. In dark mode it sits on a light
/// rounded tile so the outline stays visible.
class DingMascot extends StatelessWidget {
  const DingMascot(this.asset, {super.key, required this.size});

  final String asset;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Widget image = Image.asset(
      asset,
      width: size,
      height: size,
      gaplessPlayback: true,
    );
    if (Theme.of(context).brightness != Brightness.dark) return image;
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.08),
      decoration: BoxDecoration(
        color: DingTokens.light.accentSoft,
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Image.asset(asset, gaplessPlayback: true),
    );
  }
}

/// Vertically centred, scrollable column: the PWA's `.empty-view` /
/// `.pair-view` (`min-height: 100dvh - 120px; justify-content: center`).
class CenteredScroll extends StatelessWidget {
  const CenteredScroll({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) =>
          SingleChildScrollView(
            padding: padding,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - padding.vertical).clamp(
                  0,
                  double.infinity,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
          ),
    );
  }
}
