import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/core/widgets/compact_switch.dart';
import 'package:dingdong/core/widgets/desktop_action_button.dart';
import 'package:dingdong/core/widgets/desktop_dialog.dart';
import 'package:dingdong/core/widgets/desktop_icon_button.dart';
import 'package:dingdong/core/widgets/desktop_input_field.dart';
import 'package:dingdong/core/widgets/desktop_select_field.dart';
import 'package:dingdong/features/ai_companion/ui/ai_companion_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// One settings surface for Agent resource routing and its model connection.
class AiCompanionScreen extends StatelessWidget {
  const AiCompanionScreen({required this.controller, super.key});
  final AiCompanionController controller;
  Future<void> _configureProvider(BuildContext context) => showDialog<void>(
    context: context,
    builder: (_) => _ProviderDialog(controller: controller),
  );
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, child) {
      final l10n = context.l10n;
      return Column(
        key: const Key('ai-companion-screen'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Text(
              l10n.aiCompanionTitle,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                CompactSwitchListTile(
                  key: const Key('ai-feature-auto-resources'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.aiAutoResourceSelection),
                  subtitle: Text(l10n.aiAutoResourceSelectionDescription),
                  value: controller.settings.autoResourceSelection,
                  onChanged: controller.isLoading
                      ? null
                      : (value) => controller.saveSettings(
                          controller.settings.copyWith(
                            autoResourceSelection: value,
                          ),
                        ),
                ),
                if (controller.settings.autoResourceSelection &&
                    !controller.isConfigured)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      l10n.aiRoutingNeedsProvider,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                _Section(
                  title: l10n.aiProviderTitle,
                  children: [
                    Text(
                      !controller.isConfigured
                          ? l10n.aiProviderNotConfigured
                          : controller.connectionVerified
                          ? l10n.aiProviderVerified
                          : l10n.aiProviderNotVerified,
                    ),
                    if (controller.isConfigured) ...[
                      const SizedBox(height: 6),
                      Text(
                        controller.settings.model,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        DesktopActionButton(
                          key: const Key('ai-configure-provider'),
                          onPressed: controller.isLoading
                              ? null
                              : () => _configureProvider(context),
                          icon: const Icon(Icons.settings_outlined, size: 18),
                          label: Text(l10n.aiConfigureProvider),
                        ),
                        DesktopActionButton(
                          key: const Key('ai-test-connection'),
                          onPressed:
                              controller.isLoading || !controller.isConfigured
                              ? null
                              : controller.testConnection,
                          icon: controller.isTestingConnection
                              ? _busyIcon(context)
                              : null,
                          child: Text(
                            controller.isTestingConnection
                                ? l10n.aiTestingConnection
                                : l10n.aiTestConnection,
                          ),
                        ),
                      ],
                    ),
                    if (controller.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Semantics(
                          liveRegion: true,
                          child: Text(
                            _errorText(context, controller.error!),
                            key: const Key('ai-error'),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

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
  bool _showApiKey = false;
  final FocusNode _apiKeyFocus = FocusNode();

  Future<void> _pasteApiKey() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || data?.text == null) return;
    final selection = _apiKey.selection;
    final start = selection.isValid ? selection.start : _apiKey.text.length;
    final end = selection.isValid ? selection.end : start;
    _apiKey.value = TextEditingValue(
      text: _apiKey.text.replaceRange(start, end, data!.text!),
      selection: TextSelection.collapsed(offset: start + data.text!.length),
    );
    _apiKeyFocus.requestFocus();
  }

  late AiCompanionProtocol _protocol = widget.controller.settings.protocol;

  @override
  void dispose() {
    _endpoint.dispose();
    _model.dispose();
    _apiKey.dispose();
    _apiKeyFocus.dispose();
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
                focusNode: _apiKeyFocus,
                obscureText: !_showApiKey,
                autocorrect: false,
                enableSuggestions: false,
                enabled: !_removeKey,
                decoration: InputDecoration(
                  labelText: context.l10n.aiProviderApiKey,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DesktopIconButton(
                        key: const Key('ai-paste-api-key'),
                        tooltip: context.l10n.paste,
                        icon: const Icon(Icons.content_paste_outlined),
                        onPressed: _removeKey ? null : _pasteApiKey,
                      ),
                      DesktopIconButton(
                        key: const Key('ai-toggle-api-key'),
                        tooltip: _showApiKey
                            ? context.l10n.aiHideApiKey
                            : context.l10n.aiShowApiKey,
                        icon: Icon(
                          _showApiKey
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _showApiKey = !_showApiKey),
                      ),
                      const SizedBox(width: 6),
                    ],
                  ),
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
      AiCompanionError.credentialUnavailable =>
        context.l10n.aiErrorCredentialUnavailable,
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

Widget _busyIcon(BuildContext context) =>
    MediaQuery.disableAnimationsOf(context)
    ? const Icon(Icons.hourglass_empty, size: 14)
    : const SizedBox.square(
        dimension: 14,
        child: CircularProgressIndicator(strokeWidth: 1.5),
      );
