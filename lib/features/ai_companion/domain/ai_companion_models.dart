enum AiCompanionProtocol { auto, openAI, anthropic }

/// Only Agent resource routing and its model connection are configurable.
/// Retired insight/analysis keys in older preferences are deliberately ignored.
final class AiCompanionSettings {
  const AiCompanionSettings({
    this.autoResourceSelection = false,
    this.includeInternalInGlobal = false,
    this.providerEndpoint = '',
    this.model = '',
    this.protocol = AiCompanionProtocol.auto,
  });
  factory AiCompanionSettings.fromJson(Map<String, Object?> json) =>
      AiCompanionSettings(
        autoResourceSelection: json['autoResourceSelection'] == true,
        includeInternalInGlobal: json['includeInternalInGlobal'] == true,
        providerEndpoint: json['providerEndpoint'] is String
            ? (json['providerEndpoint']! as String).trim()
            : '',
        model: json['model'] is String ? (json['model']! as String).trim() : '',
        protocol:
            AiCompanionProtocol.values
                .where((value) => value.name == json['protocol'])
                .firstOrNull ??
            AiCompanionProtocol.auto,
      );
  final bool autoResourceSelection;
  final bool includeInternalInGlobal;
  final String providerEndpoint;
  final String model;
  final AiCompanionProtocol protocol;
  AiCompanionSettings copyWith({
    bool? autoResourceSelection,
    bool? includeInternalInGlobal,
    String? providerEndpoint,
    String? model,
    AiCompanionProtocol? protocol,
  }) => AiCompanionSettings(
    autoResourceSelection: autoResourceSelection ?? this.autoResourceSelection,
    includeInternalInGlobal:
        includeInternalInGlobal ?? this.includeInternalInGlobal,
    providerEndpoint: providerEndpoint ?? this.providerEndpoint,
    model: model ?? this.model,
    protocol: protocol ?? this.protocol,
  );
  Map<String, Object> toJson() => {
    'autoResourceSelection': autoResourceSelection,
    'includeInternalInGlobal': includeInternalInGlobal,
    'providerEndpoint': providerEndpoint,
    'model': model,
    'protocol': protocol.name,
  };
}

enum AiCompanionError {
  disabled,
  invalidProvider,
  missingApiKey,
  sensitiveOutput,
  providerUnavailable,
  authenticationFailed,
  endpointNotFound,
  rateLimited,
  invalidResponse,
  timeout,
  storageUnavailable,
  credentialUnavailable,
  requestTooLarge,
}

/// Stable diagnostics only: never contains response bodies, input or credentials.
final class AiCompanionException implements Exception {
  const AiCompanionException(this.code);
  final AiCompanionError code;
  @override
  String toString() => 'AiCompanionException(${code.name})';
}
