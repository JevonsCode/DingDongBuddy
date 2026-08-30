/// Model backends supported by DingDong's optional system-selection plugin.
enum SelectionModelProvider {
  ollama,
  lmStudio,
  openRouter,
  gemini,
  openAICompatible;

  static SelectionModelProvider parse(Object? value) {
    return values.firstWhere(
      (SelectionModelProvider provider) => provider.name == value,
      orElse: () => SelectionModelProvider.ollama,
    );
  }
}

enum SelectionPluginError {
  invalidEndpoint,
  emptyModel,
  emptyTargetLanguage,
  localEndpointRequired,
  remoteHttpsRequired,
  updateFailed,
  persistenceFailed,
  unavailable,
  statusUnavailable,
  permissionSettingsUnavailable,
  tokenRequired,
  tokenSaveFailed,
  tokenRemoveFailed,
}

/// Non-secret settings for the system-wide copy, translate and explain plugin.
///
/// API tokens deliberately do not belong here. The native gateway stores them
/// in the user's macOS Keychain under DingDong's application identity.
final class SelectionPluginConfiguration {
  const SelectionPluginConfiguration({
    this.enabled = false,
    this.provider = SelectionModelProvider.ollama,
    this.endpoint = 'http://127.0.0.1:11434',
    this.model = 'qwen3:0.6b',
    this.targetLanguage = '简体中文',
    this.unloadLocalModelAfterResponse = true,
  });

  final bool enabled;
  final SelectionModelProvider provider;
  final String endpoint;
  final String model;
  final String targetLanguage;
  final bool unloadLocalModelAfterResponse;

  bool get isLocalProvider =>
      provider == SelectionModelProvider.ollama ||
      provider == SelectionModelProvider.lmStudio;

  bool get requiresToken {
    if (provider == SelectionModelProvider.openRouter ||
        provider == SelectionModelProvider.gemini) {
      return true;
    }
    if (provider != SelectionModelProvider.openAICompatible) {
      return false;
    }
    return !_isLoopbackHttp(_parsedEndpoint);
  }

  /// A concise validation result suitable for the settings surface.
  SelectionPluginError? get validationError {
    final Uri? uri = _parsedEndpoint;
    if (uri == null ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      return SelectionPluginError.invalidEndpoint;
    }
    if (model.trim().isEmpty) {
      return SelectionPluginError.emptyModel;
    }
    if (targetLanguage.trim().isEmpty) {
      return SelectionPluginError.emptyTargetLanguage;
    }
    if (isLocalProvider && !_isLoopbackHttp(uri)) {
      return SelectionPluginError.localEndpointRequired;
    }
    if (!isLocalProvider &&
        uri.scheme.toLowerCase() != 'https' &&
        !_isLoopbackHttp(uri)) {
      return SelectionPluginError.remoteHttpsRequired;
    }
    return null;
  }

  Uri? get _parsedEndpoint {
    final String value = endpoint.trim();
    if (value.isEmpty) return null;
    return Uri.tryParse(value);
  }

  SelectionPluginConfiguration sanitized() {
    if (validationError != null) {
      return const SelectionPluginConfiguration();
    }
    return SelectionPluginConfiguration(
      enabled: enabled,
      provider: provider,
      endpoint: endpoint.trim().replaceFirst(RegExp(r'/+$'), ''),
      model: model.trim(),
      targetLanguage: targetLanguage.trim(),
      unloadLocalModelAfterResponse: unloadLocalModelAfterResponse,
    );
  }

  SelectionPluginConfiguration copyWith({
    bool? enabled,
    SelectionModelProvider? provider,
    String? endpoint,
    String? model,
    String? targetLanguage,
    bool? unloadLocalModelAfterResponse,
  }) {
    return SelectionPluginConfiguration(
      enabled: enabled ?? this.enabled,
      provider: provider ?? this.provider,
      endpoint: endpoint ?? this.endpoint,
      model: model ?? this.model,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      unloadLocalModelAfterResponse:
          unloadLocalModelAfterResponse ?? this.unloadLocalModelAfterResponse,
    );
  }

  /// Applies safe, useful defaults when the user switches provider.
  SelectionPluginConfiguration withProvider(SelectionModelProvider value) {
    final ({String endpoint, String model, bool unload}) preset =
        switch (value) {
          SelectionModelProvider.ollama => (
            endpoint: 'http://127.0.0.1:11434',
            model: 'qwen3:0.6b',
            unload: true,
          ),
          SelectionModelProvider.lmStudio => (
            endpoint: 'http://127.0.0.1:1234/v1',
            model: 'local-model',
            unload: false,
          ),
          SelectionModelProvider.openRouter => (
            endpoint: 'https://openrouter.ai/api/v1',
            model: 'openrouter/free',
            unload: false,
          ),
          SelectionModelProvider.gemini => (
            endpoint: 'https://generativelanguage.googleapis.com/v1beta/openai',
            model: 'gemini-flash-lite-latest',
            unload: false,
          ),
          SelectionModelProvider.openAICompatible => (
            endpoint: 'https://api.openai.com/v1',
            model: 'gpt-4.1-mini',
            unload: false,
          ),
        };
    return copyWith(
      provider: value,
      endpoint: preset.endpoint,
      model: preset.model,
      unloadLocalModelAfterResponse: preset.unload,
    );
  }

  Map<String, Object> toPlatformArguments() => <String, Object>{
    'enabled': enabled,
    'provider': provider.name,
    'endpoint': endpoint,
    'model': model,
    'targetLanguage': targetLanguage,
    'unloadLocalModelAfterResponse': unloadLocalModelAfterResponse,
  };

  @override
  bool operator ==(Object other) {
    return other is SelectionPluginConfiguration &&
        enabled == other.enabled &&
        provider == other.provider &&
        endpoint == other.endpoint &&
        model == other.model &&
        targetLanguage == other.targetLanguage &&
        unloadLocalModelAfterResponse == other.unloadLocalModelAfterResponse;
  }

  @override
  int get hashCode => Object.hash(
    enabled,
    provider,
    endpoint,
    model,
    targetLanguage,
    unloadLocalModelAfterResponse,
  );
}

bool _isLoopbackHttp(Uri? uri) {
  if (uri == null || uri.scheme.toLowerCase() != 'http') return false;
  return switch (uri.host.toLowerCase()) {
    'localhost' || '127.0.0.1' || '::1' => true,
    _ => false,
  };
}
