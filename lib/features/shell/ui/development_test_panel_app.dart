import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

/// Small DEV-only surface for previewing real menu-bar mascot states and motion.
class DevelopmentTestPanelApp extends StatefulWidget {
  const DevelopmentTestPanelApp({
    required this.settings,
    required this.animationsSupported,
    required this.onSleeping,
    required this.onNudge,
    this.windowController,
    super.key,
  });

  final AppSettings settings;
  final bool animationsSupported;
  final Future<void> Function() onSleeping;
  final Future<void> Function() onNudge;
  final WindowController? windowController;

  @override
  State<DevelopmentTestPanelApp> createState() =>
      _DevelopmentTestPanelAppState();
}

class _DevelopmentTestPanelAppState extends State<DevelopmentTestPanelApp> {
  @override
  void initState() {
    super.initState();
    final WindowController? controller = widget.windowController;
    if (controller != null) {
      unawaited(
        controller.setWindowMethodHandler((call) async {
          if (call.method == 'window_focus') {
            await windowManager.focus();
          }
        }),
      );
    }
  }

  @override
  void dispose() {
    final WindowController? controller = widget.windowController;
    if (controller != null) {
      unawaited(controller.setWindowMethodHandler(null));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings settings = widget.settings;
    return MaterialApp(
      title: 'DingDong DEV · Test Panel',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.desktopPanelLight(),
      darkTheme: AppTheme.desktopPanelDark(),
      themeMode: switch (settings.themeMode) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      },
      locale: switch (settings.language) {
        AppLanguagePreference.system => null,
        AppLanguagePreference.english => const Locale('en'),
        AppLanguagePreference.chinese => const Locale('zh'),
      },
      supportedLocales: const <Locale>[Locale('en'), Locale('zh')],
      localizationsDelegates: const <LocalizationsDelegate<Object>>[
        DingDongLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: _DevelopmentTestPanel(
        animationsSupported: widget.animationsSupported,
        onSleeping: widget.onSleeping,
        onNudge: widget.onNudge,
      ),
    );
  }
}

class _DevelopmentTestPanel extends StatefulWidget {
  const _DevelopmentTestPanel({
    required this.animationsSupported,
    required this.onSleeping,
    required this.onNudge,
  });

  final bool animationsSupported;
  final Future<void> Function() onSleeping;
  final Future<void> Function() onNudge;

  @override
  State<_DevelopmentTestPanel> createState() => _DevelopmentTestPanelState();
}

class _DevelopmentTestPanelState extends State<_DevelopmentTestPanel> {
  bool _running = false;
  String? _lastAction;
  bool _failed = false;

  Future<void> _trigger({
    required String action,
    required Future<void> Function() callback,
  }) async {
    if (_running || !widget.animationsSupported) {
      return;
    }
    setState(() {
      _running = true;
      _failed = false;
    });
    try {
      await callback();
      if (mounted) {
        setState(() => _lastAction = action);
      }
    } on Object {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) {
        setState(() => _running = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      context.localized('Test Panel', '测试面板'),
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.22),
                      ),
                    ),
                    child: Text(
                      'DEV',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                context.localized(
                  'Trigger the real menu-bar mascot animations without creating reminders or clipboard records.',
                  '直接触发真实的菜单栏状态图标和提醒动画，不会创建提醒或剪贴板记录。',
                ),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              _AnimationTestCard(
                title: context.localized('Sleeping state', '睡眠状态'),
                description: context.localized(
                  'Show the sleeping mascot briefly, then restore the current state.',
                  '短暂显示睡眠小人，然后恢复当前状态。',
                ),
                buttonLabel: context.localized('Test sleeping state', '测试睡眠状态'),
                buttonKey: const Key('dev-test-panel-sleeping'),
                icon: Icons.bedtime_outlined,
                onPressed: !_running && widget.animationsSupported
                    ? () => unawaited(
                        _trigger(
                          action: 'sleeping',
                          callback: widget.onSleeping,
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 12),
              _AnimationTestCard(
                title: context.localized('Horizontal nudge', '左右摇动'),
                description: context.localized(
                  'Move the status mascot horizontally, like an overdue reminder.',
                  '让状态小人水平左右摇动，模拟提醒超时状态。',
                ),
                buttonLabel: context.localized('Test nudge', '测试左右摇动'),
                buttonKey: const Key('dev-test-panel-nudge'),
                icon: Icons.swap_horiz_rounded,
                onPressed: !_running && widget.animationsSupported
                    ? () => unawaited(
                        _trigger(action: 'nudge', callback: widget.onNudge),
                      )
                    : null,
              ),
              const Spacer(),
              if (!widget.animationsSupported)
                Text(
                  context.localized(
                    'Status mascot previews are currently available on macOS only.',
                    '状态小人预览目前仅支持 macOS。',
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                )
              else if (_failed)
                Text(
                  context.localized(
                    'The preview could not be triggered.',
                    '预览触发失败。',
                  ),
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: colors.error),
                )
              else if (_lastAction != null)
                Text(
                  _lastAction == 'sleeping'
                      ? context.localized(
                          'Triggered: sleeping state',
                          '已触发：睡眠状态',
                        )
                      : context.localized(
                          'Triggered: horizontal nudge',
                          '已触发：左右摇动',
                        ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimationTestCard extends StatelessWidget {
  const _AnimationTestCard({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.buttonKey,
    required this.icon,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final Key buttonKey;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 22, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          KeyedSubtree(
            key: buttonKey,
            child: DesktopActionButton(
              label: buttonLabel,
              tone: DesktopActionTone.soft,
              onPressed: onPressed,
            ),
          ),
        ],
      ),
    );
  }
}
