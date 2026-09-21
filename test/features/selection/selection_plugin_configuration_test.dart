import 'package:dingdong/features/selection/domain/selection_plugin_configuration.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('selection plugin is disabled and local-first by default', () {
    const SelectionPluginConfiguration configuration =
        SelectionPluginConfiguration();

    expect(configuration.enabled, isFalse);
    expect(configuration.provider, SelectionModelProvider.ollama);
    expect(configuration.endpoint, 'http://127.0.0.1:11434');
    expect(configuration.model, 'qwen3:0.6b');
    expect(configuration.unloadLocalModelAfterResponse, isTrue);
    expect(configuration.requiresToken, isFalse);
  });

  test('local providers reject non-loopback endpoints', () {
    final SelectionPluginConfiguration configuration =
        const SelectionPluginConfiguration().copyWith(
          endpoint: 'http://example.com:11434',
        );

    expect(configuration.validationError, isNotNull);
    expect(configuration.sanitized(), const SelectionPluginConfiguration());
  });

  test('remote providers require HTTPS and a user token', () {
    final SelectionPluginConfiguration insecure =
        const SelectionPluginConfiguration().copyWith(
          provider: SelectionModelProvider.openAICompatible,
          endpoint: 'http://api.example.com/v1',
          model: 'small-model',
        );
    final SelectionPluginConfiguration secure = insecure.copyWith(
      endpoint: 'https://api.example.com/v1',
    );

    expect(insecure.validationError, isNotNull);
    expect(secure.validationError, isNull);
    expect(secure.requiresToken, isTrue);
  });

  test(
    'Anthropic proxy supports optional local tokens and persists its protocol',
    () {
      final configuration = const SelectionPluginConfiguration()
          .withProvider(SelectionModelProvider.anthropicCompatible)
          .copyWith(endpoint: 'http://127.0.0.1:3456/v1', model: 'proxy-model');
      expect(configuration.validationError, isNull);
      expect(configuration.supportsToken, isTrue);
      expect(configuration.requiresToken, isFalse);
      expect(
        SelectionModelProvider.parse(
          configuration.toPlatformArguments()['provider'],
        ),
        SelectionModelProvider.anthropicCompatible,
      );
      expect(
        configuration
            .copyWith(endpoint: 'https://proxy.example/v1')
            .requiresToken,
        isTrue,
      );
      expect(const SelectionPluginConfiguration().supportsToken, isFalse);
    },
  );

  test('loopback OpenAI-compatible servers remain token optional', () {
    final SelectionPluginConfiguration configuration =
        const SelectionPluginConfiguration().copyWith(
          provider: SelectionModelProvider.openAICompatible,
          endpoint: 'http://localhost:1234/v1',
          model: 'local-model',
        );

    expect(configuration.validationError, isNull);
    expect(configuration.requiresToken, isFalse);
  });
}
