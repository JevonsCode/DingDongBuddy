import 'dart:async';

import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:flutter/material.dart';

const double _desktopMenuMinWidth = 252;
const double _desktopMenuMaxWidth = 280;
const double _desktopMenuItemHeight = 32;

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

/// Compact anchored menu trigger that reuses DingDong's desktop menu surface.
class DesktopMenuButton<T> extends StatelessWidget {
  const DesktopMenuButton({
    required this.tooltip,
    required this.entries,
    required this.onSelected,
    this.icon = const Icon(Icons.more_horiz_rounded),
    super.key,
  });

  final String tooltip;
  final List<DesktopMenuEntry<T>> entries;
  final ValueChanged<T> onSelected;
  final Widget icon;

  Future<void> _open(BuildContext anchorContext) async {
    final RenderBox anchor = anchorContext.findRenderObject()! as RenderBox;
    final Offset position = anchor.localToGlobal(
      Offset(0, anchor.size.height + 4),
    );
    final T? value = await showDesktopContextMenu<T>(
      context: anchorContext,
      globalPosition: position,
      entries: entries,
    );
    if (value != null && anchorContext.mounted) {
      onSelected(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (BuildContext anchorContext) => DesktopIconButton(
        tooltip: tooltip,
        onPressed: () => unawaited(_open(anchorContext)),
        icon: icon,
      ),
    );
  }
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

/// Shows the same restrained DingDong menu on every desktop platform.
Future<T?> showDesktopContextMenu<T>({
  required BuildContext context,
  required Offset globalPosition,
  required List<DesktopMenuEntry<T>> entries,
}) async {
  final Brightness brightness = Theme.of(context).brightness;
  final bool dark = brightness == Brightness.dark;
  final List<PopupMenuEntry<T>> popupEntries = <PopupMenuEntry<T>>[];
  bool firstItem = true;
  for (final DesktopMenuEntry<T> entry in entries) {
    switch (entry) {
      case DesktopMenuItem<T>():
        popupEntries.add(
          _DesktopPopupMenuItem<T>(item: entry, marksMenuRoot: firstItem),
        );
        firstItem = false;
      case DesktopMenuDivider<T>():
        popupEntries.add(_DesktopPopupMenuDivider<T>(dark: dark));
    }
  }

  final bool reduceMotion =
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  final NavigatorState navigator = Navigator.of(context);
  final Completer<Route<dynamic>?> menuRoute = Completer<Route<dynamic>?>();
  final List<PopupMenuEntry<T>> trackedEntries = popupEntries
      .map(
        (PopupMenuEntry<T> entry) => _RouteTrackingPopupMenuEntry<T>(
          entry: entry,
          onRouteAvailable: (Route<dynamic> route) {
            if (!menuRoute.isCompleted) {
              menuRoute.complete(route);
            }
          },
        ),
      )
      .toList(growable: false);
  final Future<T?> result = showMenu<T>(
    context: context,
    position: desktopContextMenuPosition(context, globalPosition),
    items: trackedEntries,
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: dark ? 0.24 : 0.1),
    surfaceTintColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(10),
      side: BorderSide(
        color: dark ? const Color(0xFF3A3A38) : const Color(0x1A000000),
      ),
    ),
    menuPadding: const EdgeInsets.symmetric(vertical: 6),
    color: dark ? const Color(0xFF252523) : const Color(0xFFFCFCFB),
    constraints: const BoxConstraints(
      minWidth: _desktopMenuMinWidth,
      maxWidth: _desktopMenuMaxWidth,
    ),
    clipBehavior: Clip.antiAlias,
    popUpAnimationStyle: !reduceMotion
        ? const AnimationStyle(
            duration: Duration(milliseconds: 120),
            reverseDuration: Duration(milliseconds: 90),
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          )
        : AnimationStyle.noAnimation,
    requestFocus: true,
  );
  unawaited(
    result.then<void>(
      (_) {
        if (!menuRoute.isCompleted) {
          menuRoute.complete(null);
        }
      },
      onError: (Object _, StackTrace _) {
        if (!menuRoute.isCompleted) {
          menuRoute.complete(null);
        }
      },
    ),
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
      final Route<dynamic>? activeMenuRoute = await menuRoute.future;
      if (navigator.mounted && activeMenuRoute?.isActive == true) {
        navigator.removeRoute(activeMenuRoute!);
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

final class _RouteTrackingPopupMenuEntry<T> extends PopupMenuEntry<T> {
  const _RouteTrackingPopupMenuEntry({
    required this.entry,
    required this.onRouteAvailable,
  });

  final PopupMenuEntry<T> entry;
  final ValueChanged<Route<dynamic>> onRouteAvailable;

  @override
  double get height => entry.height;

  @override
  bool represents(T? value) => entry.represents(value);

  @override
  State<_RouteTrackingPopupMenuEntry<T>> createState() =>
      _RouteTrackingPopupMenuEntryState<T>();
}

final class _RouteTrackingPopupMenuEntryState<T>
    extends State<_RouteTrackingPopupMenuEntry<T>> {
  @override
  Widget build(BuildContext context) {
    final ModalRoute<dynamic>? route = ModalRoute.of(context);
    if (route != null) {
      widget.onRouteAvailable(route);
    }
    return widget.entry;
  }
}

final class _DesktopPopupMenuItem<T> extends PopupMenuEntry<T> {
  const _DesktopPopupMenuItem({
    required this.item,
    required this.marksMenuRoot,
  });

  final DesktopMenuItem<T> item;
  final bool marksMenuRoot;

  @override
  double get height => _desktopMenuItemHeight;

  @override
  bool represents(T? value) => item.value == value;

  @override
  State<_DesktopPopupMenuItem<T>> createState() =>
      _DesktopPopupMenuItemState<T>();
}

final class _DesktopPopupMenuItemState<T>
    extends State<_DesktopPopupMenuItem<T>> {
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
    final Color destructive = dark
        ? const Color(0xFFFF746C)
        : const Color(0xFFC83B35);
    final Color effectiveForeground = item.enabled
        ? (item.destructive ? destructive : foreground)
        : disabled;
    final Color hover = dark
        ? const Color(0xFF343432)
        : const Color(0x0D000000);

    return Padding(
      key: widget.marksMenuRoot ? const Key('desktop-context-menu') : null,
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
            height: _desktopMenuItemHeight,
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

final class _DesktopPopupMenuDivider<T> extends PopupMenuEntry<T> {
  const _DesktopPopupMenuDivider({required this.dark});

  final bool dark;

  @override
  double get height => 7;

  @override
  bool represents(T? value) => false;

  @override
  State<_DesktopPopupMenuDivider<T>> createState() =>
      _DesktopPopupMenuDividerState<T>();
}

final class _DesktopPopupMenuDividerState<T>
    extends State<_DesktopPopupMenuDivider<T>> {
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
