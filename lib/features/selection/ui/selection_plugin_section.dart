import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:dingdong/features/selection/domain/selection_plugin_configuration.dart';
import 'package:dingdong/features/settings/ui/settings_view_model.dart';
import 'package:flutter/material.dart';

/// Optional system-wide selection tools hosted by the DingDong process.
class SelectionPluginSection extends StatefulWidget {
  const SelectionPluginSection({required this.viewModel, super.key});

  final SettingsViewModel viewModel;

  @override
  State<SelectionPluginSection> createState() => _SelectionPluginSectionState();
}

class _SelectionPluginSectionState extends State<SelectionPluginSection> {
  late final TextEditingController _endpointController;
  late final TextEditingController _modelController;
  late final TextEditingController _languageController;
  late final TextEditingController _tokenController;
  SelectionModelProvider? _lastProvider;

  @override
  void initState() {
    super.initState();
    final SelectionPluginConfiguration configuration =
        widget.viewModel.settings.selectionPlugin;
    _endpointController = TextEditingController(text: configuration.endpoint);
    _modelController = TextEditingController(text: configuration.model);
    _languageController = TextEditingController(
      text: configuration.targetLanguage,
    );
    _tokenController = TextEditingController();
    _lastProvider = configuration.provider;
  }

  @override
  void didUpdateWidget(SelectionPluginSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.viewModel != widget.viewModel) {
      _syncConfiguration(widget.viewModel.settings.selectionPlugin);
    }
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _modelController.dispose();
    _languageController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.viewModel,
      builder: (BuildContext context, Widget? child) {
        final SelectionPluginConfiguration configuration =
            widget.viewModel.settings.selectionPlugin;
        if (_lastProvider != configuration.provider) {
          _syncConfiguration(configuration);
        }
        final ColorScheme colors = Theme.of(context).colorScheme;
        final String status = widget.viewModel.isSelectionPluginRunning
            ? context.l10n.selectionPluginRunning
            : configuration.enabled &&
                  !widget.viewModel.isSelectionPluginPermissionGranted
            ? context.l10n.selectionPluginPermissionNeeded
            : context.l10n.selectionPluginStopped;

        return Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                context.l10n.systemSelectionTools,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.systemSelectionToolsDescription,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              CompactSwitchListTile(
                key: const Key('settings-selection-enabled'),
                contentPadding: EdgeInsets.zero,
                title: Text(context.l10n.enableSystemSelectionTools),
                subtitle: Text(
                  context.l10n.enableSystemSelectionToolsDescription,
                ),
                value: configuration.enabled,
                onChanged: widget.viewModel.setSelectionPluginEnabled,
              ),
              const SizedBox(height: 10),
              Container(
                key: const Key('settings-selection-runtime-status'),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      widget.viewModel.isSelectionPluginRunning
                          ? Icons.check_circle_outline_rounded
                          : Icons.pause_circle_outline_rounded,
                      size: 19,
                      color: widget.viewModel.isSelectionPluginRunning
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        status,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DesktopIconButton(
                      tooltip: context.l10n.refreshStatus,
                      onPressed: widget.viewModel.refreshSelectionPluginStatus,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                    if (configuration.enabled &&
                        !widget
                            .viewModel
                            .isSelectionPluginPermissionGranted) ...<Widget>[
                      const SizedBox(width: 6),
                      DesktopActionButton(
                        key: const Key('settings-selection-open-accessibility'),
                        onPressed: widget
                            .viewModel
                            .openSelectionPluginAccessibilitySettings,
                        icon: Icons.open_in_new_rounded,
                        label: context.l10n.openPermissionHelper,
                        tone: DesktopActionTone.neutral,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _SettingLine(
                label: context.l10n.selectionModelProvider,
                child: SizedBox(
                  width: 280,
                  child: DesktopSelectField<SelectionModelProvider>(
                    key: const Key('settings-selection-provider'),
                    value: configuration.provider,
                    items: SelectionModelProvider.values
                        .map(
                          (SelectionModelProvider provider) =>
                              DesktopSelectItem<SelectionModelProvider>(
                                value: provider,
                                label: _providerLabel(provider),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (SelectionModelProvider provider) {
                      final SelectionPluginConfiguration next = configuration
                          .withProvider(provider);
                      _syncConfiguration(next);
                      unawaited(
                        widget.viewModel.setSelectionPluginConfiguration(next),
                      );
                    },
                  ),
                ),
              ),
              _SettingLine(
                label: context.l10n.selectionModelEndpoint,
                child: SizedBox(
                  width: 360,
                  child: DesktopTextField(
                    key: const Key('settings-selection-endpoint'),
                    controller: _endpointController,
                    decoration: const InputDecoration(
                      hintText: 'http://127.0.0.1:11434',
                    ),
                  ),
                ),
              ),
              _SettingLine(
                label: context.l10n.selectionModelName,
                child: SizedBox(
                  width: 280,
                  child: DesktopTextField(
                    key: const Key('settings-selection-model'),
                    controller: _modelController,
                  ),
                ),
              ),
              _SettingLine(
                label: context.l10n.selectionTargetLanguage,
                child: SizedBox(
                  width: 180,
                  child: DesktopTextField(
                    key: const Key('settings-selection-language'),
                    controller: _languageController,
                  ),
                ),
              ),
              if (configuration.provider == SelectionModelProvider.ollama)
                CompactSwitchListTile(
                  key: const Key('settings-selection-unload-local-model'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.selectionUnloadLocalModel),
                  subtitle: Text(
                    context.l10n.selectionUnloadLocalModelDescription,
                  ),
                  value: configuration.unloadLocalModelAfterResponse,
                  onChanged: (bool value) => unawaited(
                    widget.viewModel.setSelectionPluginConfiguration(
                      _configurationFromFields(
                        configuration,
                      ).copyWith(unloadLocalModelAfterResponse: value),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.centerRight,
                child: DesktopActionButton(
                  key: const Key('settings-selection-config-apply'),
                  onPressed: () => unawaited(
                    widget.viewModel.setSelectionPluginConfiguration(
                      _configurationFromFields(configuration),
                    ),
                  ),
                  icon: Icons.check_rounded,
                  label: context.l10n.selectionConfigurationApply,
                  tone: DesktopActionTone.soft,
                ),
              ),
              if (configuration.requiresToken) ...<Widget>[
                const SizedBox(height: 12),
                _SettingLine(
                  label: context.l10n.selectionApiToken,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        DesktopTextField(
                          key: const Key('settings-selection-token'),
                          controller: _tokenController,
                          obscureText: true,
                          decoration: InputDecoration(
                            hintText: context.l10n.selectionTokenPlaceholder,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                widget
                                        .viewModel
                                        .isSelectionPluginTokenConfigured
                                    ? context.l10n.selectionTokenSaved
                                    : context.l10n.selectionTokenNotSaved,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                            const SizedBox(width: 8),
                            DesktopActionButton(
                              key: const Key('settings-selection-token-save'),
                              onPressed: _saveToken,
                              label: context.l10n.saveToken,
                              tone: DesktopActionTone.soft,
                              compact: true,
                            ),
                            if (widget
                                .viewModel
                                .isSelectionPluginTokenConfigured) ...<Widget>[
                              const SizedBox(width: 6),
                              DesktopActionButton(
                                key: const Key(
                                  'settings-selection-token-clear',
                                ),
                                onPressed:
                                    widget.viewModel.clearSelectionPluginToken,
                                label: context.l10n.removeToken,
                                compact: true,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (widget.viewModel.selectionPluginConfigurationError !=
                  null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  context.l10n.selectionPluginError(
                    widget.viewModel.selectionPluginConfigurationError!.name,
                  ),
                  key: const Key('settings-selection-error'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  SelectionPluginConfiguration _configurationFromFields(
    SelectionPluginConfiguration current,
  ) {
    return current.copyWith(
      endpoint: _endpointController.text,
      model: _modelController.text,
      targetLanguage: _languageController.text,
    );
  }

  void _syncConfiguration(SelectionPluginConfiguration configuration) {
    if (_lastProvider != configuration.provider) {
      _tokenController.clear();
    }
    _lastProvider = configuration.provider;
    _replaceText(_endpointController, configuration.endpoint);
    _replaceText(_modelController, configuration.model);
    _replaceText(_languageController, configuration.targetLanguage);
  }

  void _replaceText(TextEditingController controller, String value) {
    if (controller.text == value) return;
    controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
  }

  Future<void> _saveToken() async {
    await widget.viewModel.saveSelectionPluginToken(
      _tokenController.text,
      configuration: _configurationFromFields(
        widget.viewModel.settings.selectionPlugin,
      ),
    );
    if (mounted &&
        widget.viewModel.selectionPluginConfigurationError == null &&
        widget.viewModel.isSelectionPluginTokenConfigured) {
      _tokenController.clear();
    }
  }
}

class _SettingLine extends StatelessWidget {
  const _SettingLine({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(child: Text(label)),
          const SizedBox(width: 18),
          Flexible(flex: 2, child: child),
        ],
      ),
    );
  }
}

String _providerLabel(SelectionModelProvider provider) => switch (provider) {
  SelectionModelProvider.ollama => 'Ollama',
  SelectionModelProvider.lmStudio => 'LM Studio',
  SelectionModelProvider.openRouter => 'OpenRouter',
  SelectionModelProvider.gemini => 'Gemini',
  SelectionModelProvider.openAICompatible => 'OpenAI-compatible',
};
