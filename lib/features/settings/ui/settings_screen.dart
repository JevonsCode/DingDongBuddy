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
                            context.localized('Settings', '设置'),
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            context.localized(
                              'Desktop behavior, history privacy, and local agent connectivity.',
                              '管理桌面行为、历史隐私与本地 Agent 连接。',
                            ),
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
                            title: context.localized('General', '通用'),
                            description: context.localized(
                              'Choose how DingDong behaves when you sign in.',
                              '选择登录系统后 DingDong 的运行方式。',
                            ),
                            children: <Widget>[
                              CompactSwitchListTile(
                                key: const Key('settings-launch-at-startup'),
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  context.localized(
                                    'Launch at startup',
                                    '开机启动',
                                  ),
                                ),
                                subtitle: Text(
                                  context.localized(
                                    'Start DingDong after you sign in to this computer.',
                                    '登录此电脑后自动启动 DingDong。',
                                  ),
                                ),
                                value: settings.launchAtStartup,
                                onChanged: widget.viewModel.setLaunchAtStartup,
                              ),
                              if (defaultTargetPlatform == TargetPlatform.macOS)
                                CompactSwitchListTile(
                                  key: const Key('settings-hide-dock-icon'),
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    context.localized(
                                      'Hide Dock icon',
                                      '隐藏 Dock 图标',
                                    ),
                                  ),
                                  subtitle: Text(
                                    context.localized(
                                      'Keep DingDong in the menu bar without showing it in the Dock.',
                                      '仅保留菜单栏入口，不在 Dock 中显示 DingDong。',
                                    ),
                                  ),
                                  value: settings.hideDockIcon,
                                  onChanged: widget.viewModel.setHideDockIcon,
                                ),
                            ],
                          ),
                          _SettingsSection(
                            title: context.localized(
                              'Keyboard shortcuts',
                              '键盘快捷键',
                            ),
                            description: context.localized(
                              'Set the system-wide panel shortcut and the shortcuts used inside the focused panel.',
                              '设置面板全局快捷键，以及面板获得焦点时使用的工作区快捷键。',
                            ),
                            children: <Widget>[
                              _SettingRow(
                                label: context.localized(
                                  'Open or hide clipboard',
                                  '打开或隐藏剪贴板',
                                ),
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
                                  context.localized(
                                    'Workspace shortcuts apply only while the panel is focused. Defaults: Control+Q/W/E on macOS, Alt+Q/W/E on Windows.',
                                    '工作区快捷键只在面板获得焦点时生效。默认：macOS 为 Control+Q/W/E，Windows 为 Alt+Q/W/E。',
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ),
                              _SettingRow(
                                label: context.localized(
                                  'Dynamic workspace',
                                  '动态工作区',
                                ),
                                child: WorkspaceShortcutRecorder(
                                  settingId: 'today',
                                  semanticLabel: context.localized(
                                    'Dynamic workspace shortcut',
                                    '动态工作区快捷键',
                                  ),
                                  value: settings.workspaceShortcuts.today,
                                  defaultValue: WorkspaceShortcuts.defaultToday,
                                  onChanged: (WorkspaceShortcut value) => widget
                                      .viewModel
                                      .setWorkspaceShortcut(0, value),
                                ),
                              ),
                              _SettingRow(
                                label: context.localized(
                                  'Library workspace',
                                  '资源库工作区',
                                ),
                                child: WorkspaceShortcutRecorder(
                                  settingId: 'library',
                                  semanticLabel: context.localized(
                                    'Library workspace shortcut',
                                    '资源库工作区快捷键',
                                  ),
                                  value: settings.workspaceShortcuts.library,
                                  defaultValue:
                                      WorkspaceShortcuts.defaultLibrary,
                                  onChanged: (WorkspaceShortcut value) => widget
                                      .viewModel
                                      .setWorkspaceShortcut(1, value),
                                ),
                              ),
                              _SettingRow(
                                label: context.localized(
                                  'Clipboard workspace',
                                  '剪贴板工作区',
                                ),
                                child: WorkspaceShortcutRecorder(
                                  settingId: 'clipboard',
                                  semanticLabel: context.localized(
                                    'Clipboard workspace shortcut',
                                    '剪贴板工作区快捷键',
                                  ),
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
                            title: context.localized('Appearance', '外观'),
                            description: context.localized(
                              'Keep the workspace comfortable in your current desktop environment.',
                              '根据当前桌面环境调整工作台显示。',
                            ),
                            children: <Widget>[
                              _SettingRow(
                                label: context.localized('Theme', '主题'),
                                child:
                                    DesktopSegmentedControl<AppThemePreference>(
                                      key: const Key('settings-theme-mode'),
                                      value: settings.themeMode,
                                      segments:
                                          <DesktopSegment<AppThemePreference>>[
                                            DesktopSegment<AppThemePreference>(
                                              value: AppThemePreference.system,
                                              label: Text(
                                                context.localized(
                                                  'System',
                                                  '跟随系统',
                                                ),
                                              ),
                                            ),
                                            DesktopSegment<AppThemePreference>(
                                              value: AppThemePreference.light,
                                              label: Text(
                                                context.localized(
                                                  'Light',
                                                  '浅色',
                                                ),
                                              ),
                                            ),
                                            DesktopSegment<AppThemePreference>(
                                              value: AppThemePreference.dark,
                                              label: Text(
                                                context.localized('Dark', '深色'),
                                              ),
                                            ),
                                          ],
                                      onChanged: widget.viewModel.setThemeMode,
                                    ),
                              ),
                              _SettingRow(
                                label: context.localized('Language', '语言'),
                                child: SizedBox(
                                  width: 190,
                                  child:
                                      DesktopSelectField<AppLanguagePreference>(
                                        key: const Key('settings-language'),
                                        value: settings.language,
                                        items:
                                            const <
                                              DesktopSelectItem<
                                                AppLanguagePreference
                                              >
                                            >[
                                              DesktopSelectItem(
                                                value: AppLanguagePreference
                                                    .system,
                                                label: 'System',
                                              ),
                                              DesktopSelectItem(
                                                value: AppLanguagePreference
                                                    .english,
                                                label: 'English',
                                              ),
                                              DesktopSelectItem(
                                                value: AppLanguagePreference
                                                    .chinese,
                                                label: '中文',
                                              ),
                                            ],
                                        onChanged: widget.viewModel.setLanguage,
                                      ),
                                ),
                              ),
                              _SettingRow(
                                label:
                                    '${context.localized('Window opacity', '窗口透明度')} · ${(settings.backgroundOpacity * 100).round()}%',
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
                                label: context.localized(
                                  'Default workspace',
                                  '默认页面',
                                ),
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
                                                context.localized(
                                                  'Dynamic',
                                                  '动态',
                                                ),
                                              ),
                                            ),
                                            DesktopSegment<DefaultWorkspace>(
                                              value: DefaultWorkspace.library,
                                              label: Text(
                                                context.localized(
                                                  'Library',
                                                  '资源库',
                                                ),
                                              ),
                                            ),
                                            DesktopSegment<DefaultWorkspace>(
                                              value: DefaultWorkspace.clipboard,
                                              label: Text(
                                                context.localized(
                                                  'Clipboard',
                                                  '剪贴板',
                                                ),
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
                            title: context.localized(
                              'Clipboard history',
                              '剪贴板历史',
                            ),
                            description: context.localized(
                              'History stays on this device. Agent access to clipboard content is controlled below.',
                              '历史仅保存在本机；是否允许 Agent 读取正文由下方开关控制。',
                            ),
                            children: <Widget>[
                              CompactSwitchListTile(
                                key: const Key('settings-clipboard-monitoring'),
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  context.localized(
                                    'Monitor clipboard changes',
                                    '监控剪贴板变化',
                                  ),
                                ),
                                subtitle: Text(
                                  context.localized(
                                    'Capture text, files, and images while DingDong is running.',
                                    'DingDong 运行期间捕获文本、文件和图片。',
                                  ),
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
                                  context.localized(
                                    'Allow Agents to read clipboard content',
                                    '允许 Agent 读取剪贴板正文',
                                  ),
                                ),
                                subtitle: Text(
                                  context.localized(
                                    'Off by default. Metadata stays available; sensitive records still require an explicit request when enabled.',
                                    '默认关闭。关闭时只返回元数据；开启后，敏感记录仍需调用方明确请求。',
                                  ),
                                ),
                                value: settings.allowAgentClipboardContent,
                                onChanged: widget
                                    .viewModel
                                    .setAllowAgentClipboardContent,
                              ),
                              _SettingRow(
                                label: context.localized(
                                  'Maximum items',
                                  '最大条目数',
                                ),
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
                                label: context.localized(
                                  'Retention days',
                                  '保留天数',
                                ),
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
                            title: context.localized(
                              'Recent agents',
                              '最近 Agent',
                            ),
                            description: context.localized(
                              'Completion details stay on this device. Counting metadata contains timestamps only.',
                              '完成详情仅保存在本机；用于统计的元数据只包含完成时间。',
                            ),
                            children: <Widget>[
                              CompactSwitchListTile(
                                key: const Key(
                                  'settings-agent-activity-group-sessions',
                                ),
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  context.localized(
                                    'Group repeated sessions',
                                    '合并同会话提醒',
                                  ),
                                ),
                                subtitle: Text(
                                  context.localized(
                                    'Keep the same conversation ID in one item, show ×N, and do not increase the recent count.',
                                    '相同会话 ID 合并为一个动态项，显示 ×N，且不增加最近 Agent 数量。',
                                  ),
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
                                title: Text(
                                  context.localized(
                                    'Remember after restart',
                                    '重启后保留记录',
                                  ),
                                ),
                                subtitle: Text(
                                  context.localized(
                                    'When disabled, the next launch starts with an empty Agent history.',
                                    '关闭后，下次启动将从空的 Agent 历史开始。',
                                  ),
                                ),
                                value: settings.rememberAgentActivity,
                                onChanged:
                                    widget.viewModel.setRememberAgentActivity,
                              ),
                              _SettingRow(
                                label: context.localized(
                                  'Maximum detailed items',
                                  '详细记录上限',
                                ),
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
                                label: context.localized(
                                  'Count window (hours)',
                                  '计数时间范围（小时）',
                                ),
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
                          _SettingsSection(
                            title: 'Agent API',
                            description: context.localized(
                              'DingDong listens only on the local loopback interface.',
                              'DingDong 仅监听本机回环地址。',
                            ),
                            children: <Widget>[
                              _SettingRow(
                                label: context.localized('Local port', '本地端口'),
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
                                        label: context.localized(
                                          'Restart',
                                          '重启',
                                        ),
                                        tone: DesktopActionTone.soft,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Text(
                                context.localized(
                                  'Port changes apply the next time DingDong starts.',
                                  '端口修改将在下次启动 DingDong 时生效。',
                                ),
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
