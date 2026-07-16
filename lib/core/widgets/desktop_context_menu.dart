import 'package:flutter/material.dart';

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
