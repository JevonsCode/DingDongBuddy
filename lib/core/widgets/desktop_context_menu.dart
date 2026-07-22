import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const double _windowsMenuMinWidth = 252;
const double _windowsMenuMaxWidth = 280;
const double _windowsMenuItemHeight = 32;

typedef _DesktopContextMenuDismissal = Future<void> Function();

/// Tracks the Flutter-owned desktop context menu that is currently open.
///
/// Desktop hosts should dismiss the active menu before hiding their window so
/// the menu route cannot reappear when the window is shown again.
final class DesktopContextMenuController {
  Object? _activeSession;
  _DesktopContextMenuDismissal? _activeDismissal;

  Future<void> dismissActiveMenu() async {
    final _DesktopContextMenuDismissal? dismissal = _activeDismissal;
    _activeSession = null;
    _activeDismissal = null;
    await dismissal?.call();
  }

  Object _register(_DesktopContextMenuDismissal dismissal) {
    final Object session = Object();
    _activeSession = session;
    _activeDismissal = dismissal;
    return session;
  }

  void _unregister(Object session) {
    if (!identical(_activeSession, session)) {
      return;
    }
    _activeSession = null;
    _activeDismissal = null;
  }
}

/// Makes a [DesktopContextMenuController] available to application-owned
/// desktop context menus without subscribing event handlers to rebuilds.
final class DesktopContextMenuScope extends InheritedWidget {
  const DesktopContextMenuScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final DesktopContextMenuController controller;

  static DesktopContextMenuController? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<DesktopContextMenuScope>()
        ?.controller;
  }

  @override
  bool updateShouldNotify(DesktopContextMenuScope oldWidget) {
    return !identical(controller, oldWidget.controller);
  }
}

/// A platform-aware entry used by application-owned context menus.
sealed class DesktopMenuEntry<T> {
  const DesktopMenuEntry();
}

/// A selectable item in an application-owned desktop context menu.
final class DesktopMenuItem<T> extends DesktopMenuEntry<T> {
  const DesktopMenuItem({
    required this.value,
    required this.label,
    required this.symbol,
    this.shortcut,
    this.enabled = true,
    this.destructive = false,
    this.key,
  });

  final T value;
  final String label;
  final String symbol;
  final String? shortcut;
  final bool enabled;
  final bool destructive;
  final Key? key;
}

/// A visual separator in an application-owned desktop context menu.
final class DesktopMenuDivider<T> extends DesktopMenuEntry<T> {
  const DesktopMenuDivider();
}

/// Converts a global pointer coordinate into the overlay coordinate space used
/// by [showMenu], keeping desktop context menus anchored beside the pointer.
RelativeRect desktopContextMenuPosition(
  BuildContext context,
  Offset globalPosition,
) {
  final RenderBox overlay =
      Overlay.of(context).context.findRenderObject()! as RenderBox;
  final Offset localPosition = overlay.globalToLocal(globalPosition);
  return RelativeRect.fromRect(
    Rect.fromLTWH(localPosition.dx, localPosition.dy, 1, 1),
    Offset.zero & overlay.size,
  );
}

/// Shows a Flutter-owned context menu, using a Notion-like presentation on
/// Windows and the existing Material presentation on other platforms.
Future<T?> showDesktopContextMenu<T>({
  required BuildContext context,
  required Offset globalPosition,
  required List<DesktopMenuEntry<T>> entries,
}) async {
  final bool windows = defaultTargetPlatform == TargetPlatform.windows;
  final Brightness brightness = Theme.of(context).brightness;
  final bool dark = brightness == Brightness.dark;
  final List<PopupMenuEntry<T>> popupEntries = <PopupMenuEntry<T>>[];
  bool firstItem = true;
  for (final DesktopMenuEntry<T> entry in entries) {
    switch (entry) {
      case DesktopMenuItem<T>():
        popupEntries.add(
          windows
              ? _WindowsPopupMenuItem<T>(item: entry, marksMenuRoot: firstItem)
              : _materialPopupMenuItem(entry),
        );
        firstItem = false;
      case DesktopMenuDivider<T>():
        popupEntries.add(
          windows
              ? _WindowsPopupMenuDivider<T>(dark: dark)
              : const PopupMenuDivider(),
        );
    }
  }

  final bool reduceMotion =
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  final NavigatorState navigator = Navigator.of(context);
  final Future<T?> result = showMenu<T>(
    context: context,
    position: desktopContextMenuPosition(context, globalPosition),
    items: popupEntries,
    elevation: windows ? 2 : null,
    shadowColor: windows
        ? Colors.black.withValues(alpha: dark ? 0.24 : 0.1)
        : null,
    surfaceTintColor: windows ? Colors.transparent : null,
    shape: windows
        ? RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: dark ? const Color(0xFF3A3A38) : const Color(0x1A000000),
            ),
          )
        : null,
    menuPadding: windows ? const EdgeInsets.symmetric(vertical: 6) : null,
    color: windows
        ? (dark ? const Color(0xFF252523) : const Color(0xFFFCFCFB))
        : null,
    constraints: windows
        ? const BoxConstraints(
            minWidth: _windowsMenuMinWidth,
            maxWidth: _windowsMenuMaxWidth,
          )
        : null,
    clipBehavior: windows ? Clip.antiAlias : Clip.none,
    popUpAnimationStyle: windows && !reduceMotion
        ? const AnimationStyle(
            duration: Duration(milliseconds: 120),
            reverseDuration: Duration(milliseconds: 90),
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          )
        : AnimationStyle.noAnimation,
    requestFocus: true,
  );
  final DesktopContextMenuController? controller =
      DesktopContextMenuScope.maybeOf(context);
  Object? session;
  bool dismissalRequested = false;
  if (controller != null) {
    session = controller._register(() async {
      if (dismissalRequested) {
        return;
      }
      dismissalRequested = true;
      if (navigator.mounted && navigator.canPop()) {
        navigator.pop<T>();
      }
      await result;
    });
  }
  try {
    return await result;
  } finally {
    if (controller != null && session != null) {
      controller._unregister(session);
    }
  }
}

PopupMenuItem<T> _materialPopupMenuItem<T>(DesktopMenuItem<T> item) {
  return PopupMenuItem<T>(
    key: item.key,
    value: item.value,
    enabled: item.enabled,
    child: Row(
      children: <Widget>[
        PopupSymbolIcon(item.symbol, size: 17, color: PopupStyle.textSecondary),
        const SizedBox(width: 9),
        Expanded(child: Text(item.label, overflow: TextOverflow.ellipsis)),
        if (item.shortcut != null) ...<Widget>[
          const SizedBox(width: 16),
          Text(item.shortcut!),
        ],
      ],
    ),
  );
}

final class _WindowsPopupMenuItem<T> extends PopupMenuEntry<T> {
  const _WindowsPopupMenuItem({
    required this.item,
    required this.marksMenuRoot,
  });

  final DesktopMenuItem<T> item;
  final bool marksMenuRoot;

  @override
  double get height => _windowsMenuItemHeight;

  @override
  bool represents(T? value) => item.value == value;

  @override
  State<_WindowsPopupMenuItem<T>> createState() =>
      _WindowsPopupMenuItemState<T>();
}

final class _WindowsPopupMenuItemState<T>
    extends State<_WindowsPopupMenuItem<T>> {
  void _select() {
    if (widget.item.enabled) {
      Navigator.pop<T>(context, widget.item.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final DesktopMenuItem<T> item = widget.item;
    final Color foreground = dark
        ? const Color(0xFFE7E7E5)
        : const Color(0xFF37352F);
    final Color muted = dark
        ? const Color(0xFF9B9B98)
        : const Color(0xFF9B9A97);
    final Color disabled = muted.withValues(alpha: 0.55);
    final Color effectiveForeground = item.enabled ? foreground : disabled;
    final Color hover = dark
        ? const Color(0xFF343432)
        : const Color(0x0D000000);

    return Padding(
      key: widget.marksMenuRoot ? const Key('windows-context-menu') : null,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Semantics(
        button: true,
        enabled: item.enabled,
        child: InkWell(
          key: item.key,
          onTap: item.enabled ? _select : null,
          canRequestFocus: item.enabled,
          borderRadius: BorderRadius.circular(6),
          hoverColor: hover,
          focusColor: hover,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          mouseCursor: item.enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: SizedBox(
            height: _windowsMenuItemHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: <Widget>[
                  PopupSymbolIcon(
                    item.symbol,
                    size: 16,
                    color: effectiveForeground,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: effectiveForeground,
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        height: 1.15,
                      ),
                    ),
                  ),
                  if (item.shortcut != null) ...<Widget>[
                    const SizedBox(width: 16),
                    Text(
                      item.shortcut!,
                      style: TextStyle(
                        color: item.enabled ? muted : disabled,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _WindowsPopupMenuDivider<T> extends PopupMenuEntry<T> {
  const _WindowsPopupMenuDivider({required this.dark});

  final bool dark;

  @override
  double get height => 7;

  @override
  bool represents(T? value) => false;

  @override
  State<_WindowsPopupMenuDivider<T>> createState() =>
      _WindowsPopupMenuDividerState<T>();
}

final class _WindowsPopupMenuDividerState<T>
    extends State<_WindowsPopupMenuDivider<T>> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: ColoredBox(
        color: widget.dark ? const Color(0xFF3A3A38) : const Color(0x14000000),
      ),
    );
  }
}
