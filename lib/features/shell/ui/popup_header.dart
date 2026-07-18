import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/desktop_platform_policy.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:dingdong/features/shell/ui/popup_mascot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Branded header and three-workspace switcher for the callout interface.
class PopupHeader extends StatelessWidget {
  const PopupHeader({
    required this.selectedIndex,
    required this.loadingIndex,
    required this.showShortcutHints,
    required this.onSelected,
    required this.onRefresh,
    required this.onSettings,
    this.onStartDragging,
    this.onHide,
    super.key,
  });

  final int selectedIndex;
  final int? loadingIndex;
  final bool showShortcutHints;
  final ValueChanged<int> onSelected;
  final VoidCallback onRefresh;
  final VoidCallback onSettings;
  final Future<void> Function()? onStartDragging;
  final Future<void> Function()? onHide;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 108,
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: PopupStyle.border)),
      ),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 55,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 17, 7),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: GestureDetector(
                      key: const Key('popup-drag-region'),
                      behavior: HitTestBehavior.opaque,
                      onPanStart: onStartDragging == null
                          ? null
                          : (_) => unawaited(onStartDragging!()),
                      child: Row(
                        children: <Widget>[
                          const PopupMascot(),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'DingDong',
                              style: TextStyle(
                                color: PopupStyle.textPrimary,
                                fontSize: 17,
                                height: 1,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _HeaderButton(
                    key: const Key('popup-refresh'),
                    tooltip: context.localized('Refresh', '刷新'),
                    symbol: 'refresh',
                    onPressed: onRefresh,
                  ),
                  const SizedBox(width: 12),
                  _HeaderButton(
                    key: const Key('popup-open-settings'),
                    tooltip: context.localized('Settings', '设置'),
                    symbol: 'settings',
                    onPressed: onSettings,
                  ),
                  const SizedBox(width: 12),
                  _HeaderButton(
                    key: const Key('popup-hide'),
                    tooltip: context.localized('Hide', '收起'),
                    symbol: 'collapse',
                    onPressed: onHide == null ? null : () => onHide!(),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              key: const Key('popup-tab-bar'),
              padding: const EdgeInsets.fromLTRB(17, 5, 17, 12),
              child: Row(
                children: <Widget>[
                  _WorkspaceTab(
                    key: const Key('popup-tab-0'),
                    index: 0,
                    contentKey: const Key('popup-tab-content-0'),
                    selected: selectedIndex == 0,
                    loading: loadingIndex == 0,
                    symbol: 'today',
                    label: context.localized('Dynamic', '动态'),
                    shortcut: _shortcut('Q'),
                    showShortcut: showShortcutHints,
                    onPressed: () => onSelected(0),
                  ),
                  const SizedBox(width: 6),
                  _WorkspaceTab(
                    key: const Key('popup-tab-1'),
                    index: 1,
                    contentKey: const Key('popup-tab-content-1'),
                    selected: selectedIndex == 1,
                    loading: loadingIndex == 1,
                    symbol: 'library',
                    label: context.localized('Library', '资源库'),
                    shortcut: _shortcut('W'),
                    showShortcut: showShortcutHints,
                    onPressed: () => onSelected(1),
                  ),
                  const SizedBox(width: 6),
                  _WorkspaceTab(
                    key: const Key('popup-tab-2'),
                    index: 2,
                    contentKey: const Key('popup-tab-content-2'),
                    selected: selectedIndex == 2,
                    loading: loadingIndex == 2,
                    symbol: 'clipboard',
                    label: context.localized('Clipboard', '剪贴板'),
                    shortcut: _shortcut('E'),
                    showShortcut: showShortcutHints,
                    onPressed: () => onSelected(2),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _shortcut(String key) {
  return primaryShortcutLabel(key, defaultTargetPlatform);
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({
    required this.tooltip,
    required this.symbol,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final String symbol;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      style: IconButton.styleFrom(
        fixedSize: const Size.square(32),
        minimumSize: const Size.square(32),
        maximumSize: const Size.square(32),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
        backgroundColor: PopupStyle.surface,
        foregroundColor: PopupStyle.textSecondary,
        side: const BorderSide(color: PopupStyle.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: PopupSymbolIcon(symbol, size: 16, color: PopupStyle.textSecondary),
    );
  }
}

class _WorkspaceTab extends StatelessWidget {
  const _WorkspaceTab({
    required this.index,
    required this.selected,
    required this.loading,
    required this.contentKey,
    required this.symbol,
    required this.label,
    required this.shortcut,
    required this.showShortcut,
    required this.onPressed,
    super.key,
  });

  final int index;
  final bool selected;
  final bool loading;
  final Key contentKey;
  final String symbol;
  final String label;
  final String shortcut;
  final bool showShortcut;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 36),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          backgroundColor: selected
              ? PopupStyle.accentSoft
              : PopupStyle.surface,
          foregroundColor: selected
              ? PopupStyle.accent
              : PopupStyle.textSecondary,
          side: BorderSide(
            color: selected
                ? PopupStyle.accent.withValues(alpha: 0.25)
                : PopupStyle.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            AnimatedPadding(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.only(
                left: showShortcut ? 2 : 0,
                right: showShortcut ? 46 : 0,
              ),
              child: Center(
                child: FittedBox(
                  key: contentKey,
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      SizedBox.square(
                        dimension: 17,
                        child: Center(
                          child: loading
                              ? SizedBox.square(
                                  key: Key('popup-tab-loading-$index'),
                                  dimension: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 1.7,
                                    strokeCap: StrokeCap.round,
                                    color: PopupStyle.accent,
                                  ),
                                )
                              : PopupSymbolIcon(
                                  symbol,
                                  size: 17,
                                  color: selected
                                      ? PopupStyle.accent
                                      : PopupStyle.textSecondary,
                                ),
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        label,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (showShortcut)
              Positioned(
                right: 10,
                top: 0,
                bottom: 0,
                child: Center(
                  child: SizedBox(
                    width: 34,
                    child: Text(
                      shortcut,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: selected
                            ? PopupStyle.accent.withValues(alpha: 0.86)
                            : PopupStyle.textTertiary,
                        fontFamily: 'monospace',
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
