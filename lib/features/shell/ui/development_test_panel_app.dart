import 'dart:async';

import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:dingdong/app/app_locale.dart';
import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/app/app_theme.dart';
import 'package:dingdong/core/platform/windows_auxiliary_window_close_behavior.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/features/shell/domain/development_test_action.dart';
import 'package:flutter/material.dart';
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
      onGenerateTitle: (BuildContext context) =>
          context.l10n.developmentTestPanelWindowTitle,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.desktopPanelLight(),
      darkTheme: AppTheme.desktopPanelDark(),
      themeMode: switch (settings.themeMode) {
        AppThemePreference.system => ThemeMode.system,
        AppThemePreference.light => ThemeMode.light,
        AppThemePreference.dark => ThemeMode.dark,
      },
      locale: configuredAppLocale(settings.language),
      supportedLocales: DingDongLocalizations.supportedLocales,
      localizationsDelegates: DingDongLocalizations.localizationsDelegates,
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
                    context.l10n.testPanel,
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
              context.l10n.exerciseRealDingDongIntegrationPathsFromOnePlace,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _TestDataNotice(colors: colors),
            const SizedBox(height: 22),
            _TestSection(
              title: context.l10n.menuBarMascot,
              description: context
                  .l10n
                  .previewRealTrayStatesWithoutCreatingHistoryRecords,
              cards: <Widget>[
                _TestCard(
                  title: context.l10n.sleepingState,
                  description: context
                      .l10n
                      .showTheSleepingMascotBrieflyThenRestoreTheCurrentState,
                  buttonLabel: context.l10n.run,
                  buttonKey: const Key('dev-test-panel-sleeping'),
                  icon: Icons.bedtime_outlined,
                  running: _runningAction == DevelopmentTestAction.traySleeping,
                  onPressed: _callbackFor(DevelopmentTestAction.traySleeping),
                ),
                _TestCard(
                  title: context.l10n.horizontalNudge,
                  description:
                      context.l10n.nudgeTheTrayMascotLikeAnOverdueReminder,
                  buttonLabel: context.l10n.run,
                  buttonKey: const Key('dev-test-panel-nudge'),
                  icon: Icons.swap_horiz_rounded,
                  running: _runningAction == DevelopmentTestAction.trayNudge,
                  onPressed: _callbackFor(DevelopmentTestAction.trayNudge),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _TestSection(
              title: context.l10n.agentAlerts,
              description: context
                  .l10n
                  .usesTheRealLocalDingRouteUnreadBadgeNativeAlertAnd_63a64edd,
              cards: <Widget>[
                _TestCard(
                  title: context.l10n.basicCompletion,
                  description:
                      context.l10n.createOneClearlyLabeledDEVCompletion,
                  buttonLabel: context.l10n.notify,
                  buttonKey: const Key('dev-test-panel-agent-basic'),
                  icon: Icons.notifications_active_outlined,
                  running:
                      _runningAction == DevelopmentTestAction.agentCompletion,
                  onPressed: _callbackFor(
                    DevelopmentTestAction.agentCompletion,
                  ),
                ),
                _TestCard(
                  title: context.l10n.richMobileDetail,
                  description: context
                      .l10n
                      .testAConciseSummaryPlusALongerMobileDetailBody,
                  buttonLabel: context.l10n.notify,
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
                  title: context.l10n.threeAlertBurst,
                  description: context
                      .l10n
                      .checkUnreadCountingOrderingAndRepeatedPhoneDelivery,
                  buttonLabel: context.l10n.send3,
                  buttonKey: const Key('dev-test-panel-agent-burst'),
                  icon: Icons.filter_3_rounded,
                  running: _runningAction == DevelopmentTestAction.agentBurst,
                  onPressed: _callbackFor(DevelopmentTestAction.agentBurst),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _TestSection(
              title: context.l10n.clipboardAndDevices,
              description: context
                  .l10n
                  .createsRemovableDEVSamplesOrOpensTheRealDeviceWorkflow,
              cards: <Widget>[
                _TestCard(
                  title: context.l10n.textFromPhone,
                  description: context
                      .l10n
                      .mockAddAPhoneOriginTextRowWithoutReadingAnyPhone_381a76fb,
                  buttonLabel: context.l10n.create,
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
                  title: context.l10n.fileFromPhone,
                  description: context
                      .l10n
                      .mockCreateASmallLocalFileAndShowItsDeviceSource,
                  buttonLabel: context.l10n.create,
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
                  title: context.l10n.oneWayAutoSend,
                  description: context
                      .l10n
                      .createAComputerRecordAndSendItOnlyToConnectedDevicesWith_41a63724,
                  buttonLabel: context.l10n.createAndSend,
                  buttonKey: const Key('dev-test-panel-auto-send'),
                  icon: Icons.arrow_forward_rounded,
                  running:
                      _runningAction == DevelopmentTestAction.autoSendClipboard,
                  onPressed: _callbackFor(
                    DevelopmentTestAction.autoSendClipboard,
                  ),
                ),
                _TestCard(
                  title: context.l10n.sendToDeviceDialog,
                  description: context
                      .l10n
                      .createASampleAndOpenTheRealTargetDeviceChooser,
                  buttonLabel: context.l10n.open,
                  buttonKey: const Key('dev-test-panel-manual-share'),
                  icon: Icons.send_to_mobile_outlined,
                  running:
                      _runningAction == DevelopmentTestAction.manualDeviceShare,
                  onPressed: _callbackFor(
                    DevelopmentTestAction.manualDeviceShare,
                  ),
                ),
                _TestCard(
                  title: context.l10n.connectionManager,
                  description: context
                      .l10n
                      .openTheStandaloneQRDeviceSwitchDisconnectAndDelete_441119af,
                  buttonLabel: context.l10n.open,
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
                context
                    .l10n
                    .trayMascotPreviewsAreUnavailableOnThisPlatformTheOther_ab13b937,
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
              context
                  .l10n
                  .agentAndClipboardItemsCreatedHereAreExplicitDEVTestData_f8625f9f,
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
                label: running ? context.l10n.running : buttonLabel,
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
        ? context.l10n.theTestFailedCheckTheConnectionAndSystemPermissions
        : running
        ? context.l10n.runningTest
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
    DevelopmentTestAction.traySleeping => context.l10n.triggeredSleepingState,
    DevelopmentTestAction.trayNudge => context.l10n.triggeredHorizontalNudge,
    DevelopmentTestAction.agentCompletion =>
      context.l10n.createdBasicAgentCompletion,
    DevelopmentTestAction.agentRichCompletion =>
      context.l10n.createdRichMobileAgentDetail,
    DevelopmentTestAction.agentBurst =>
      context.l10n.createdThreeAgentCompletions,
    DevelopmentTestAction.phoneClipboardText =>
      context.l10n.createdSimulatedPhoneTextRow,
    DevelopmentTestAction.phoneClipboardFile =>
      context.l10n.createdSimulatedPhoneFileRow,
    DevelopmentTestAction.autoSendClipboard =>
      context.l10n.createdComputerAutoSendSample,
    DevelopmentTestAction.manualDeviceShare =>
      context.l10n.openedSendToDeviceChooser,
    DevelopmentTestAction.openDeviceManager =>
      context.l10n.openedConnectionManager,
  };
}
