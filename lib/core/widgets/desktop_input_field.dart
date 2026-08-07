import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Single-line search field with a stable desktop surface and built-in clear
/// action. Search icon, placeholder and clear affordance follow familiar
/// platform conventions while all geometry stays consistent across windows.
class DesktopSearchField extends StatefulWidget {
  const DesktopSearchField({
    required this.hintText,
    this.controller,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.height = 38,
    this.backgroundColor,
    this.borderColor,
    this.focusBorderColor,
    this.foregroundColor,
    this.hintStyle,
    this.style,
    this.searchIcon,
    this.clearTooltip = 'Clear search',
    this.surfaceKey,
    this.searchIconKey,
    this.clearButtonKey,
    this.borderRadius = 9,
    Key? key,
  }) : _fieldKey = key,
       super(key: null);

  // Keep the public key on TextField so enterText/focus integrations continue
  // to address the editable control itself.
  final Key? _fieldKey;

  final String hintText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;
  final double height;
  final Color? backgroundColor;
  final Color? borderColor;
  final Color? focusBorderColor;
  final Color? foregroundColor;
  final TextStyle? hintStyle;
  final TextStyle? style;
  final Widget? searchIcon;
  final String clearTooltip;
  final Key? surfaceKey;
  final Key? searchIconKey;
  final Key? clearButtonKey;
  final double borderRadius;

  @override
  State<DesktopSearchField> createState() => _DesktopSearchFieldState();
}

class _DesktopSearchFieldState extends State<DesktopSearchField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _hasText = false;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'desktop-search');
    _controller.addListener(_handleControllerChanged);
    _focusNode.addListener(_handleFocusChanged);
    _hasText = _controller.text.isNotEmpty;
    _focused = _focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant DesktopSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _controller.removeListener(_handleControllerChanged);
      if (oldWidget.controller == null) _controller.dispose();
      _controller = widget.controller ?? TextEditingController();
      _controller.addListener(_handleControllerChanged);
      _hasText = _controller.text.isNotEmpty;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_handleFocusChanged);
      if (oldWidget.focusNode == null) _focusNode.dispose();
      _focusNode = widget.focusNode ?? FocusNode(debugLabel: 'desktop-search');
      _focusNode.addListener(_handleFocusChanged);
      _focused = _focusNode.hasFocus;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _focusNode.removeListener(_handleFocusChanged);
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focusNode.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    final bool hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText && mounted) setState(() => _hasText = hasText);
  }

  void _handleFocusChanged() {
    if (_focusNode.hasFocus != _focused && mounted) {
      setState(() => _focused = _focusNode.hasFocus);
    }
  }

  void _clear() {
    if (_controller.text.isEmpty) return;
    _controller.clear();
    widget.onChanged?.call('');
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;
    final Color foreground = widget.foregroundColor ?? colors.onSurfaceVariant;
    final Color outline = _focused
        ? widget.focusBorderColor ?? colors.primary.withValues(alpha: 0.52)
        : widget.borderColor ?? colors.outlineVariant.withValues(alpha: 0.88);
    final Widget icon =
        widget.searchIcon ??
        Icon(Icons.search_rounded, size: widget.height <= 34 ? 16 : 18);
    final TextStyle? textStyle =
        widget.style ??
        theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurface,
          fontSize: 13,
          height: 1.05,
        );
    return Container(
      key: widget.surfaceKey,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color:
            widget.backgroundColor ??
            colors.surfaceContainerLowest.withValues(
              alpha: widget.enabled ? 1 : 0.55,
            ),
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(color: outline),
      ),
      child: DesktopTextField(
        key: widget._fieldKey,
        controller: _controller,
        focusNode: _focusNode,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        autofocus: widget.autofocus,
        enabled: widget.enabled,
        textInputAction: TextInputAction.search,
        textAlignVertical: TextAlignVertical.center,
        cursorColor: colors.primary,
        cursorHeight: widget.height <= 34 ? 16 : 17,
        cursorWidth: 1.5,
        style: textStyle,
        decoration: InputDecoration(
          isCollapsed: true,
          filled: false,
          hintText: widget.hintText,
          hintStyle:
              widget.hintStyle ??
              textStyle?.copyWith(color: foreground.withValues(alpha: 0.82)),
          contentPadding: const EdgeInsets.only(right: 4),
          prefixIcon: SizedBox(
            key: widget.searchIconKey,
            width: widget.height,
            height: widget.height,
            child: Center(
              child: IconTheme.merge(
                data: IconThemeData(color: foreground),
                child: icon,
              ),
            ),
          ),
          prefixIconConstraints: BoxConstraints.tightFor(
            width: widget.height,
            height: widget.height,
          ),
          suffixIcon: _hasText && widget.enabled
              ? Center(
                  child: DesktopIconButton(
                    key: widget.clearButtonKey,
                    tooltip: widget.clearTooltip,
                    onPressed: _clear,
                    size: widget.height <= 34 ? 26 : 28,
                    iconSize: 14,
                    foregroundColor: foreground,
                    icon: const Icon(Icons.close_rounded),
                  ),
                )
              : null,
          suffixIconConstraints: BoxConstraints.tightFor(
            width: _hasText && widget.enabled
                ? (widget.height <= 34 ? 32 : 34)
                : 0,
            height: widget.height,
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
        ),
      ),
    );
  }
}

/// Text input with DingDong's compact desktop geometry.
///
/// The app still uses Flutter's text editing semantics, but keeps the visual
/// treatment in one place so feature screens do not drift back to the default
/// Material field metrics.
class DesktopTextField extends StatelessWidget {
  const DesktopTextField({
    this.controller,
    this.focusNode,
    this.decoration,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.readOnly = false,
    this.minLines,
    this.maxLines = 1,
    this.expands = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.maxLengthEnforcement,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.style,
    this.cursorColor,
    this.cursorHeight,
    this.cursorWidth = 2,
    this.obscureText = false,
    Key? key,
  }) : _fieldKey = key,
       super(key: null);

  // Keep the key on the platform text control so existing focus/editing
  // integrations can address the real field without exposing duplicate key
  // matches through the shared wrapper.
  final Key? _fieldKey;

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final bool enabled;
  final bool readOnly;
  final int? minLines;
  final int? maxLines;
  final bool expands;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final MaxLengthEnforcement? maxLengthEnforcement;
  final TextAlign textAlign;
  final TextAlignVertical? textAlignVertical;
  final TextStyle? style;
  final Color? cursorColor;
  final double? cursorHeight;
  final double cursorWidth;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final InputDecoration resolvedDecoration =
        (decoration ?? const InputDecoration())
            .applyDefaults(theme.inputDecorationTheme)
            .copyWith(
              isDense: true,
              contentPadding:
                  decoration?.contentPadding ??
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            );
    return TextField(
      key: _fieldKey,
      controller: controller,
      focusNode: focusNode,
      decoration: resolvedDecoration,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      enabled: enabled,
      readOnly: readOnly,
      minLines: minLines,
      maxLines: maxLines,
      expands: expands,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      maxLength: maxLength,
      maxLengthEnforcement: maxLengthEnforcement,
      textAlign: textAlign,
      textAlignVertical: textAlignVertical,
      style: style,
      cursorColor: cursorColor,
      cursorHeight: cursorHeight,
      cursorWidth: cursorWidth,
      obscureText: obscureText,
    );
  }
}

/// Form-compatible sibling for settings and editor fields.
class DesktopTextFormField extends StatelessWidget {
  const DesktopTextFormField({
    required this.initialValue,
    this.decoration,
    this.onChanged,
    this.keyboardType,
    this.textAlign = TextAlign.start,
    Key? key,
  }) : _fieldKey = key,
       super(key: null);

  final Key? _fieldKey;

  final String initialValue;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final InputDecoration resolvedDecoration =
        (decoration ?? const InputDecoration())
            .applyDefaults(theme.inputDecorationTheme)
            .copyWith(
              isDense: true,
              contentPadding:
                  decoration?.contentPadding ??
                  const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
            );
    return TextFormField(
      key: _fieldKey,
      initialValue: initialValue,
      decoration: resolvedDecoration,
      onChanged: onChanged,
      keyboardType: keyboardType,
      textAlign: textAlign,
    );
  }
}
