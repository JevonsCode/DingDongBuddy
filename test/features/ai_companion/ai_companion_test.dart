import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/clipboard_record.dart';
import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/ai_companion/data/ai_companion_client.dart';
import 'package:dingdong/features/ai_companion/data/ai_companion_store.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_analyzer.dart';
import 'package:dingdong/features/ai_companion/domain/ai_companion_privacy.dart';
import 'package:dingdong/features/ai_companion/ui/ai_companion_controller.dart';
import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/token_usage/domain/token_usage_models.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime.utc(2026, 10, 21, 12);

void main() {
  test(
    'analysis category or provider changes clear visible and persisted cloud text',
    () async {
      final changes =
          <String, AiCompanionSettings Function(AiCompanionSettings)>{
            'clipboard': (settings) =>
                settings.copyWith(clipboardAnalysis: false),
            'usage': (settings) => settings.copyWith(usageOptimization: false),
            'progressive': (settings) =>
                settings.copyWith(progressiveDisclosure: false),
            'tokens': (settings) => settings.copyWith(tokenOptimization: false),
            'endpoint': (settings) =>
                settings.copyWith(providerEndpoint: 'https://other.example/v1'),
            'model': (settings) => settings.copyWith(model: 'other-model'),
          };
      for (final change in changes.entries) {
        final backend = MemoryPreferencesBackend();
        final secrets = _Secrets();
        final transport = _Transport()
          ..reply = 'Review progressive disclosure and resource usage.';
        final controller = _controller(
          backend: backend,
          secrets: secrets,
          transport: transport,
          loader: () async => AiCompanionMetadata(
            resources: <Resource>[
              _resource('prompt', ResourceType.prompt),
              _resource('mcp', ResourceType.mcp, candidates: 8),
            ],
          ),
        );
        addTearDown(controller.dispose);
        await controller.saveSettings(
          _configured.copyWith(
            clipboardAnalysis: true,
            usageOptimization: true,
            progressiveDisclosure: true,
            tokenOptimization: true,
            cloudAnalysis: true,
          ),
          apiKey: 'dummy',
        );
        await controller.analyze();
        expect(controller.report!.cloudSummary, isNotNull, reason: change.key);
        expect(controller.report!.localOnly, false, reason: change.key);
        await controller.saveSettings(change.value(controller.settings));
        expect(controller.error, isNull, reason: change.key);
        expect(controller.report!.cloudSummary, isNull, reason: change.key);
        expect(controller.report!.localOnly, true, reason: change.key);
        if (change.key == 'progressive') {
          expect(controller.settings.usageOptimization, true);
          expect(controller.settings.cloudAnalysis, true);
          expect(
            controller.report!.suggestions.map((item) => item.code),
            contains(AiSuggestionCode.candidateWithoutUse),
          );
          expect(
            controller.report!.suggestions.any(
              (item) =>
                  item.code == AiSuggestionCode.progressivePrompt ||
                  item.code == AiSuggestionCode.progressiveMcp,
            ),
            false,
          );
        }
        final stored = await AiCompanionPreferencesStore(
          backend,
          secretStore: secrets,
        ).loadReport();
        expect(stored!.cloudSummary, isNull, reason: change.key);
        expect(stored.localOnly, true, reason: change.key);
        expect(transport.requests, hasLength(1), reason: change.key);
      }
    },
  );

  test('empty token metadata omits counts and reports incomplete coverage', () {
    final safe = const AiCompanionAnalyzer().cloudMetadata(
      const AiCompanionSettings(tokenOptimization: true),
      const AiCompanionMetadata(),
    );
    final tokens = safe['tokens']! as Map;
    for (final String key in <String>[
      'total',
      'input',
      'output',
      'cachedInput',
    ]) {
      expect(tokens.containsKey(key), false);
    }
    expect(tokens['dataAvailable'], false);
    expect(tokens['complete'], false);
  });

  test(
    'all switches default off and loading never reads local data or network',
    () async {
      final _Transport transport = _Transport();
      int reads = 0;
      final AiCompanionController controller = _controller(
        transport: transport,
        loader: () async {
          reads++;
          return const AiCompanionMetadata();
        },
      );
      addTearDown(controller.dispose);
      await controller.load();
      expect(
        controller.settings.toJson().values.whereType<bool>(),
        everyElement(false),
      );
      expect(
        controller.settings.toJson().values.whereType<bool>(),
        hasLength(7),
      );
      expect(
        AiCompanionSettings.fromJson(<String, Object?>{}).progressiveDisclosure,
        false,
      );
      await controller.analyze();
      expect(controller.error, AiCompanionError.disabled);
      await controller.sendMessage('Hello');
      expect(controller.error, AiCompanionError.disabled);
      await controller.checkIn(activeMinutes: 120);
      expect(reads, 0);
      expect(transport.requests, isEmpty);
      expect(controller.report, isNull);
    },
  );

  test(
    'progressive disclosure is independently persisted and locally targeted',
    () async {
      final metadata = AiCompanionMetadata(
        clipboard: <ClipboardRecord>[_clip('clipboard', copyCount: 5)],
        resources: <Resource>[
          _resource(
            'prompt',
            ResourceType.prompt,
            content: 'Short prompt',
            uses: 8,
          ),
          _resource('mcp', ResourceType.mcp, candidates: 12, uses: 8),
          _resource('skill', ResourceType.skill, candidates: 12),
          _resource('disabled', ResourceType.prompt).copyWith(enabled: false),
          _resource(
            'manual',
            ResourceType.mcp,
          ).copyWith(activation: ResourceActivation.manual),
          _resource(
            'matched',
            ResourceType.prompt,
          ).copyWith(activation: ResourceActivation.taskMatch),
        ],
        tokenUsage: _tokenSnapshot(),
      );
      const active = AiCompanionSettings(progressiveDisclosure: true);
      expect(active.analysisEnabled, true);
      final defaults = await const AiCompanionAnalyzer().analyze(
        const AiCompanionSettings(),
        metadata,
        _now,
      );
      expect(defaults.suggestions, isEmpty);
      final report = await const AiCompanionAnalyzer().analyze(
        active,
        metadata,
        _now,
      );
      expect(report.suggestions.map((item) => item.code), <AiSuggestionCode>[
        AiSuggestionCode.progressivePrompt,
        AiSuggestionCode.progressiveMcp,
      ]);
      expect(report.suggestions.map((item) => item.targetId), <String>[
        'prompt',
        'mcp',
      ]);
      expect(report.suggestions.first.count, 'Short prompt'.length);
      expect(report.suggestions.last.count, 1);
      final backend = MemoryPreferencesBackend();
      final secrets = _Secrets();
      final transport = _Transport();
      final controller = _controller(
        transport: transport,
        backend: backend,
        secrets: secrets,
        loader: () async => metadata,
      );
      addTearDown(controller.dispose);
      await controller.saveSettings(active);
      await controller.analyze();
      expect(controller.error, isNull);
      expect(controller.report!.suggestions, hasLength(2));
      final restored = _controller(backend: backend, secrets: secrets);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.settings.progressiveDisclosure, true);
      expect(restored.report!.suggestions, hasLength(2));
      await restored.saveSettings(
        active.copyWith(progressiveDisclosure: false, usageOptimization: true),
      );
      expect(restored.report!.suggestions, isEmpty);
      expect(transport.requests, isEmpty);
    },
  );

  test(
    'progressive-only cloud payload has no usage, clipboard or token metadata',
    () async {
      final transport = _Transport();
      final client = AiCompanionClient(transport: transport);
      addTearDown(client.dispose);
      final metadata = AiCompanionMetadata(
        resources: <Resource>[
          _resource(
            'private-prompt-id',
            ResourceType.prompt,
            title: 'private title',
            content: 'password=private prompt',
            candidates: 99,
          ),
          _resource(
            'private-mcp-id',
            ResourceType.mcp,
            content:
                '{"url":"https://private.example/path","apiKey":"private"}',
            uses: 77,
          ),
          _resource('disabled', ResourceType.prompt).copyWith(enabled: false),
          _resource('skill', ResourceType.skill),
        ],
        clipboard: <ClipboardRecord>[
          _clip('private-clip', text: 'private clipboard'),
        ],
        tokenUsage: _tokenSnapshot(),
      );
      await client.analyze(
        _configured.copyWith(progressiveDisclosure: true, cloudAnalysis: true),
        'dummy',
        metadata,
      );
      final payload = jsonDecode(transport.requests.single.body) as Map;
      final encoded =
          ((payload['messages'] as List).last as Map)['content'] as String;
      final safe = jsonDecode(encoded) as Map;
      expect(safe.keys.toSet(), <String>{'schema', 'progressiveDisclosure'});
      final entries = safe['progressiveDisclosure'] as List;
      expect(entries, hasLength(2));
      expect((entries.first as Map).keys.toSet(), <String>{
        'id',
        'kind',
        'activation',
        'promptCharacterCount',
      });
      expect((entries.last as Map).keys.toSet(), <String>{
        'id',
        'kind',
        'activation',
      });
      expect(
        (entries.first as Map)['promptCharacterCount'],
        'password=private prompt'.length,
      );
      expect((entries.first as Map)['id'], 'r1');
      expect((entries.last as Map)['id'], 'r2');
      for (final forbidden in <String>[
        'private',
        'password',
        'candidateCount',
        'invocationCount',
        'activationOrLoadCount',
        'tokens',
        'clipboard',
        'resources',
      ]) {
        expect(encoded.contains(forbidden), false, reason: forbidden);
      }
      final disabled = const AiCompanionAnalyzer().cloudMetadata(
        const AiCompanionSettings(usageOptimization: true),
        metadata,
      );
      expect(disabled.containsKey('progressiveDisclosure'), false);
      final system =
          ((payload['messages'] as List).first as Map)['content'] as String;
      expect(
        system,
        contains('native client tool-list protocols are unchanged'),
      );
    },
  );

  test(
    'independent switches gate clipboard, resource, and token suggestions',
    () async {
      final AiCompanionMetadata metadata = AiCompanionMetadata(
        clipboard: <ClipboardRecord>[_clip('one', copyCount: 4), _clip('two')],
        resources: <Resource>[
          _resource('mcp', ResourceType.mcp, candidates: 8, uses: 100),
          _resource('skill', ResourceType.skill, candidates: 8, uses: 1),
          _resource(
            'prompt',
            ResourceType.prompt,
            content: List.filled(2100, 'x').join(),
          ),
        ],
        tokenUsage: _tokenSnapshot(),
      );
      const AiCompanionAnalyzer analyzer = AiCompanionAnalyzer();
      final clipboard = await analyzer.analyze(
        const AiCompanionSettings(clipboardAnalysis: true),
        metadata,
        _now,
      );
      expect(
        clipboard.suggestions.map((item) => item.code),
        containsAll(<AiSuggestionCode>[
          AiSuggestionCode.frequentClipboard,
          AiSuggestionCode.repeatedClipboard,
        ]),
      );
      expect(
        clipboard.suggestions.every(
          (item) => item.code.name.contains('Clipboard'),
        ),
        true,
      );
      final usage = await analyzer.analyze(
        const AiCompanionSettings(usageOptimization: true),
        metadata,
        _now,
      );
      expect(
        usage.suggestions
            .where((item) => item.code == AiSuggestionCode.candidateWithoutUse)
            .map((item) => item.targetId),
        <String>['mcp'],
      );
      expect(
        usage.suggestions.any(
          (item) => item.code == AiSuggestionCode.largeAlwaysOnPrompt,
        ),
        false,
      );
      final tokens = await analyzer.analyze(
        const AiCompanionSettings(tokenOptimization: true),
        metadata,
        _now,
      );
      expect(
        tokens.suggestions.map((item) => item.code),
        containsAll(<AiSuggestionCode>[
          AiSuggestionCode.largeAlwaysOnPrompt,
          AiSuggestionCode.highInputTokens,
          AiSuggestionCode.lowCacheReuse,
        ]),
      );
      expect(
        tokens.suggestions.any(
          (item) => item.code == AiSuggestionCode.candidateWithoutUse,
        ),
        false,
      );
    },
  );

  test(
    'sensitive, image and file clipboard entries never become suggestions',
    () async {
      final report = await const AiCompanionAnalyzer().analyze(
        const AiCompanionSettings(clipboardAnalysis: true),
        AiCompanionMetadata(
          clipboard: <ClipboardRecord>[
            _clip('secret', text: 'password=visible', copyCount: 5),
            _clip('tagged', tags: <String>['sensitive'], copyCount: 5),
            _clip('image', tags: <String>['image'], copyCount: 5),
            _clip('file', tags: <String>['file'], copyCount: 5),
          ],
        ),
        _now,
      );
      expect(report.suggestions, isEmpty);
    },
  );

  test(
    'cloud analysis serializes only anonymous whitelisted metadata',
    () async {
      final _Transport transport = _Transport();
      final AiCompanionClient client = AiCompanionClient(transport: transport);
      addTearDown(client.dispose);
      const String sentinel = 'private-secret-resource-name';
      await client.analyze(
        _configured.copyWith(
          cloudAnalysis: true,
          clipboardAnalysis: true,
          usageOptimization: true,
          tokenOptimization: true,
        ),
        'dummy',
        AiCompanionMetadata(
          resources: <Resource>[
            _resource(
              sentinel,
              ResourceType.mcp,
              title: 'secret-title',
              content: 'password=private-value',
              candidates: 9,
            ),
          ],
          clipboard: <ClipboardRecord>[
            _clip('private-clipboard-id', text: 'private clipboard contents'),
            _clip(
              'file-id',
              text: r'C:\private\file.png',
              tags: <String>['image'],
            ),
          ],
          tokenUsage: _tokenSnapshot(),
        ),
      );
      final String raw = transport.requests.single.body;
      for (final String forbidden in <String>[
        sentinel,
        'secret-title',
        'password',
        'private-value',
        'private-clipboard-id',
        'private clipboard contents',
        'file.png',
        'private-group',
        'private-source',
      ]) {
        expect(raw.contains(forbidden), false, reason: forbidden);
      }
      final Map<String, Object?> payload =
          jsonDecode(raw) as Map<String, Object?>;
      final messages = payload['messages']! as List;
      final Map<String, Object?> metadata =
          jsonDecode((messages.last as Map)['content'] as String)
              as Map<String, Object?>;
      expect(metadata.keys.toSet(), <String>{
        'schema',
        'clipboard',
        'resources',
        'tokens',
      });
      final resource = (metadata['resources']! as List).single as Map;
      expect(resource['id'], 'r1');
      expect(resource['kind'], 'mcp');
      expect(resource.keys.toSet(), <String>{
        'id',
        'kind',
        'activation',
        'enabled',
        'candidateCount',
        'activationOrLoadCount',
        'invocationCount',
      });
      expect(payload.keys.toSet(), <String>{
        'model',
        'messages',
        'stream',
        'max_tokens',
      });
    },
  );

  test(
    'disabled categories are absent even when other cloud analysis is on',
    () async {
      final _Transport transport = _Transport();
      final AiCompanionClient client = AiCompanionClient(transport: transport);
      addTearDown(client.dispose);
      await client.analyze(
        _configured.copyWith(cloudAnalysis: true, usageOptimization: true),
        'dummy',
        AiCompanionMetadata(
          resources: <Resource>[_resource('private', ResourceType.skill)],
        ),
      );
      final payload = jsonDecode(transport.requests.single.body) as Map;
      final metadata =
          jsonDecode(
                ((payload['messages'] as List).last as Map)['content']
                    as String,
              )
              as Map;
      expect(metadata.keys.toSet(), <String>{'schema', 'resources'});
      await expectLater(
        client.analyze(
          _configured.copyWith(usageOptimization: true),
          'dummy',
          const AiCompanionMetadata(),
        ),
        _fails(AiCompanionError.disabled),
      );
      expect(transport.requests, hasLength(1));
    },
  );

  test(
    'unknown token components remain unknown and coverage is explicit',
    () async {
      final AiCompanionMetadata metadata = AiCompanionMetadata(
        tokenUsage: TokenUsageSnapshot(
          days: <TokenUsageDay>[
            TokenUsageDay(
              day: _now,
              source: ConversationTokenUsageSource.codex,
              totals: const TokenUsageTotals(
                totalTokens: 100,
                inputTokens: null,
              ),
            ),
          ],
          storageAvailable: false,
        ),
      );
      final safe = const AiCompanionAnalyzer().cloudMetadata(
        const AiCompanionSettings(tokenOptimization: true),
        metadata,
      );
      final tokens = safe['tokens']! as Map;
      expect(tokens.containsKey('input'), false);
      expect(tokens.containsKey('output'), false);
      expect(tokens['complete'], false);
      expect(tokens['storageAvailable'], false);
      final report = await const AiCompanionAnalyzer().analyze(
        const AiCompanionSettings(tokenOptimization: true),
        metadata,
        _now,
      );
      expect(
        report.suggestions.single.code,
        AiSuggestionCode.incompleteTokenData,
      );
    },
  );

  for (final String input in <String>[
    'password=short',
    'my password is short',
    '密码是简单密码',
    'Bearer abc123',
    'sk-proj-abcdefghijklmno',
    'ghp_abcdefghijklmnopqrstuvwxyz',
    'eyJabc.def.ghi',
    '-----BEGIN PRIVATE KEY-----',
    'abcdefABCDEF1234567890abcdefABCDEF1234567890',
    r'C:\Users\private\secrets',
    '/Users/private/secrets',
    '../private/data',
    '~/private/data',
    'photo.png',
    'notes.txt',
    'data:image/png;base64,abc',
    '![picture](anything)',
    'https://private.example/image',
  ]) {
    test(
      'local chat filter blocks sensitive or file input: ${input.length} chars ${input.hashCode}',
      () async {
        final _Transport transport = _Transport();
        final controller = _controller(transport: transport);
        addTearDown(controller.dispose);
        await controller.saveSettings(
          _configured.copyWith(emotionalSupport: true),
          apiKey: 'dummy',
        );
        await controller.sendMessage(input);
        expect(controller.error, AiCompanionError.sensitiveInput);
        expect(controller.messages, isEmpty);
        expect(transport.requests, isEmpty);
      },
    );
  }

  test(
    'chat output is filtered, API key echo blocked, history never persisted',
    () async {
      final _Transport transport = _Transport()..reply = 'password=leaked';
      final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
      final _Secrets secrets = _Secrets();
      int reads = 0;
      final controller = _controller(
        transport: transport,
        backend: backend,
        secrets: secrets,
        loader: () async {
          reads++;
          return const AiCompanionMetadata();
        },
      );
      addTearDown(controller.dispose);
      await controller.saveSettings(
        _configured.copyWith(emotionalSupport: true),
        apiKey: 'unusual-short-provider-key',
      );
      await controller.sendMessage('I feel overwhelmed today.');
      expect(controller.error, AiCompanionError.sensitiveOutput);
      expect(controller.messages, isEmpty);
      transport.reply = 'unusual-short-provider-key';
      await controller.sendMessage('Please help me take a break.');
      expect(controller.error, AiCompanionError.sensitiveOutput);
      transport.reply = 'A short pause can help. What feels most urgent?';
      await controller.sendMessage('I feel overwhelmed today.');
      expect(controller.error, isNull);
      expect(controller.messages, hasLength(2));
      expect(reads, 0);
      final String saved = jsonEncode(backend.values);
      expect(saved.contains('unusual-short-provider-key'), false);
      expect(saved.contains('overwhelmed'), false);
      expect(secrets.value, 'unusual-short-provider-key');
    },
  );

  test('provider endpoint change drops the previous credential', () async {
    final _Transport transport = _Transport();
    final _Secrets secrets = _Secrets();
    final controller = _controller(transport: transport, secrets: secrets);
    addTearDown(controller.dispose);
    await controller.saveSettings(
      _configured.copyWith(emotionalSupport: true),
      apiKey: 'dummy',
    );
    await controller.saveSettings(
      controller.settings.copyWith(
        providerEndpoint: 'https://other.example/v1',
      ),
    );
    expect(controller.hasStoredApiKey, false);
    expect(secrets.value, isNull);
    await controller.sendMessage('Hello');
    expect(controller.error, AiCompanionError.missingApiKey);
    expect(transport.requests, isEmpty);
  });

  test(
    'local analysis needs neither provider nor network and reports reload',
    () async {
      final _Transport transport = _Transport();
      final backend = MemoryPreferencesBackend();
      final secrets = _Secrets();
      final controller = _controller(
        transport: transport,
        backend: backend,
        secrets: secrets,
        loader: () async => AiCompanionMetadata(
          clipboard: <ClipboardRecord>[_clip('local', copyCount: 5)],
        ),
      );
      addTearDown(controller.dispose);
      await controller.saveSettings(
        const AiCompanionSettings(clipboardAnalysis: true),
      );
      await controller.analyze();
      expect(controller.error, isNull);
      expect(controller.report!.localOnly, true);
      expect(
        controller.report!.suggestions.single.code,
        AiSuggestionCode.frequentClipboard,
      );
      expect(transport.requests, isEmpty);
      final restored = _controller(backend: backend, secrets: secrets);
      addTearDown(restored.dispose);
      await restored.load();
      expect(restored.report!.suggestions.single.targetId, 'local');
      await restored.saveSettings(const AiCompanionSettings());
      expect(restored.report, isNull);
      expect(
        backend.values.containsKey(AiCompanionPreferencesStore.reportKey),
        false,
      );
    },
  );

  test('permission revocation ignores a late cloud response', () async {
    final Completer<AiCompanionHttpResponse> pending =
        Completer<AiCompanionHttpResponse>();
    final _Transport transport = _Transport()..pending = pending;
    final controller = _controller(transport: transport);
    addTearDown(controller.dispose);
    await controller.saveSettings(
      _configured.copyWith(clipboardAnalysis: true, cloudAnalysis: true),
      apiKey: 'dummy',
    );
    final Future<void> analysis = controller.analyze();
    for (int i = 0; i < 20 && transport.requests.isEmpty; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(transport.requests, hasLength(1));
    await controller.saveSettings(const AiCompanionSettings());
    pending.complete(AiCompanionHttpResponse(200, _response('late result')));
    await analysis;
    expect(controller.report, isNull);
    expect(controller.error, isNull);
    expect(controller.isLoading, false);
  });

  test(
    'proactive check-ins require opt-in, elapsed time and quiet interval, no network',
    () async {
      DateTime now = _now;
      final _Transport transport = _Transport();
      int reads = 0;
      final controller = _controller(
        transport: transport,
        now: () => now,
        loader: () async {
          reads++;
          return const AiCompanionMetadata();
        },
      );
      addTearDown(controller.dispose);
      await controller.checkIn(activeMinutes: 120);
      expect(controller.report, isNull);
      await controller.saveSettings(
        const AiCompanionSettings(proactiveCheckIns: true),
      );
      await controller.checkIn(activeMinutes: 59);
      expect(controller.report, isNull);
      await controller.checkIn(activeMinutes: 60);
      expect(
        controller.report!.suggestions.single.code,
        AiSuggestionCode.takeBreak,
      );
      final first = controller.report;
      now = now.add(const Duration(minutes: 30));
      await controller.checkIn(activeMinutes: 90);
      expect(identical(controller.report, first), true);
      now = now.add(const Duration(hours: 2));
      await controller.checkIn(activeMinutes: 210);
      expect(controller.report!.suggestions.single.count, 210);
      expect(reads, 0);
      expect(transport.requests, isEmpty);
    },
  );

  test('provider URL validation permits explicit loopback and HTTPS only', () {
    for (final String endpoint in <String>[
      'http://127.0.0.1:11434',
      'http://localhost:11434/v1',
      'http://[::1]:11434/v1',
      'https://provider.example/v1',
    ]) {
      expect(
        AiCompanionClient.validateProvider(
          _configured.copyWith(providerEndpoint: endpoint),
        ).path,
        '/v1/chat/completions',
      );
    }
    for (final String endpoint in <String>[
      'http://provider.example/v1',
      'http://192.168.1.2/v1',
      'https://user:password@provider.example/v1',
      'https://provider.example/v1?api_key=secret',
      'https://provider.example/v1#fragment',
      'file:///tmp/server',
      '',
    ]) {
      expect(
        () => AiCompanionClient.validateProvider(
          _configured.copyWith(providerEndpoint: endpoint),
        ),
        throwsA(
          isA<AiCompanionException>().having(
            (error) => error.code,
            'code',
            AiCompanionError.invalidProvider,
          ),
        ),
      );
    }
  });

  test(
    'real HTTP lifecycle survives save, connection test, clear and retry',
    () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      final List<String> paths = <String>[];
      final List<String?> auth = <String?>[];
      final List<Map<String, Object?>> payloads = <Map<String, Object?>>[];
      server.listen((request) async {
        paths.add(request.uri.path);
        auth.add(request.headers.value('authorization'));
        payloads.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, Object?>,
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(_response('OK'));
        await request.response.close();
      });
      final controller = AiCompanionController(
        store: AiCompanionPreferencesStore(
          MemoryPreferencesBackend(),
          secretStore: _Secrets(),
        ),
        loadMetadata: () async => const AiCompanionMetadata(),
      );
      addTearDown(controller.dispose);
      await controller.saveSettings(
        AiCompanionSettings(
          providerEndpoint: 'http://127.0.0.1:${server.port}/v1',
          model: 'local-model',
          emotionalSupport: true,
        ),
        apiKey: 'local-dummy',
      );
      await controller.testConnection();
      expect(controller.error, isNull);
      expect(controller.connectionVerified, true);
      await controller.sendMessage('Hello');
      expect(controller.messages, hasLength(2));
      controller.clearConversation();
      await controller.sendMessage('Please help me pause.');
      expect(controller.error, isNull);
      expect(controller.messages, hasLength(2));
      expect(paths, everyElement('/v1/chat/completions'));
      expect(auth, everyElement('Bearer local-dummy'));
      expect(payloads, hasLength(3));
      expect((payloads.last['messages'] as List).length, 2);
      expect(payloads.last.containsKey('tools'), false);
    },
  );

  test(
    'real HTTP redirects never forward credentials or expose error bodies',
    () async {
      final HttpServer destination = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final HttpServer source = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => destination.close(force: true));
      addTearDown(() => source.close(force: true));
      int redirected = 0;
      destination.listen((request) {
        redirected++;
        request.response.close();
      });
      source.listen((request) async {
        await request.drain<void>();
        request.response.statusCode = HttpStatus.found;
        request.response.headers.set(
          'location',
          'http://127.0.0.1:${destination.port}/stolen',
        );
        request.response.write('password=raw-provider-error');
        await request.response.close();
      });
      final client = AiCompanionClient();
      addTearDown(client.dispose);
      await expectLater(
        client.testConnection(
          _configured.copyWith(
            providerEndpoint: 'http://127.0.0.1:${source.port}/v1',
          ),
          'dummy',
        ),
        _fails(AiCompanionError.providerUnavailable),
      );
      expect(redirected, 0);
    },
  );

  test('real HTTP oversized response is bounded', () async {
    final HttpServer server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(() => server.close(force: true));
    server.listen((request) async {
      await request.drain<void>();
      request.response.write(List.filled(70000, 'x').join());
      await request.response.close();
    });
    final client = AiCompanionClient();
    addTearDown(client.dispose);
    await expectLater(
      client.testConnection(
        _configured.copyWith(
          providerEndpoint: 'http://127.0.0.1:${server.port}/v1',
        ),
        null,
      ),
      _fails(AiCompanionError.invalidResponse),
    );
  });

  test(
    'real HTTP timeout closes the request and next call can retry',
    () async {
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(() => server.close(force: true));
      int count = 0;
      server.listen((request) async {
        await request.drain<void>();
        count++;
        if (count == 1) return; // Deliberately never finishes this response.
        request.response.write(_response('OK'));
        await request.response.close();
      });
      final client = AiCompanionClient(
        timeout: const Duration(milliseconds: 80),
      );
      addTearDown(client.dispose);
      final settings = _configured.copyWith(
        providerEndpoint: 'http://127.0.0.1:${server.port}/v1',
      );
      await expectLater(
        client.testConnection(settings, null),
        _fails(AiCompanionError.timeout),
      );
      await client.testConnection(settings, null);
      expect(count, 2);
    },
  );

  test(
    'failure diagnostics contain no raw provider body or exception message',
    () async {
      final transport = _Transport()
        ..status = 401
        ..reply = 'password=raw-provider-error';
      final client = AiCompanionClient(transport: transport);
      addTearDown(client.dispose);
      try {
        await client.testConnection(_configured, 'dummy');
        fail('expected failure');
      } on AiCompanionException catch (error) {
        expect(error.code, AiCompanionError.providerUnavailable);
        expect(error.toString(), 'AiCompanionException(providerUnavailable)');
      }
      expect(
        const AiCompanionPrivacy().isSafeText('I feel tired and want to talk.'),
        true,
      );
    },
  );
}

const AiCompanionSettings _configured = AiCompanionSettings(
  providerEndpoint: 'https://provider.example/v1',
  model: 'test-model',
);

Matcher _fails(AiCompanionError code) => throwsA(
  isA<AiCompanionException>().having((error) => error.code, 'code', code),
);

AiCompanionController _controller({
  _Transport? transport,
  MemoryPreferencesBackend? backend,
  _Secrets? secrets,
  AiCompanionMetadataLoader? loader,
  DateTime Function()? now,
}) => AiCompanionController(
  store: AiCompanionPreferencesStore(
    backend ?? MemoryPreferencesBackend(),
    secretStore: secrets ?? _Secrets(),
  ),
  loadMetadata: loader ?? () async => const AiCompanionMetadata(),
  client: AiCompanionClient(transport: transport ?? _Transport()),
  now: now ?? () => _now,
);

final class _Secrets implements AiCompanionSecretStore {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> delete() async {
    value = null;
  }
}

final class _Request {
  const _Request(this.uri, this.headers, this.body);
  final Uri uri;
  final Map<String, String> headers;
  final String body;
}

final class _Transport implements AiCompanionTransport {
  final List<_Request> requests = <_Request>[];
  String reply = 'Review rarely used resource scopes.';
  int status = 200;
  Completer<AiCompanionHttpResponse>? pending;
  @override
  Future<AiCompanionHttpResponse> post(
    Uri uri, {
    required Map<String, String> headers,
    required String body,
  }) async {
    requests.add(_Request(uri, headers, body));
    return pending == null
        ? AiCompanionHttpResponse(status, _response(reply))
        : pending!.future;
  }

  @override
  void close() {}
}

String _response(String content) => jsonEncode(<String, Object>{
  'choices': <Object>[
    <String, Object>{
      'message': <String, String>{'content': content},
    },
  ],
});

ClipboardRecord _clip(
  String id, {
  String text = 'A reusable short phrase',
  int copyCount = 1,
  List<String> tags = const <String>[],
}) => ClipboardRecord(
  id: id,
  group: 'private-group',
  title: 'private-title',
  content: text,
  tags: tags,
  pinned: false,
  enabled: true,
  activation: 'manual',
  createdAt: _now,
  updatedAt: _now,
  source: 'private-source',
  copyCount: copyCount,
);

Resource _resource(
  String id,
  ResourceType type, {
  String title = 'private-resource',
  String content = 'private-resource-content',
  int candidates = 0,
  int uses = 0,
}) => Resource(
  id: id,
  type: type,
  title: title,
  content: content,
  createdAt: _now.subtract(const Duration(days: 30)),
  updatedAt: _now,
  activation: ResourceActivation.always,
  candidateCount: candidates,
  usageCount: uses,
);

TokenUsageSnapshot _tokenSnapshot() => TokenUsageSnapshot(
  days: <TokenUsageDay>[
    TokenUsageDay(
      day: _now,
      source: ConversationTokenUsageSource.codex,
      totals: const TokenUsageTotals(
        totalTokens: 21000,
        inputTokens: 20000,
        outputTokens: 1000,
        cachedInputTokens: 100,
        cacheWriteInputTokens: 0,
      ),
    ),
  ],
);
