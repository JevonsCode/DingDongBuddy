import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/features/ai_companion/ui/ai_companion_controller.dart';
import 'package:flutter/material.dart';

/// Optional companion workspace. Loading or opening it never contacts a model.
class AiCompanionScreen extends StatefulWidget {
  const AiCompanionScreen({
    required this.controller,
    this.onReviewSuggestion,
    this.now,
    super.key,
  });

  final AiCompanionController controller;
  final ValueChanged<AiSuggestion>? onReviewSuggestion;
  final DateTime Function()? now;

  @override
  State<AiCompanionScreen> createState() => _AiCompanionScreenState();
}

class _AiCompanionScreenState extends State<AiCompanionScreen> {
  final TextEditingController _message = TextEditingController();
  Timer? _checkInTimer;
  DateTime? _checkInsEnabledAt;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_updateCheckInTimer);
    _updateCheckInTimer();
  }

  @override
  void didUpdateWidget(AiCompanionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_updateCheckInTimer);
    _checkInTimer?.cancel();
    _checkInTimer = null;
    _checkInsEnabledAt = null;
    widget.controller.addListener(_updateCheckInTimer);
    _updateCheckInTimer();
  }

  void _updateCheckInTimer() {
    if (!widget.controller.settings.proactiveCheckIns) {
      _checkInTimer?.cancel();
      _checkInTimer = null;
      _checkInsEnabledAt = null;
    } else {
      _checkInsEnabledAt ??= (widget.now ?? DateTime.now)();
      _checkInTimer ??= Timer.periodic(const Duration(hours: 1), (_) async {
        if (!mounted || !widget.controller.settings.proactiveCheckIns) return;
        final DateTime? previous = widget.controller.report?.createdAt;
        await widget.controller.checkIn(
          activeMinutes: (widget.now ?? DateTime.now)()
              .difference(_checkInsEnabledAt!)
              .inMinutes,
        );
        if (mounted &&
            widget.controller.error == null &&
            previous != widget.controller.report?.createdAt) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.aiTakeABreakSuggestion)),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateCheckInTimer);
    _checkInTimer?.cancel();
    _message.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    await widget.controller.sendMessage(_message.text);
    if (mounted && widget.controller.error == null) _message.clear();
  }

  Future<void> _configureProvider() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          _ProviderDialog(controller: widget.controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (BuildContext context, Widget? child) {
        final controller = widget.controller;
        final settings = controller.settings;
        final colors = Theme.of(context).colorScheme;
        return ListView(
          key: const Key('ai-companion-screen'),
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            Text(
              context.l10n.aiCompanionTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 6),
            Text(context.l10n.aiCompanionSubtitle),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.secondaryContainer.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(context.l10n.aiPrivacySummary),
            ),
            const SizedBox(height: 20),
            _Section(
              title: context.l10n.aiFeaturesTitle,
              children: <Widget>[
                _feature(
                  key: 'clipboard',
                  title: context.l10n.aiClipboardAnalysis,
                  description: context.l10n.aiClipboardAnalysisDescription,
                  value: settings.clipboardAnalysis,
                  change: (bool value) =>
                      settings.copyWith(clipboardAnalysis: value),
                ),
                _feature(
                  key: 'resources',
                  title: context.l10n.aiUsageOptimization,
                  description: context.l10n.aiUsageOptimizationDescription,
                  value: settings.usageOptimization,
                  change: (bool value) =>
                      settings.copyWith(usageOptimization: value),
                ),
                _feature(
                  key: 'progressive-disclosure',
                  title: context.l10n.aiProgressiveDisclosure,
                  description: context.l10n.aiProgressiveDisclosureDescription,
                  value: settings.progressiveDisclosure,
                  change: (bool value) =>
                      settings.copyWith(progressiveDisclosure: value),
                ),
                _feature(
                  key: 'tokens',
                  title: context.l10n.aiTokenOptimization,
                  description: context.l10n.aiTokenOptimizationDescription,
                  value: settings.tokenOptimization,
                  change: (bool value) =>
                      settings.copyWith(tokenOptimization: value),
                ),
                _feature(
                  key: 'check-ins',
                  title: context.l10n.aiProactiveCheckIns,
                  description: context.l10n.aiProactiveCheckInsDescription,
                  value: settings.proactiveCheckIns,
                  change: (bool value) =>
                      settings.copyWith(proactiveCheckIns: value),
                ),
                _feature(
                  key: 'chat',
                  title: context.l10n.aiEmotionalSupport,
                  description: context.l10n.aiEmotionalSupportDescription,
                  value: settings.emotionalSupport,
                  change: (bool value) =>
                      settings.copyWith(emotionalSupport: value),
                ),
                const Divider(),
                _feature(
                  key: 'cloud',
                  title: context.l10n.aiCloudAnalysis,
                  description: context.l10n.aiCloudAnalysisDescription,
                  value: settings.cloudAnalysis,
                  change: (bool value) =>
                      settings.copyWith(cloudAnalysis: value),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: context.l10n.aiProviderTitle,
              children: <Widget>[
                Text(
                  !controller.isConfigured
                      ? settings.providerEndpoint.isNotEmpty &&
                                settings.model.isNotEmpty
                            ? context.l10n.aiErrorMissingApiKey
                            : context.l10n.aiProviderNotConfigured
                      : controller.connectionVerified
                      ? context.l10n.aiProviderVerified
                      : context.l10n.aiProviderNotVerified,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    DesktopActionButton(
                      key: const Key('ai-configure-provider'),
                      onPressed: controller.isLoading
                          ? null
                          : _configureProvider,
                      icon: const Icon(Icons.settings_outlined, size: 18),
                      label: Text(context.l10n.aiConfigureProvider),
                    ),
                    DesktopActionButton(
                      key: const Key('ai-test-connection'),
                      onPressed:
                          controller.isLoading || !controller.isConfigured
                          ? null
                          : controller.testConnection,
                      child: Text(context.l10n.aiTestConnection),
                    ),
                  ],
                ),
              ],
            ),
            if (controller.error != null) ...<Widget>[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                child: Text(
                  _errorText(context, controller.error!),
                  key: const Key('ai-error'),
                  style: TextStyle(color: colors.error),
                ),
              ),
            ],
            if (controller.isLoading) ...<Widget>[
              const SizedBox(height: 12),
              const LinearProgressIndicator(key: Key('ai-loading')),
            ],
            const SizedBox(height: 16),
            _Section(
              title: context.l10n.aiInsightsTitle,
              children: <Widget>[
                Text(context.l10n.aiReadOnly),
                const SizedBox(height: 8),
                Text(context.l10n.aiDailyScope),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: DesktopActionButton(
                    tone: DesktopActionTone.primary,
                    key: const Key('ai-analyze'),
                    onPressed: controller.isLoading || !settings.analysisEnabled
                        ? null
                        : controller.analyze,
                    icon: const Icon(Icons.insights_outlined, size: 18),
                    label: Text(context.l10n.aiAnalyze),
                  ),
                ),
                const SizedBox(height: 12),
                if (controller.report == null)
                  Text(context.l10n.aiInsightsEmpty)
                else ...<Widget>[
                  Text(
                    controller.report!.localOnly
                        ? context.l10n.aiLocalAnalysis
                        : context.l10n.aiCloudResult,
                    key: const Key('ai-report-source'),
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  for (final suggestion in controller.report!.suggestions)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(aiSuggestionText(context, suggestion)),
                          if (suggestion.targetId != null &&
                              widget.onReviewSuggestion != null)
                            DesktopActionButton(
                              key: Key(
                                'ai-review-${suggestion.code.name}-${suggestion.targetId}',
                              ),
                              tone: DesktopActionTone.soft,
                              onPressed: () =>
                                  widget.onReviewSuggestion!(suggestion),
                              child: Text(context.l10n.aiReviewSuggestion),
                            ),
                        ],
                      ),
                    ),
                  if (controller.report!.suggestions.isEmpty &&
                      controller.report!.cloudSummary == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(context.l10n.aiNoSuggestions),
                    ),
                  if (controller.report!.cloudSummary != null) ...<Widget>[
                    const Divider(height: 24),
                    SelectableText(controller.report!.cloudSummary!),
                  ],
                ],
              ],
            ),
            const SizedBox(height: 16),
            _Section(
              title: context.l10n.aiChatTitle,
              children: <Widget>[
                Text(
                  !settings.emotionalSupport
                      ? context.l10n.aiChatDisabled
                      : !controller.isConfigured
                      ? context.l10n.aiChatNeedsProvider
                      : context.l10n.aiChatDescription,
                ),
                if (settings.emotionalSupport) ...<Widget>[
                  for (final message in controller.messages)
                    Container(
                      margin: const EdgeInsets.only(top: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: message.role == 'user'
                            ? colors.primaryContainer.withValues(alpha: 0.4)
                            : colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            message.role == 'user'
                                ? context.l10n.aiChatYou
                                : context.l10n.aiChatAssistant,
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          const SizedBox(height: 4),
                          SelectableText(message.text),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  DesktopTextField(
                    key: const Key('ai-message-input'),
                    controller: _message,
                    minLines: 2,
                    maxLines: 6,
                    maxLength: 4000,
                    enabled: !controller.isLoading && controller.isConfigured,
                    decoration: InputDecoration(
                      hintText: context.l10n.aiChatPlaceholder,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (controller.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _errorText(context, controller.error!),
                        key: const Key('ai-chat-error'),
                        style: TextStyle(color: colors.error),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      DesktopActionButton(
                        tone: DesktopActionTone.primary,
                        key: const Key('ai-send-message'),
                        onPressed:
                            controller.isLoading || !controller.isConfigured
                            ? null
                            : _sendMessage,
                        child: Text(context.l10n.aiChatSend),
                      ),
                      DesktopActionButton(
                        tone: DesktopActionTone.soft,
                        key: const Key('ai-clear-conversation'),
                        onPressed:
                            controller.isLoading || controller.messages.isEmpty
                            ? null
                            : controller.clearConversation,
                        child: Text(context.l10n.aiChatClear),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _feature({
    required String key,
    required String title,
    required String description,
    required bool value,
    required AiCompanionSettings Function(bool) change,
  }) => CompactSwitchListTile(
    key: Key('ai-feature-$key'),
    contentPadding: EdgeInsets.zero,
    title: Text(title),
    subtitle: Text(description),
    value: value,
    onChanged: widget.controller.isLoading
        ? null
        : (bool value) => widget.controller.saveSettings(change(value)),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );
}

class _ProviderDialog extends StatefulWidget {
  const _ProviderDialog({required this.controller});
  final AiCompanionController controller;

  @override
  State<_ProviderDialog> createState() => _ProviderDialogState();
}

class _ProviderDialogState extends State<_ProviderDialog> {
  late final TextEditingController _endpoint = TextEditingController(
    text: widget.controller.settings.providerEndpoint,
  );
  late final TextEditingController _model = TextEditingController(
    text: widget.controller.settings.model,
  );
  final TextEditingController _apiKey = TextEditingController();
  bool _removeKey = false;

  @override
  void dispose() {
    _endpoint.dispose();
    _model.dispose();
    _apiKey.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.controller.saveSettings(
      widget.controller.settings.copyWith(
        providerEndpoint: _endpoint.text.trim(),
        model: _model.text.trim(),
      ),
      apiKey: _apiKey.text.trim().isEmpty ? null : _apiKey.text.trim(),
      clearApiKey: _removeKey,
    );
    if (mounted && widget.controller.error == null) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (BuildContext context, Widget? child) => DesktopAlertDialog(
      maxWidth: 560,
      title: Text(context.l10n.aiProviderTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(context.l10n.aiProviderHelp),
              const SizedBox(height: 8),
              Text(context.l10n.aiProviderCredentialNote),
              const SizedBox(height: 16),
              DesktopTextField(
                key: const Key('ai-provider-endpoint'),
                controller: _endpoint,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: context.l10n.aiProviderEndpoint,
                  hintText: context.l10n.aiProviderEndpointHint,
                ),
              ),
              const SizedBox(height: 12),
              DesktopTextField(
                key: const Key('ai-provider-model'),
                controller: _model,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: context.l10n.aiProviderModel,
                ),
              ),
              const SizedBox(height: 12),
              DesktopTextField(
                key: const Key('ai-provider-api-key'),
                controller: _apiKey,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !_removeKey,
                decoration: InputDecoration(
                  labelText: context.l10n.aiProviderApiKey,
                  helperText: widget.controller.hasStoredApiKey
                      ? context.l10n.aiProviderKeyStored
                      : context.l10n.aiProviderKeyHint,
                  helperMaxLines: 3,
                ),
              ),
              if (widget.controller.hasStoredApiKey)
                CompactSwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.l10n.aiRemoveApiKey),
                  value: _removeKey,
                  onChanged: (bool? value) =>
                      setState(() => _removeKey = value ?? false),
                ),
              if (widget.controller.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _errorText(context, widget.controller.error!),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        DesktopActionButton(
          tone: DesktopActionTone.soft,
          onPressed: widget.controller.isLoading
              ? null
              : () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        DesktopActionButton(
          tone: DesktopActionTone.primary,
          key: const Key('ai-save-provider'),
          onPressed: widget.controller.isLoading ? null : _save,
          child: Text(context.l10n.save),
        ),
      ],
    ),
  );
}

String _errorText(BuildContext context, AiCompanionError error) =>
    switch (error) {
      AiCompanionError.disabled => context.l10n.aiErrorDisabled,
      AiCompanionError.invalidProvider => context.l10n.aiErrorInvalidProvider,
      AiCompanionError.missingApiKey => context.l10n.aiErrorMissingApiKey,
      AiCompanionError.sensitiveInput => context.l10n.aiErrorSensitiveInput,
      AiCompanionError.sensitiveOutput => context.l10n.aiErrorSensitiveOutput,
      AiCompanionError.providerUnavailable =>
        context.l10n.aiErrorProviderUnavailable,
      AiCompanionError.invalidResponse => context.l10n.aiErrorInvalidResponse,
      AiCompanionError.timeout => context.l10n.aiErrorTimeout,
      AiCompanionError.storageUnavailable =>
        context.l10n.aiErrorStorageUnavailable,
      AiCompanionError.emptyMessage => context.l10n.aiErrorEmptyMessage,
      AiCompanionError.messageTooLong => context.l10n.aiErrorMessageTooLong,
    };

String aiSuggestionText(BuildContext context, AiSuggestion suggestion) =>
    switch (suggestion.code) {
      AiSuggestionCode.frequentClipboard => context.l10n.aiFrequentClipboard(
        suggestion.count,
      ),
      AiSuggestionCode.repeatedClipboard => context.l10n.aiRepeatedClipboard(
        suggestion.count,
      ),
      AiSuggestionCode.ungroupedClipboard => context.l10n.aiUngroupedClipboard(
        suggestion.count,
      ),
      AiSuggestionCode.candidateWithoutUse =>
        context.l10n.aiCandidateWithoutUse(suggestion.count),
      AiSuggestionCode.alwaysOnUnused => context.l10n.aiAlwaysOnUnused,
      AiSuggestionCode.progressivePrompt => context.l10n.aiProgressivePrompt(
        suggestion.count,
      ),
      AiSuggestionCode.progressiveMcp => context.l10n.aiProgressiveMcp,
      AiSuggestionCode.largeAlwaysOnPrompt =>
        context.l10n.aiLargeAlwaysOnPrompt(suggestion.count),
      AiSuggestionCode.highInputTokens => context.l10n.aiHighInputTokens(
        suggestion.count,
      ),
      AiSuggestionCode.lowCacheReuse => context.l10n.aiLowCacheReuse(
        suggestion.count,
      ),
      AiSuggestionCode.incompleteTokenData =>
        context.l10n.aiIncompleteTokenData,
      AiSuggestionCode.takeBreak => context.l10n.aiTakeABreakSuggestion,
    };
