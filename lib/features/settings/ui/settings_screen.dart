import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:dingdong/features/settings/domain/sound_file_gateway.dart';
import 'package:dingdong/features/settings/domain/sound_preview_gateway.dart';
import 'package:dingdong/features/settings/ui/quick_paste_permission_section.dart';
import 'package:dingdong/features/settings/ui/release_settings_section.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:dingdong/features/settings/ui/sound_choices.dart';
import 'package:dingdong/features/settings/ui/system_usage_section.dart';
import 'package:flutter/material.dart';

part 'settings_fields.dart';
part 'settings_sections.dart';

/// Desktop settings workspace grouped by user intent rather than storage keys.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    required this.viewModel,
    this.soundFileGateway,
    this.soundPreviewGateway,
    this.onRestartApplication,
    super.key,
  });

  final SettingsViewModel viewModel;
  final SoundFileGateway? soundFileGateway;
  final SoundPreviewGateway? soundPreviewGateway;
  final Future<void> Function()? onRestartApplication;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    unawaited(widget.viewModel.load());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(widget.viewModel.checkForUpdates());
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
                              CompactSwitchListTile(
                                key: const Key('settings-anonymous-telemetry'),
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  context.localized(
                                    'Share anonymous diagnostics',
                                    '分享匿名诊断数据',
                                  ),
                                ),
                                subtitle: Text(
                                  context.localized(
                                    'Optional usage and error events only. Never sends clipboard content, paths, names, or error details.',
                                    '仅上传可选的使用和错误事件；绝不上传剪贴板内容、路径、姓名或错误详情。',
                                  ),
                                ),
                                value: settings.anonymousTelemetry,
                                onChanged:
                                    widget.viewModel.setAnonymousTelemetry,
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
                                child: SegmentedButton<AppThemePreference>(
                                  key: const Key('settings-theme-mode'),
                                  showSelectedIcon: false,
                                  segments: <ButtonSegment<AppThemePreference>>[
                                    ButtonSegment<AppThemePreference>(
                                      value: AppThemePreference.system,
                                      label: Text(
                                        context.localized('System', '跟随系统'),
                                      ),
                                    ),
                                    ButtonSegment<AppThemePreference>(
                                      value: AppThemePreference.light,
                                      label: Text(
                                        context.localized('Light', '浅色'),
                                      ),
                                    ),
                                    ButtonSegment<AppThemePreference>(
                                      value: AppThemePreference.dark,
                                      label: Text(
                                        context.localized('Dark', '深色'),
                                      ),
                                    ),
                                  ],
                                  selected: <AppThemePreference>{
                                    settings.themeMode,
                                  },
                                  onSelectionChanged:
                                      (Set<AppThemePreference> value) {
                                        widget.viewModel.setThemeMode(
                                          value.single,
                                        );
                                      },
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
                                  child: Slider(
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
                                  'List density',
                                  '列表密度',
                                ),
                                child: SegmentedButton<PanelDensityPreference>(
                                  key: const Key('settings-density'),
                                  showSelectedIcon: false,
                                  segments:
                                      <ButtonSegment<PanelDensityPreference>>[
                                        ButtonSegment<PanelDensityPreference>(
                                          value: PanelDensityPreference
                                              .comfortable,
                                          label: Text(
                                            context.localized(
                                              'Comfortable',
                                              '舒展',
                                            ),
                                          ),
                                        ),
                                        ButtonSegment<PanelDensityPreference>(
                                          value: PanelDensityPreference.compact,
                                          label: Text(
                                            context.localized('Compact', '紧凑'),
                                          ),
                                        ),
                                      ],
                                  selected: <PanelDensityPreference>{
                                    settings.density,
                                  },
                                  onSelectionChanged:
                                      (Set<PanelDensityPreference> value) =>
                                          widget.viewModel.setDensity(
                                            value.single,
                                          ),
                                ),
                              ),
                              _SettingRow(
                                label: context.localized(
                                  'Default workspace',
                                  '默认页面',
                                ),
                                child: SegmentedButton<DefaultWorkspace>(
                                  key: const Key('settings-default-workspace'),
                                  showSelectedIcon: false,
                                  segments: <ButtonSegment<DefaultWorkspace>>[
                                    ButtonSegment<DefaultWorkspace>(
                                      value: DefaultWorkspace.today,
                                      label: Text(
                                        context.localized('Dynamic', '动态'),
                                      ),
                                    ),
                                    ButtonSegment<DefaultWorkspace>(
                                      value: DefaultWorkspace.library,
                                      label: Text(
                                        context.localized('Library', '资源库'),
                                      ),
                                    ),
                                    ButtonSegment<DefaultWorkspace>(
                                      value: DefaultWorkspace.clipboard,
                                      label: Text(
                                        context.localized('Clipboard', '剪贴板'),
                                      ),
                                    ),
                                  ],
                                  selected: <DefaultWorkspace>{
                                    settings.defaultWorkspace,
                                  },
                                  onSelectionChanged:
                                      (Set<DefaultWorkspace> value) => widget
                                          .viewModel
                                          .setDefaultWorkspace(value.single),
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
                              'History stays on this device. Sensitive entries remain hidden from agent APIs by default.',
                              '历史仅保存在本机；敏感内容默认不会暴露给 Agent API。',
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
                              _SettingRow(
                                label: context.localized(
                                  'Maximum items',
                                  '最大条目数',
                                ),
                                child: _NumberField(
                                  key: const Key('settings-retention-items'),
                                  initialValue: settings.clipboardMaxItems,
                                  onSubmitted: (int value) =>
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
                                  onSubmitted: (int value) =>
                                      widget.viewModel.setRetention(
                                        maxItems: settings.clipboardMaxItems,
                                        maxAgeDays: value,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          _NotificationSoundSettingsSection(
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
                                      onSubmitted: widget.viewModel.setApiPort,
                                    ),
                                    if (widget.viewModel.requiresRestart &&
                                        widget.onRestartApplication !=
                                            null) ...<Widget>[
                                      const SizedBox(width: 8),
                                      FilledButton.tonalIcon(
                                        key: const Key('settings-restart'),
                                        onPressed: () =>
                                            widget.onRestartApplication!.call(),
                                        icon: const Icon(
                                          Icons.restart_alt_rounded,
                                          size: 17,
                                        ),
                                        label: Text(
                                          context.localized('Restart', '重启'),
                                        ),
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
                          ReleaseSettingsSection(viewModel: widget.viewModel),
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
