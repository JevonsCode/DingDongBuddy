import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/platform/windows_auxiliary_window_close_behavior.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/features/shell/domain/development_test_action.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:window_manager/window_manager.dart';

/// DEV-only surface for exercising real desktop and device-link paths.
class DevelopmentTestPanelApp extends StatefulWidget {
  const DevelopmentTestPanelApp({
    required this.settings,
    required this.animationsSupported,
    required this.onRun,
    this.windowController,
    super.key,
  });

  final AppSettings settings;
  final bool animationsSupported;
  final Future<void> Function(DevelopmentTestAction action) onRun;
  final WindowController? windowController;

  @override
  State<DevelopmentTestPanelApp> createState() =>
      _DevelopmentTestPanelAppState();
}

class _DevelopmentTestPanelAppState extends State<DevelopmentTestPanelApp>
    with
        WindowListener,
        WindowsAuxiliaryWindowCloseBehavior<DevelopmentTestPanelApp> {
  @override
  void initState() {
    super.initState();
    enableWindowsHideOnClose();
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
        onRun: widget.onRun,
      ),
    );
  }
}

class _DevelopmentTestPanel extends StatefulWidget {
  const _DevelopmentTestPanel({
    required this.animationsSupported,
    required this.onRun,
  });

  final bool animationsSupported;
  final Future<void> Function(DevelopmentTestAction action) onRun;

  @override
  State<_DevelopmentTestPanel> createState() => _DevelopmentTestPanelState();
}

class _DevelopmentTestPanelState extends State<_DevelopmentTestPanel> {
  DevelopmentTestAction? _runningAction;
  DevelopmentTestAction? _lastAction;
  bool _failed = false;

  Future<void> _trigger(DevelopmentTestAction action) async {
    if (_runningAction != null ||
        (action.requiresTrayAnimation && !widget.animationsSupported)) {
      return;
    }
    setState(() {
      _runningAction = action;
      _failed = false;
    });
    try {
      await widget.onRun(action);
      if (mounted) {
        setState(() => _lastAction = action);
      }
    } on Object {
      if (mounted) {
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) {
        setState(() => _runningAction = null);
      }
    }
  }

  VoidCallback? _callbackFor(DevelopmentTestAction action) {
    if (_runningAction != null ||
        (action.requiresTrayAnimation && !widget.animationsSupported)) {
      return null;
    }
    return () => unawaited(_trigger(action));
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          key: const Key('dev-test-panel-list'),
          padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
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
                'Exercise real DingDong integration paths from one place.',
                '从一个窗口直接验收 DingDong 的真实集成链路。',
              ),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _TestDataNotice(colors: colors),
            const SizedBox(height: 22),
            _TestSection(
              title: context.localized('Menu-bar mascot', '状态小人'),
              description: context.localized(
                'Preview real tray states without creating history records.',
                '预览真实菜单栏状态，不创建历史记录。',
              ),
              cards: <Widget>[
                _TestCard(
                  title: context.localized('Sleeping state', '睡眠状态'),
                  description: context.localized(
                    'Show the sleeping mascot briefly, then restore the current state.',
                    '短暂显示睡眠小人，然后恢复当前状态。',
                  ),
                  buttonLabel: context.localized('Run', '测试'),
                  buttonKey: const Key('dev-test-panel-sleeping'),
                  icon: Icons.bedtime_outlined,
                  running: _runningAction == DevelopmentTestAction.traySleeping,
                  onPressed: _callbackFor(DevelopmentTestAction.traySleeping),
                ),
                _TestCard(
                  title: context.localized('Horizontal nudge', '左右摇动'),
                  description: context.localized(
                    'Nudge the tray mascot like an overdue reminder.',
                    '让菜单栏小人左右摇动，模拟超时提醒。',
                  ),
                  buttonLabel: context.localized('Run', '测试'),
                  buttonKey: const Key('dev-test-panel-nudge'),
                  icon: Icons.swap_horiz_rounded,
                  running: _runningAction == DevelopmentTestAction.trayNudge,
                  onPressed: _callbackFor(DevelopmentTestAction.trayNudge),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _TestSection(
              title: context.localized('Agent alerts', 'Agent 提醒'),
              description: context.localized(
                'Uses the real local /ding route, unread badge, native alert, and connected-phone delivery.',
                '走真实本地 /ding、未读角标、系统提醒和已连接手机分发链路。',
              ),
              cards: <Widget>[
                _TestCard(
                  title: context.localized('Basic completion', '基础完成提醒'),
                  description: context.localized(
                    'Create one clearly labeled DEV completion.',
                    '生成一条明确标注为 DEV 的完成提醒。',
                  ),
                  buttonLabel: context.localized('Notify', '发送提醒'),
                  buttonKey: const Key('dev-test-panel-agent-basic'),
                  icon: Icons.notifications_active_outlined,
                  running:
                      _runningAction == DevelopmentTestAction.agentCompletion,
                  onPressed: _callbackFor(
                    DevelopmentTestAction.agentCompletion,
                  ),
                ),
                _TestCard(
                  title: context.localized('Rich mobile detail', '手机长描述'),
                  description: context.localized(
                    'Test a concise summary plus a longer mobile detail body.',
                    '测试简短摘要与手机端较长详情正文。',
                  ),
                  buttonLabel: context.localized('Notify', '发送提醒'),
                  buttonKey: const Key('dev-test-panel-agent-rich'),
                  icon: Icons.subject_rounded,
                  running:
                      _runningAction ==
                      DevelopmentTestAction.agentRichCompletion,
                  onPressed: _callbackFor(
                    DevelopmentTestAction.agentRichCompletion,
                  ),
                ),
                _TestCard(
                  title: context.localized('Three-alert burst', '连续三条提醒'),
                  description: context.localized(
                    'Check unread counting, ordering, and repeated phone delivery.',
                    '检查未读数字、列表顺序和手机连续接收。',
                  ),
                  buttonLabel: context.localized('Send 3', '发送 3 条'),
                  buttonKey: const Key('dev-test-panel-agent-burst'),
                  icon: Icons.filter_3_rounded,
                  running: _runningAction == DevelopmentTestAction.agentBurst,
                  onPressed: _callbackFor(DevelopmentTestAction.agentBurst),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _TestSection(
              title: context.localized('Clipboard and devices', '剪贴板与设备'),
              description: context.localized(
                'Creates removable DEV samples or opens the real device workflow.',
                '创建可删除的 DEV 样例，或打开真实设备流程。',
              ),
              cards: <Widget>[
                _TestCard(
                  title: context.localized('Text from phone', '来自手机的文字'),
                  description: context.localized(
                    'MOCK: add a phone-origin text row without reading any phone clipboard.',
                    'MOCK：添加一条手机来源文字；不会读取手机剪贴板。',
                  ),
                  buttonLabel: context.localized('Create', '创建样例'),
                  buttonKey: const Key('dev-test-panel-phone-text'),
                  icon: Icons.phone_iphone_rounded,
                  running:
                      _runningAction ==
                      DevelopmentTestAction.phoneClipboardText,
                  onPressed: _callbackFor(
                    DevelopmentTestAction.phoneClipboardText,
                  ),
                ),
                _TestCard(
                  title: context.localized('File from phone', '来自手机的文件'),
                  description: context.localized(
                    'MOCK: create a small local file and show its device source.',
                    'MOCK：创建一个小型本地文件并展示设备来源。',
                  ),
                  buttonLabel: context.localized('Create', '创建样例'),
                  buttonKey: const Key('dev-test-panel-phone-file'),
                  icon: Icons.attach_file_rounded,
                  running:
                      _runningAction ==
                      DevelopmentTestAction.phoneClipboardFile,
                  onPressed: _callbackFor(
                    DevelopmentTestAction.phoneClipboardFile,
                  ),
                ),
                _TestCard(
                  title: context.localized('One-way auto send', '单向自动同步'),
                  description: context.localized(
                    'Create a computer record and send it only to connected devices with auto-send enabled.',
                    '创建电脑记录，只发送给已连接且开启自动同步的设备。',
                  ),
                  buttonLabel: context.localized('Create and send', '创建并发送'),
                  buttonKey: const Key('dev-test-panel-auto-send'),
                  icon: Icons.arrow_forward_rounded,
                  running:
                      _runningAction == DevelopmentTestAction.autoSendClipboard,
                  onPressed: _callbackFor(
                    DevelopmentTestAction.autoSendClipboard,
                  ),
                ),
                _TestCard(
                  title: context.localized('Send to device dialog', '发送到设备弹框'),
                  description: context.localized(
                    'Create a sample and open the real target-device chooser.',
                    '创建样例并打开真实的目标设备选择弹框。',
                  ),
                  buttonLabel: context.localized('Open', '打开'),
                  buttonKey: const Key('dev-test-panel-manual-share'),
                  icon: Icons.send_to_mobile_outlined,
                  running:
                      _runningAction == DevelopmentTestAction.manualDeviceShare,
                  onPressed: _callbackFor(
                    DevelopmentTestAction.manualDeviceShare,
                  ),
                ),
                _TestCard(
                  title: context.localized('Connection manager', '连接管理窗口'),
                  description: context.localized(
                    'Open the standalone QR, device, switch, disconnect, and delete surface.',
                    '打开独立二维码、设备、开关、断连和删除窗口。',
                  ),
                  buttonLabel: context.localized('Open', '打开'),
                  buttonKey: const Key('dev-test-panel-device-manager'),
                  icon: Icons.devices_other_rounded,
                  running:
                      _runningAction == DevelopmentTestAction.openDeviceManager,
                  onPressed: _callbackFor(
                    DevelopmentTestAction.openDeviceManager,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            if (!widget.animationsSupported)
              Text(
                context.localized(
                  'Tray mascot previews are unavailable on this platform; the other integration tests remain available.',
                  '当前平台不支持状态小人预览；其余集成测试仍可使用。',
                ),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
              ),
            if (_failed || _lastAction != null || _runningAction != null) ...[
              const SizedBox(height: 12),
              _ActionStatus(
                failed: _failed,
                runningAction: _runningAction,
                lastAction: _lastAction,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TestDataNotice extends StatelessWidget {
  const _TestDataNotice({required this.colors});

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('dev-test-panel-data-notice'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.tertiaryContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.tertiary.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.science_outlined, size: 20, color: colors.tertiary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              context.localized(
                'Agent and clipboard items created here are explicit DEV test data. Phone-origin samples are simulations, never captured from a real phone clipboard.',
                '这里创建的 Agent 与剪贴板条目都是明确的 DEV 测试数据；“手机来源”样例为模拟数据，绝不会读取真实手机剪贴板。',
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TestSection extends StatelessWidget {
  const _TestSection({
    required this.title,
    required this.description,
    required this.cards,
  });

  final String title;
  final String description;
  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            const double gap = 12;
            final int columns = constraints.maxWidth >= 680 ? 2 : 1;
            final double width = columns == 1
                ? constraints.maxWidth
                : (constraints.maxWidth - gap) / 2;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: cards
                  .map((Widget card) => SizedBox(width: width, child: card))
                  .toList(growable: false),
            );
          },
        ),
      ],
    );
  }
}

class _TestCard extends StatelessWidget {
  const _TestCard({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.buttonKey,
    required this.icon,
    required this.running,
    required this.onPressed,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final Key buttonKey;
  final IconData icon;
  final bool running;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 154),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 21, color: colors.primary),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colors.onSurfaceVariant,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: KeyedSubtree(
              key: buttonKey,
              child: DesktopActionButton(
                label: running
                    ? context.localized('Running…', '执行中…')
                    : buttonLabel,
                tone: DesktopActionTone.soft,
                onPressed: onPressed,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionStatus extends StatelessWidget {
  const _ActionStatus({
    required this.failed,
    required this.runningAction,
    required this.lastAction,
  });

  final bool failed;
  final DevelopmentTestAction? runningAction;
  final DevelopmentTestAction? lastAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final bool running = runningAction != null;
    final Color color = failed ? colors.error : colors.primary;
    final String label = failed
        ? context.localized(
            'The test failed. Check the connection and system permissions.',
            '测试执行失败，请检查连接状态和系统权限。',
          )
        : running
        ? context.localized('Running test…', '正在执行测试…')
        : _successLabel(context, lastAction!);
    return Container(
      key: const Key('dev-test-panel-action-status'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          if (running)
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            )
          else
            Icon(
              failed ? Icons.error_outline_rounded : Icons.check_rounded,
              size: 18,
              color: color,
            ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _successLabel(BuildContext context, DevelopmentTestAction action) {
  return switch (action) {
    DevelopmentTestAction.traySleeping => context.localized(
      'Triggered: sleeping state',
      '已触发：睡眠状态',
    ),
    DevelopmentTestAction.trayNudge => context.localized(
      'Triggered: horizontal nudge',
      '已触发：左右摇动',
    ),
    DevelopmentTestAction.agentCompletion => context.localized(
      'Created: basic Agent completion',
      '已创建：基础 Agent 完成提醒',
    ),
    DevelopmentTestAction.agentRichCompletion => context.localized(
      'Created: rich mobile Agent detail',
      '已创建：手机端长描述 Agent 提醒',
    ),
    DevelopmentTestAction.agentBurst => context.localized(
      'Created: three Agent completions',
      '已创建：连续三条 Agent 提醒',
    ),
    DevelopmentTestAction.phoneClipboardText => context.localized(
      'Created: simulated phone text row',
      '已创建：模拟手机文字记录',
    ),
    DevelopmentTestAction.phoneClipboardFile => context.localized(
      'Created: simulated phone file row',
      '已创建：模拟手机文件记录',
    ),
    DevelopmentTestAction.autoSendClipboard => context.localized(
      'Created: computer auto-send sample',
      '已创建：电脑自动同步样例',
    ),
    DevelopmentTestAction.manualDeviceShare => context.localized(
      'Opened: send-to-device chooser',
      '已打开：发送到设备选择弹框',
    ),
    DevelopmentTestAction.openDeviceManager => context.localized(
      'Opened: connection manager',
      '已打开：连接管理窗口',
    ),
  };
}
