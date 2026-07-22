import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/platform/desktop_platform_policy.dart';
import 'package:dingdong/core/theme/popup_style.dart';
import 'package:dingdong/core/widgets/popup_symbol_icon.dart';
import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:dingdong/features/shell/ui/popup_mascot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Branded header and three-workspace switcher for the callout interface.
class PopupHeader extends StatelessWidget {
  const PopupHeader({
    required this.selectedIndex,
    required this.issueCount,
    required this.updateAvailable,
    required this.showShortcutHints,
    required this.onSelected,
    required this.onIssues,
    required this.onBrand,
    required this.onSettings,
    required this.onVersion,
    this.onStartDragging,
    this.onHide,
    super.key,
  });

  final int selectedIndex;
  final int issueCount;
  final bool updateAvailable;
  final bool showShortcutHints;
  final ValueChanged<int> onSelected;
  final VoidCallback onIssues;
  final VoidCallback onBrand;
  final VoidCallback onSettings;
  final VoidCallback onVersion;
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
                          Expanded(
                            child: Row(
                              children: <Widget>[
                                Flexible(
                                  child: Semantics(
                                    button: true,
                                    child: GestureDetector(
                                      key: const Key('popup-brand-sound'),
                                      behavior: HitTestBehavior.opaque,
                                      onTap: onBrand,
                                      child: const Text(
                                        'DingDong',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: PopupStyle.textPrimary,
                                          fontSize: 17,
                                          height: 1,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: _VersionButton(
                                    updateAvailable: updateAvailable,
                                    onPressed: onVersion,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox.square(
                    dimension: 32,
                    child: issueCount > 0
                        ? _IssueButton(count: issueCount, onPressed: onIssues)
                        : null,
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
                    contentKey: const Key('popup-tab-content-0'),
                    selected: selectedIndex == 0,
                    symbol: 'today',
                    label: context.localized('Dynamic', '动态'),
                    shortcut: _shortcut('Q'),
                    showShortcut: showShortcutHints,
                    onPressed: () => onSelected(0),
                  ),
                  const SizedBox(width: 6),
                  _WorkspaceTab(
                    key: const Key('popup-tab-1'),
                    contentKey: const Key('popup-tab-content-1'),
                    selected: selectedIndex == 1,
                    symbol: 'library',
                    label: context.localized('Library', '资源库'),
                    shortcut: _shortcut('W'),
                    showShortcut: showShortcutHints,
                    onPressed: () => onSelected(1),
                  ),
                  const SizedBox(width: 6),
                  _WorkspaceTab(
                    key: const Key('popup-tab-2'),
                    contentKey: const Key('popup-tab-content-2'),
                    selected: selectedIndex == 2,
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

class _VersionButton extends StatelessWidget {
  const _VersionButton({
    required this.updateAvailable,
    required this.onPressed,
  });

  final bool updateAvailable;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        key: const Key('popup-app-version'),
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text(
                'v$currentAppVersion',
                key: Key('app-version-$currentAppVersion'),
                style: TextStyle(
                  color: PopupStyle.textSecondary,
                  fontSize: 9,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (updateAvailable) ...<Widget>[
                const SizedBox(width: 3),
                Container(
                  key: const Key('popup-version-update-dot'),
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: PopupStyle.mcp,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
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

class _IssueButton extends StatelessWidget {
  const _IssueButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      key: const Key('popup-issues'),
      tooltip: context.localized(
        '$count issues need attention',
        '$count 个问题需要处理',
      ),
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
        backgroundColor: const Color(0xFFFFF3F1),
        foregroundColor: const Color(0xFFB93A32),
        side: const BorderSide(color: Color(0xFFF1C8C3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      icon: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, size: 17),
          if (count > 1)
            Positioned(
              top: -7,
              right: -9,
              child: Container(
                key: const Key('popup-issue-count'),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFB93A32),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: PopupStyle.surface, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    height: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WorkspaceTab extends StatelessWidget {
  const _WorkspaceTab({
    required this.selected,
    required this.contentKey,
    required this.symbol,
    required this.label,
    required this.shortcut,
    required this.showShortcut,
    required this.onPressed,
    super.key,
  });

  final bool selected;
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
                          child: PopupSymbolIcon(
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
