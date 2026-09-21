import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/core/widgets/desktop_segmented_control.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:dingdong/core/widgets/desktop_slider.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/settings_window_launcher.dart';
import 'package:dingdong/features/settings/domain/sound_file_gateway.dart';
import 'package:dingdong/features/settings/domain/sound_preview_gateway.dart';
import 'package:dingdong/features/settings/ui/global_hot_key_recorder.dart';
import 'package:dingdong/features/settings/ui/quick_paste_permission_section.dart';
import 'package:dingdong/features/settings/ui/release_settings_section.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:dingdong/features/settings/ui/sound_choices.dart';
import 'package:dingdong/features/settings/ui/system_usage_section.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

part 'settings_fields.dart';
part 'settings_sections.dart';

/// Desktop settings workspace grouped by user intent rather than storage keys.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.viewModel,
    this.navigationController,
    this.soundFileGateway,
    this.soundPreviewGateway,
    this.onRestartApplication,
    super.key,
  });

  final SettingsViewModel viewModel;
  final SettingsNavigationController? navigationController;
  final SoundFileGateway? soundFileGateway;
  final SoundPreviewGateway? soundPreviewGateway;
  final Future<void> Function()? onRestartApplication;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GlobalKey _releaseSectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  late SettingsNavigationController _navigationController;
  late bool _ownsNavigationController;
  bool _navigationPending = true;
  bool _navigationScheduled = false;

  @override
  void initState() {
    super.initState();
    _setNavigationController(widget.navigationController);
    widget.viewModel.addListener(_handleViewModelChanged);
    unawaited(widget.viewModel.load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.viewModel.checkForUpdates());
      _scheduleNavigation();
    });
  }

  @override
  void didUpdateWidget(SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.navigationController != widget.navigationController) {
      _navigationController.removeListener(_requestNavigation);
      if (_ownsNavigationController) {
        _navigationController.dispose();
      }
      _setNavigationController(widget.navigationController);
      _requestNavigation();
    }
  }

  @override
  void dispose() {
    widget.viewModel.removeListener(_handleViewModelChanged);
    _navigationController.removeListener(_requestNavigation);
    if (_ownsNavigationController) {
      _navigationController.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _setNavigationController(SettingsNavigationController? controller) {
    _ownsNavigationController = controller == null;
    _navigationController = controller ?? SettingsNavigationController();
    _navigationController.addListener(_requestNavigation);
  }

  void _handleViewModelChanged() {
    if (_navigationPending && widget.viewModel.isLoaded) {
      _scheduleNavigation();
    }
  }

  void _requestNavigation() {
    _navigationPending = true;
    _scheduleNavigation();
  }

  void _scheduleNavigation() {
    if (_navigationScheduled || !mounted) {
      return;
    }
    _navigationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigationScheduled = false;
      if (!mounted || !widget.viewModel.isLoaded) {
        return;
      }
      switch (_navigationController.destination) {
        case SettingsWindowDestination.top:
          if (!_scrollController.hasClients) {
            return;
          }
          _navigationPending = false;
          unawaited(
            _scrollController.animateTo(
              0,
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
            ),
          );
        case SettingsWindowDestination.version:
          final BuildContext? releaseContext =
              _releaseSectionKey.currentContext;
          if (releaseContext == null) {
            return;
          }
          _navigationPending = false;
          unawaited(
            Scrollable.ensureVisible(
              releaseContext,
              alignment: 0.08,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            ),
          );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      key: const Key('settings-screen'),
      color: Theme.of(context).colorScheme.surface,
      child: AnimatedBuilder(
        animation: widget.viewModel,
        builder: (BuildContext context, Widget? child) {
          if (!widget.viewModel.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          final AppSettings settings = widget.viewModel.settings;
          return CustomScrollView(
            controller: _scrollController,
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(36, 32, 36, 48),
                sliver: SliverToBoxAdapter(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 780),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            context.l10n.settings2,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context
                                .l10n
                                .desktopBehaviorHistoryPrivacyAndLocalAgentConnectivity,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          if (widget.viewModel.errorMessage !=
                              null) ...<Widget>[
                            const SizedBox(height: 18),
                            _ErrorBanner(
                              message: widget.viewModel.errorMessage!,
                            ),
                          ],
                          const SizedBox(height: 30),
                          _SettingsSection(
                            title: context.l10n.general,
                            description: context
                                .l10n
                                .chooseHowDingDongBehavesWhenYouSignIn,
                            children: <Widget>[
                              CompactSwitchListTile(
                                key: const Key('settings-launch-at-startup'),
                                contentPadding: EdgeInsets.zero,
                                title: Text(context.l10n.launchAtStartup),
                                subtitle: Text(
                                  context
                                      .l10n
                                      .startDingDongAfterYouSignInToThisComputer,
                                ),
                                value: settings.launchAtStartup,
                                onChanged: widget.viewModel.setLaunchAtStartup,
                              ),
                              if (defaultTargetPlatform == TargetPlatform.macOS)
                                CompactSwitchListTile(
                                  key: const Key('settings-hide-dock-icon'),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(context.l10n.hideDockIcon),
                                  subtitle: Text(
                                    context
                                        .l10n
                                        .keepDingDongInTheMenuBarWithoutShowingItInTheDock,
                                  ),
                                  value: settings.hideDockIcon,
                                  onChanged: widget.viewModel.setHideDockIcon,
                                ),
                              if (defaultTargetPlatform == TargetPlatform.macOS)
                                _SettingRow(
                                  label: context
                                      .l10n
                                      .menuBarIconHiddenByTheCameraHousing,
                                  child: DesktopActionButton(
                                    key: const Key(
                                      'settings-menu-bar-recovery',
                                    ),
                                    onPressed: () => unawaited(
                                      widget.viewModel.showMenuBarRecovery(),
                                    ),
                                    icon: Icons.visibility_rounded,
                                    label: context.l10n.findIcon,
                                    tone: DesktopActionTone.soft,
                                  ),
                                ),
                            ],
                          ),
                          _SettingsSection(
                            title: context.l10n.keyboardShortcuts,
                            description: context
                                .l10n
                                .setTheSystemWidePanelShortcutAndTheShortcutsUsedInside_4f5138fb,
                            children: <Widget>[
                              _SettingRow(
                                label: context.l10n.openOrHideClipboard,
                                child: GlobalHotKeyRecorder(
                                  value: settings.globalHotKey,
                                  onChanged: widget.viewModel.setGlobalHotKey,
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 2,
                                ),
                                child: Text(
                                  context
                                      .l10n
                                      .workspaceShortcutsApplyOnlyWhileThePanelIsFocused_1b6f2968,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              _SettingRow(
                                label: context.l10n.dynamicWorkspace,
                                child: WorkspaceShortcutRecorder(
                                  settingId: 'today',
                                  semanticLabel:
                                      context.l10n.dynamicWorkspaceShortcut,
                                  value: settings.workspaceShortcuts.today,
                                  defaultValue: WorkspaceShortcuts.defaultToday,
                                  onChanged: (WorkspaceShortcut value) => widget
                                      .viewModel
                                      .setWorkspaceShortcut(0, value),
                                ),
                              ),
                              _SettingRow(
                                label: context.l10n.libraryWorkspace,
                                child: WorkspaceShortcutRecorder(
                                  settingId: 'library',
                                  semanticLabel:
                                      context.l10n.libraryWorkspaceShortcut,
                                  value: settings.workspaceShortcuts.library,
                                  defaultValue:
                                      WorkspaceShortcuts.defaultLibrary,
                                  onChanged: (WorkspaceShortcut value) => widget
                                      .viewModel
                                      .setWorkspaceShortcut(1, value),
                                ),
                              ),
                              _SettingRow(
                                label: context.l10n.clipboardWorkspace,
                                child: WorkspaceShortcutRecorder(
                                  settingId: 'clipboard',
                                  semanticLabel:
                                      context.l10n.clipboardWorkspaceShortcut,
                                  value: settings.workspaceShortcuts.clipboard,
                                  defaultValue:
                                      WorkspaceShortcuts.defaultClipboard,
                                  onChanged: (WorkspaceShortcut value) => widget
                                      .viewModel
                                      .setWorkspaceShortcut(2, value),
                                ),
                              ),
                            ],
                          ),
                          QuickPastePermissionSection(
                            viewModel: widget.viewModel,
                          ),
                          SystemUsageSection(viewModel: widget.viewModel),
                          _SettingsSection(
                            title: context.l10n.appearance,
                            description: context
                                .l10n
                                .keepTheWorkspaceComfortableInYourCurrentDesktop_41d3bc46,
                            children: <Widget>[
                              _SettingRow(
                                label: context.l10n.theme,
                                child:
                                    DesktopSegmentedControl<AppThemePreference>(
                                      key: const Key('settings-theme-mode'),
                                      value: settings.themeMode,
                                      segments:
                                          <DesktopSegment<AppThemePreference>>[
                                            DesktopSegment<AppThemePreference>(
                                              value: AppThemePreference.system,
                                              label: Text(context.l10n.system),
                                            ),
                                            DesktopSegment<AppThemePreference>(
                                              value: AppThemePreference.light,
                                              label: Text(context.l10n.light),
                                            ),
                                            DesktopSegment<AppThemePreference>(
                                              value: AppThemePreference.dark,
                                              label: Text(context.l10n.dark),
                                            ),
                                          ],
                                      onChanged: widget.viewModel.setThemeMode,
                                    ),
                              ),
                              _SettingRow(
                                label: context.l10n.language,
                                child: SizedBox(
                                  width: 190,
                                  child:
                                      DesktopSelectField<AppLanguagePreference>(
                                        key: const Key('settings-language'),
                                        value: settings.language,
                                        items:
                                            <
                                              DesktopSelectItem<
                                                AppLanguagePreference
                                              >
                                            >[
                                              DesktopSelectItem(
                                                value: AppLanguagePreference
                                                    .system,
                                                label: context.l10n.system,
                                              ),
                                              DesktopSelectItem(
                                                value: AppLanguagePreference
                                                    .english,
                                                label: context
                                                    .l10n
                                                    .languageEnglish,
                                              ),
                                              DesktopSelectItem(
                                                value: AppLanguagePreference
                                                    .chinese,
                                                label: context
                                                    .l10n
                                                    .languageChinese,
                                              ),
                                              DesktopSelectItem(
                                                value: AppLanguagePreference
                                                    .spanish,
                                                label: context
                                                    .l10n
                                                    .languageSpanish,
                                              ),
                                            ],
                                        onChanged: widget.viewModel.setLanguage,
                                      ),
                                ),
                              ),
                              _SettingRow(
                                label:
                                    '${context.l10n.windowOpacity} · ${(settings.backgroundOpacity * 100).round()}%',
                                child: SizedBox(
                                  width: 220,
                                  child: DesktopSlider(
                                    key: const Key('settings-opacity'),
                                    value: settings.backgroundOpacity,
                                    min: 0.82,
                                    max: 0.96,
                                    divisions: 14,
                                    onChanged:
                                        widget.viewModel.setBackgroundOpacity,
                                  ),
                                ),
                              ),
                              _SettingRow(
                                label: context.l10n.defaultWorkspace,
                                child:
                                    DesktopSegmentedControl<DefaultWorkspace>(
                                      key: const Key(
                                        'settings-default-workspace',
                                      ),
                                      value: settings.defaultWorkspace,
                                      segments:
                                          <DesktopSegment<DefaultWorkspace>>[
                                            DesktopSegment<DefaultWorkspace>(
                                              value: DefaultWorkspace.today,
                                              label: Text(
                                                context.l10n.dynamicMessage,
                                              ),
                                            ),
                                            DesktopSegment<DefaultWorkspace>(
                                              value: DefaultWorkspace.library,
                                              label: Text(
                                                context.l10n.libraryMessage,
                                              ),
                                            ),
                                            DesktopSegment<DefaultWorkspace>(
                                              value: DefaultWorkspace.clipboard,
                                              label: Text(
                                                context.l10n.clipboard,
                                              ),
                                            ),
                                          ],
                                      onChanged:
                                          widget.viewModel.setDefaultWorkspace,
                                    ),
                              ),
                            ],
                          ),
                          _SettingsSection(
                            title: context.l10n.clipboardHistory2,
                            description: context
                                .l10n
                                .historyStaysOnThisDeviceAgentAccessToClipboardContentIs_74a8f236,
                            children: <Widget>[
                              CompactSwitchListTile(
                                key: const Key('settings-clipboard-monitoring'),
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  context.l10n.monitorClipboardChanges,
                                ),
                                subtitle: Text(
                                  context
                                      .l10n
                                      .captureTextFilesAndImagesWhileDingDongIsRunning,
                                ),
                                value: settings.clipboardMonitoring,
                                onChanged:
                                    widget.viewModel.setClipboardMonitoring,
                              ),
                              CompactSwitchListTile(
                                key: const Key(
                                  'settings-agent-clipboard-content',
                                ),
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  context
                                      .l10n
                                      .allowAgentsToReadClipboardContent,
                                ),
                                subtitle: Text(
                                  context
                                      .l10n
                                      .offByDefaultMetadataStaysAvailableSensitiveRecordsStill_fa1a5f8f,
                                ),
                                value: settings.allowAgentClipboardContent,
                                onChanged: widget
                                    .viewModel
                                    .setAllowAgentClipboardContent,
                              ),
                              _SettingRow(
                                label: context.l10n.maximumItems,
                                child: _NumberField(
                                  key: const Key('settings-retention-items'),
                                  initialValue: settings.clipboardMaxItems,
                                  onChanged: (int value) =>
                                      widget.viewModel.setRetention(
                                        maxItems: value,
                                        maxAgeDays:
                                            settings.clipboardMaxAgeDays,
                                      ),
                                ),
                              ),
                              _SettingRow(
                                label: context.l10n.retentionDays,
                                child: _NumberField(
                                  key: const Key('settings-retention-days'),
                                  initialValue: settings.clipboardMaxAgeDays,
                                  onChanged: (int value) =>
                                      widget.viewModel.setRetention(
                                        maxItems: settings.clipboardMaxItems,
                                        maxAgeDays: value,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          _SettingsSection(
                            title: context.l10n.recentAgents,
                            description: context
                                .l10n
                                .completionDetailsStayOnThisDeviceCountingMetadata_9920ce29,
                            children: <Widget>[
                              CompactSwitchListTile(
                                key: const Key(
                                  'settings-agent-activity-group-sessions',
                                ),
                                contentPadding: EdgeInsets.zero,
                                title: Text(context.l10n.groupRepeatedSessions),
                                subtitle: Text(
                                  context
                                      .l10n
                                      .keepTheSameConversationIDInOneItemShowNAndDoNotIncrease_925894bb,
                                ),
                                value: settings.groupRepeatedAgentSessions,
                                onChanged: widget
                                    .viewModel
                                    .setGroupRepeatedAgentSessions,
                              ),
                              CompactSwitchListTile(
                                key: const Key(
                                  'settings-agent-activity-remember',
                                ),
                                contentPadding: EdgeInsets.zero,
                                title: Text(context.l10n.rememberAfterRestart),
                                subtitle: Text(
                                  context
                                      .l10n
                                      .whenDisabledTheNextLaunchStartsWithAnEmptyAgentHistory,
                                ),
                                value: settings.rememberAgentActivity,
                                onChanged:
                                    widget.viewModel.setRememberAgentActivity,
                              ),
                              _SettingRow(
                                label: context.l10n.maximumDetailedItems,
                                child: _NumberField(
                                  key: const Key(
                                    'settings-agent-activity-items',
                                  ),
                                  initialValue: settings.agentActivityMaxItems,
                                  onChanged: (int value) =>
                                      widget.viewModel.setAgentActivityPolicy(
                                        maxItems: value,
                                        countHours:
                                            settings.agentActivityCountHours,
                                      ),
                                ),
                              ),
                              _SettingRow(
                                label: context.l10n.countWindowHours,
                                child: _NumberField(
                                  key: const Key(
                                    'settings-agent-activity-hours',
                                  ),
                                  initialValue:
                                      settings.agentActivityCountHours,
                                  onChanged: (int value) =>
                                      widget.viewModel.setAgentActivityPolicy(
                                        maxItems:
                                            settings.agentActivityMaxItems,
                                        countHours: value,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          _NotificationSettingsSection(
                            viewModel: widget.viewModel,
                            settings: settings,
                            soundFileGateway: widget.soundFileGateway,
                            soundPreviewGateway: widget.soundPreviewGateway,
                          ),
                          _ConversationFooterSettingsSection(
                            viewModel: widget.viewModel,
                            settings: settings,
                          ),
                          _SettingsSection(
                            title: context.l10n.agentAPI,
                            description: context
                                .l10n
                                .dingdongListensOnlyOnTheLocalLoopbackInterface,
                            children: <Widget>[
                              _SettingRow(
                                label: context.l10n.localPort,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    _NumberField(
                                      key: const Key('settings-api-port'),
                                      initialValue: settings.apiPort,
                                      onChanged: widget.viewModel.setApiPort,
                                    ),
                                    if (widget.viewModel.requiresRestart &&
                                        widget.onRestartApplication !=
                                            null) ...<Widget>[
                                      const SizedBox(width: 8),
                                      DesktopActionButton(
                                        key: const Key('settings-restart'),
                                        onPressed: () =>
                                            widget.onRestartApplication!.call(),
                                        icon: const Icon(
                                          Icons.restart_alt_rounded,
                                          size: 17,
                                        ),
                                        label: context.l10n.restart,
                                        tone: DesktopActionTone.soft,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Text(
                                context
                                    .l10n
                                    .portChangesApplyTheNextTimeDingDongStarts,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                          ReleaseSettingsSection(
                            key: _releaseSectionKey,
                            viewModel: widget.viewModel,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

final class SettingsNavigationController extends ChangeNotifier {
  SettingsNavigationController({
    SettingsWindowDestination initialDestination =
        SettingsWindowDestination.top,
  }) : _destination = initialDestination;

  SettingsWindowDestination _destination;

  SettingsWindowDestination get destination => _destination;

  void navigateTo(SettingsWindowDestination destination) {
    _destination = destination;
    notifyListeners();
  }
}
