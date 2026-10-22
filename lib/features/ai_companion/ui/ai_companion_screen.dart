import 'dart:async';

import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:dingdong/features/ai_companion/ui/ai_companion_controller.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../token_usage/domain/token_usage_models.dart';

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

class _AiCompanionScreenState extends State<AiCompanionScreen>
    with WidgetsBindingObserver {
  Timer? _checkInTimer;
  final _scrollController = ScrollController();
  DateTime? _checkInsEnabledAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(widget.controller.refreshInternalUsage());
    widget.controller.addListener(_updateCheckInTimer);
    _updateCheckInTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.controller.refreshInternalUsage());
    }
  }

  @override
  void didUpdateWidget(AiCompanionScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    unawaited(widget.controller.refreshInternalUsage());
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
    WidgetsBinding.instance.removeObserver(this);
    widget.controller.removeListener(_updateCheckInTimer);
    _checkInTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _configureProvider() async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) =>
          _ProviderDialog(controller: widget.controller),
    );
  }

  Future<void> _analyze() async {
    _scrollController.jumpTo(0);
    await widget.controller.analyze();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, child) {
      final controller = widget.controller;
      final settings = controller.settings;
      final l10n = context.l10n;
      final colors = Theme.of(context).colorScheme;
      return Column(
        key: const Key('ai-companion-screen'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final title = Text(
                  l10n.aiCompanionTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                );
                final action = DesktopActionButton(
                  tone: DesktopActionTone.primary,
                  key: const Key('ai-analyze'),
                  onPressed: controller.isLoading || !settings.analysisEnabled
                      ? null
                      : _analyze,
                  icon: const Icon(Icons.insights_outlined, size: 18),
                  label: Text(l10n.aiAnalyze),
                );
                return constraints.maxWidth < 420
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [title, const SizedBox(height: 12), action],
                      )
                    : Row(
                        children: [
                          Expanded(child: title),
                          action,
                        ],
                      );
              },
            ),
          ),
          const Divider(height: 1),
          if (controller.isLoading)
            const LinearProgressIndicator(key: Key('ai-loading')),
          if (controller.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _errorText(context, controller.error!),
                  key: const Key('ai-error'),
                  style: TextStyle(color: colors.error),
                ),
              ),
            ),
          Expanded(
            child: ListView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: [
                _insights(context),
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _feature(
                        key: 'auto-resources',
                        title: l10n.aiAutoResourceSelection,
                        description: l10n.aiAutoResourceSelectionDescription,
                        value: settings.autoResourceSelection,
                        change: (value) =>
                            settings.copyWith(autoResourceSelection: value),
                      ),
                      if (settings.autoResourceSelection &&
                          !controller.isConfigured)
                        Text(
                          l10n.aiRoutingNeedsProvider,
                          style: TextStyle(color: colors.onSurfaceVariant),
                        ),
                    ],
                  ),
                ),
                _Section(
                  title: l10n.aiFeaturesTitle,
                  children: [
                    _feature(
                      key: 'clipboard',
                      title: l10n.aiClipboardAnalysis,
                      description: l10n.aiClipboardAnalysisDescription,
                      value: settings.clipboardAnalysis,
                      change: (value) =>
                          settings.copyWith(clipboardAnalysis: value),
                    ),
                    _feature(
                      key: 'resources',
                      title: l10n.aiUsageOptimization,
                      description: l10n.aiUsageOptimizationDescription,
                      value: settings.usageOptimization,
                      change: (value) =>
                          settings.copyWith(usageOptimization: value),
                    ),
                    _feature(
                      key: 'progressive-disclosure',
                      title: l10n.aiProgressiveDisclosure,
                      description: l10n.aiProgressiveDisclosureDescription,
                      value: settings.progressiveDisclosure,
                      change: (value) =>
                          settings.copyWith(progressiveDisclosure: value),
                    ),
                    _feature(
                      key: 'tokens',
                      title: l10n.aiTokenOptimization,
                      description: l10n.aiTokenOptimizationDescription,
                      value: settings.tokenOptimization,
                      change: (value) =>
                          settings.copyWith(tokenOptimization: value),
                    ),
                    _feature(
                      key: 'cloud',
                      title: l10n.aiCloudAnalysis,
                      description: l10n.aiCloudAnalysisDescription,
                      value: settings.cloudAnalysis,
                      change: (value) =>
                          settings.copyWith(cloudAnalysis: value),
                    ),
                    _feature(
                      key: 'check-ins',
                      title: l10n.aiProactiveCheckIns,
                      description: l10n.aiProactiveCheckInsDescription,
                      value: settings.proactiveCheckIns,
                      change: (value) =>
                          settings.copyWith(proactiveCheckIns: value),
                    ),
                  ],
                ),
                _Section(
                  title: l10n.aiProviderTitle,
                  children: [
                    Text(
                      !controller.isConfigured
                          ? settings.providerEndpoint.isNotEmpty &&
                                    settings.model.isNotEmpty
                                ? l10n.aiErrorMissingApiKey
                                : l10n.aiProviderNotConfigured
                          : controller.connectionVerified
                          ? l10n.aiProviderVerified
                          : l10n.aiProviderNotVerified,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        DesktopActionButton(
                          key: const Key('ai-configure-provider'),
                          onPressed: controller.isLoading
                              ? null
                              : _configureProvider,
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          label: Text(l10n.aiConfigureProvider),
                        ),
                        DesktopActionButton(
                          key: const Key('ai-test-connection'),
                          onPressed:
                              controller.isLoading || !controller.isConfigured
                              ? null
                              : controller.testConnection,
                          child: Text(l10n.aiTestConnection),
                        ),
                      ],
                    ),
                  ],
                ),
                _internalUsage(context),
              ],
            ),
          ),
        ],
      );
    },
  );

  Widget _insights(BuildContext context) {
    final report = widget.controller.report;
    final settings = widget.controller.settings;
    final l10n = context.l10n;
    final groups = <(String, String, bool, Set<AiSuggestionCode>)>[
      (
        'clipboard',
        l10n.aiClipboardAnalysis,
        settings.clipboardAnalysis,
        {
          AiSuggestionCode.frequentClipboard,
          AiSuggestionCode.repeatedClipboard,
          AiSuggestionCode.ungroupedClipboard,
        },
      ),
      (
        'resources',
        l10n.aiUsageOptimization,
        settings.usageOptimization,
        {AiSuggestionCode.candidateWithoutUse, AiSuggestionCode.alwaysOnUnused},
      ),
      (
        'disclosure',
        l10n.aiProgressiveDisclosure,
        settings.progressiveDisclosure,
        {AiSuggestionCode.progressivePrompt, AiSuggestionCode.progressiveMcp},
      ),
      (
        'tokens',
        l10n.aiTokenOptimization,
        settings.tokenOptimization,
        {
          AiSuggestionCode.largeAlwaysOnPrompt,
          AiSuggestionCode.highInputTokens,
          AiSuggestionCode.lowCacheReuse,
          AiSuggestionCode.incompleteTokenData,
        },
      ),
      (
        'check-ins',
        l10n.aiProactiveCheckIns,
        settings.proactiveCheckIns,
        {AiSuggestionCode.takeBreak},
      ),
    ];
    return _Section(
      title: l10n.aiInsightsTitle,
      children: [
        if (report == null)
          Text(l10n.aiInsightsEmpty)
        else ...[
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                report.localOnly ? l10n.aiLocalAnalysis : l10n.aiCloudResult,
                key: const Key('ai-report-source'),
              ),
              Text(
                DateFormat.yMd(
                  Localizations.localeOf(context).toLanguageTag(),
                ).add_Hm().format(report.createdAt.toLocal()),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          for (final (id, title, enabled, codes) in groups)
            if (enabled &&
                (id != 'check-ins' ||
                    report.suggestions.any((s) => codes.contains(s.code))))
              Padding(
                key: Key('ai-result-$id'),
                padding: const EdgeInsets.only(top: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 6),
                    if (!report.suggestions.any((s) => codes.contains(s.code)))
                      Text(
                        l10n.aiCategoryNoSuggestions,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    for (final suggestion in report.suggestions.where(
                      (s) => codes.contains(s.code),
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
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
                                child: Text(l10n.aiReviewSuggestion),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
          if (report.cloudSummary != null) ...[
            const SizedBox(height: 16),
            Text(
              l10n.aiCloudResult,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            SelectableText(report.cloudSummary!),
          ],
        ],
        const SizedBox(height: 12),
        Text(l10n.aiReadOnly, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        Text(l10n.aiDailyScope, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Widget _internalUsage(BuildContext context) {
    final controller = widget.controller;
    final settings = controller.settings;
    final l10n = context.l10n;
    final now = (widget.now ?? DateTime.now)().toLocal();
    final today = controller.internalUsage.days.where(
      (d) =>
          d.day.year == now.year &&
          d.day.month == now.month &&
          d.day.day == now.day,
    );
    final format = NumberFormat.decimalPattern(
      Localizations.localeOf(context).toLanguageTag(),
    );
    String count(int? n) =>
        n == null ? l10n.aiInternalUnknown : format.format(n);
    Widget row(String title, TokenUsageTotals totals, int requests) {
      final total = totals.totalIsExact
          ? count(totals.totalTokens)
          : totals.totalTokens == 0
          ? l10n.aiInternalUnknown
          : '≥${count(totals.totalTokens)}';
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$title: $total Token · ${l10n.aiInternalRequests(requests)}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              '${l10n.tokenUsageInput} ${count(totals.inputTokens)} · ${l10n.tokenUsageOutput} ${count(totals.outputTokens)} · ${l10n.tokenUsageCacheRead} ${count(totals.cachedInputTokens)} · ${l10n.tokenUsageCacheWrite} ${count(totals.cacheWriteInputTokens)}',
            ),
          ],
        ),
      );
    }

    return _Section(
      title: l10n.aiInternalUsageTitle,
      action: DesktopIconButton(
        key: const Key('ai-refresh-usage'),
        tooltip: l10n.refresh,
        onPressed: controller.refreshInternalUsage,
        icon: const Icon(Icons.refresh, size: 18),
      ),
      children: [
        Text(l10n.aiInternalUsageDescription),
        _feature(
          key: 'include-internal',
          title: l10n.aiIncludeInternal,
          description: l10n.aiIncludeInternalDescription,
          value: settings.includeInternalInGlobal,
          change: (value) => settings.copyWith(includeInternalInGlobal: value),
        ),
        if (!controller.usageStorageAvailable)
          Text(
            l10n.aiInternalStorageError,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          )
        else ...[
          row(
            l10n.tokenUsageToday,
            TokenUsageTotals.sum(today.map((d) => d.totals)),
            today.fold(0, (n, d) => n + d.eventCount),
          ),
          row(
            l10n.aiInternalCumulative,
            controller.internalUsage.totals,
            controller.internalUsage.days.fold(0, (n, d) => n + d.eventCount),
          ),
        ],
        if (controller.lastUsage != null)
          row(l10n.aiInternalLast, controller.lastUsage!.totals, 1),
        const SizedBox(height: 8),
        Text(
          l10n.aiInternalPartial,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
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
  const _Section({required this.title, required this.children, this.action});
  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ?action,
          ],
        ),
        const Divider(height: 20),
        ...children,
      ],
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
  late AiCompanionProtocol _protocol = widget.controller.settings.protocol;

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
        protocol: _protocol,
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
              Text(context.l10n.aiProviderProtocol),
              const SizedBox(height: 6),
              DesktopSelectField<AiCompanionProtocol>(
                key: const Key('ai-provider-protocol'),
                semanticLabel: context.l10n.aiProviderProtocol,
                value: _protocol,
                items: <DesktopSelectItem<AiCompanionProtocol>>[
                  DesktopSelectItem(
                    value: AiCompanionProtocol.auto,
                    label: context.l10n.aiProviderProtocolAuto,
                  ),
                  const DesktopSelectItem(
                    value: AiCompanionProtocol.openAI,
                    label: 'OpenAI Chat Completions',
                  ),
                  const DesktopSelectItem(
                    value: AiCompanionProtocol.anthropic,
                    label: 'Anthropic Messages',
                  ),
                ],
                onChanged: (value) => setState(() => _protocol = value),
              ),
              const SizedBox(height: 12),
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
      AiCompanionError.sensitiveOutput => context.l10n.aiErrorSensitiveOutput,
      AiCompanionError.providerUnavailable =>
        context.l10n.aiErrorProviderUnavailable,
      AiCompanionError.authenticationFailed =>
        context.l10n.aiErrorAuthenticationFailed,
      AiCompanionError.endpointNotFound => context.l10n.aiErrorEndpointNotFound,
      AiCompanionError.rateLimited => context.l10n.aiErrorRateLimited,
      AiCompanionError.invalidResponse => context.l10n.aiErrorInvalidResponse,
      AiCompanionError.timeout => context.l10n.aiErrorTimeout,
      AiCompanionError.storageUnavailable =>
        context.l10n.aiErrorStorageUnavailable,
      AiCompanionError.requestTooLarge => context.l10n.aiErrorRequestTooLarge,
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
