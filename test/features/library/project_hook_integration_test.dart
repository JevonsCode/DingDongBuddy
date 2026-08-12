import 'dart:convert';
import 'dart:io';

import 'package:dingdong/features/library/domain/project_hook_integration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  test(
    'enabling Impeccable hooks preserves unrelated entries and records ownership',
    () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'dingdong-codex-project-hooks-',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      final File hooksFile = File(
        path.join(project.path, '.codex', 'hooks.json'),
      )..createSync(recursive: true);
      hooksFile.writeAsStringSync(
        '${jsonEncode(<String, Object?>{
          'version': 1,
          'custom': <String, Object?>{'keep': true},
          'hooks': <String, Object?>{
            'PostToolUse': <Object?>[
              <String, Object?>{
                'matcher': 'Shell',
                'hooks': <Object?>[
                  <String, Object?>{'type': 'command', 'command': 'echo external', 'timeout': 3},
                ],
              },
            ],
            'SessionStart': <Object?>[
              <String, Object?>{
                'hooks': <Object?>[
                  <String, Object?>{'type': 'command', 'command': 'echo session'},
                ],
              },
            ],
          },
        })}\n',
      );
      final CodexProjectHookIntegration integration =
          CodexProjectHookIntegration(projectRoot: project);

      final HookReconcileResult result = await integration.reconcile(
        desiredState: HookDesiredState.enabled,
        deployment: const HookDeployment(
          deploymentId: 'dep-1',
          artifactDigest: 'sha256:artifact-a',
        ),
        adapter: const ImpeccableCodexHookAdapter(),
      );

      expect(result.disposition, HookReconcileDisposition.installed);
      expect(result.trustState, HookTrustState.pending);
      final Map<String, Object?> manifest = _readObject(hooksFile);
      expect(manifest['version'], 1);
      expect(manifest['custom'], <String, Object?>{'keep': true});
      final Map<String, Object?> hooks = Map<String, Object?>.from(
        manifest['hooks']! as Map,
      );
      expect(hooks['SessionStart'], <Object?>[
        <String, Object?>{
          'hooks': <Object?>[
            <String, Object?>{'type': 'command', 'command': 'echo session'},
          ],
        },
      ]);
      expect(hooks['PostToolUse'], <Object?>[
        <String, Object?>{
          'matcher': 'Shell',
          'hooks': <Object?>[
            <String, Object?>{
              'type': 'command',
              'command': 'echo external',
              'timeout': 3,
            },
          ],
        },
        _postToolUseEntry,
      ]);
      expect(hooks['Stop'], <Object?>[_stopEntry]);

      final File receiptFile = File(
        path.join(project.path, '.codex', '.dingdong-hook-receipts.json'),
      );
      final Map<String, Object?> receipt = _readObject(receiptFile);
      expect(receipt['schemaVersion'], 1);
      final Map<String, Object?> deployments = Map<String, Object?>.from(
        receipt['deployments']! as Map,
      );
      final Map<String, Object?> owned = Map<String, Object?>.from(
        deployments['dingdong:codex-project:dep-1']! as Map,
      );
      expect(owned['deploymentId'], 'dep-1');
      expect(owned['artifactDigest'], 'sha256:artifact-a');
      expect(owned['trustState'], 'pending');
      expect(owned, isNot(contains('codexHash')));
      expect(owned, isNot(contains('trustedHash')));
      expect(owned['ownedEntries'], <Object?>[
        <String, Object?>{
          'ownedKey': 'dingdong:codex-project:dep-1:PostToolUse',
          'event': 'PostToolUse',
          'definition': _postToolUseEntry,
        },
        <String, Object?>{
          'ownedKey': 'dingdong:codex-project:dep-1:Stop',
          'event': 'Stop',
          'definition': _stopEntry,
        },
      ]);
    },
  );

  test(
    'reconciling the same owned hooks twice is a file-system no-op',
    () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'dingdong-codex-project-hooks-noop-',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      final CodexProjectHookIntegration integration =
          CodexProjectHookIntegration(projectRoot: project);
      const HookDeployment deployment = HookDeployment(
        deploymentId: 'dep-1',
        artifactDigest: 'sha256:artifact-a',
      );

      await integration.reconcile(
        desiredState: HookDesiredState.enabled,
        deployment: deployment,
        adapter: const ImpeccableCodexHookAdapter(),
      );
      final File hooksFile = File(
        path.join(project.path, '.codex', 'hooks.json'),
      );
      final File receiptFile = File(
        path.join(project.path, '.codex', '.dingdong-hook-receipts.json'),
      );
      final String hooksBefore = hooksFile.readAsStringSync();
      final String receiptBefore = receiptFile.readAsStringSync();
      final DateTime sentinel = DateTime.fromMillisecondsSinceEpoch(1000000000);
      hooksFile.setLastModifiedSync(sentinel);
      receiptFile.setLastModifiedSync(sentinel);

      final HookReconcileResult result = await integration.reconcile(
        desiredState: HookDesiredState.enabled,
        deployment: deployment,
        adapter: const ImpeccableCodexHookAdapter(),
      );

      expect(result.disposition, HookReconcileDisposition.unchanged);
      expect(hooksFile.readAsStringSync(), hooksBefore);
      expect(receiptFile.readAsStringSync(), receiptBefore);
      expect(hooksFile.lastModifiedSync(), sentinel);
      expect(receiptFile.lastModifiedSync(), sentinel);
    },
  );

  test(
    'an external exact-equivalent hook satisfies desired state without adoption',
    () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'dingdong-codex-project-hooks-external-',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      final File hooksFile = File(
        path.join(project.path, '.codex', 'hooks.json'),
      )..createSync(recursive: true);
      hooksFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'hooks': <String, Object?>{
            'PostToolUse': <Object?>[_postToolUseEntry],
            'Stop': <Object?>[_stopEntry],
          },
        })}\n',
      );
      final String before = hooksFile.readAsStringSync();
      final DateTime sentinel = DateTime.fromMillisecondsSinceEpoch(1000000000);
      hooksFile.setLastModifiedSync(sentinel);

      final HookReconcileResult result =
          await CodexProjectHookIntegration(projectRoot: project).reconcile(
            desiredState: HookDesiredState.enabled,
            deployment: const HookDeployment(
              deploymentId: 'dep-1',
              artifactDigest: 'sha256:artifact-a',
            ),
            adapter: const ImpeccableCodexHookAdapter(),
          );

      expect(result.disposition, HookReconcileDisposition.externalSatisfied);
      expect(result.trustState, HookTrustState.unknown);
      expect(hooksFile.readAsStringSync(), before);
      expect(hooksFile.lastModifiedSync(), sentinel);
      expect(
        File(
          path.join(project.path, '.codex', '.dingdong-hook-receipts.json'),
        ).existsSync(),
        isFalse,
      );
    },
  );

  test('a conflicting external Impeccable hook fails closed', () async {
    final Directory project = Directory.systemTemp.createTempSync(
      'dingdong-codex-project-hooks-conflict-',
    );
    addTearDown(() => project.deleteSync(recursive: true));
    final File hooksFile = File(path.join(project.path, '.codex', 'hooks.json'))
      ..createSync(recursive: true);
    hooksFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'hooks': <String, Object?>{
          'PostToolUse': <Object?>[
            <String, Object?>{
              'matcher': 'Edit|Write|apply_patch',
              'hooks': <Object?>[
                <String, Object?>{'type': 'command', 'command': 'node ".agents/skills/impeccable/scripts/hook.mjs" '
                    '--dingdong-deployment-id "dep-1" '
                    '--dingdong-artifact-digest "sha256:artifact-old"', 'timeout': 5, 'statusMessage': 'Checking UI changes'},
              ],
            },
          ],
        },
      })}\n',
    );
    final String before = hooksFile.readAsStringSync();

    await expectLater(
      CodexProjectHookIntegration(projectRoot: project).reconcile(
        desiredState: HookDesiredState.enabled,
        deployment: const HookDeployment(
          deploymentId: 'dep-1',
          artifactDigest: 'sha256:artifact-a',
        ),
        adapter: const ImpeccableCodexHookAdapter(),
      ),
      throwsA(
        isA<HookIntegrationException>().having(
          (HookIntegrationException error) => error.kind,
          'kind',
          HookIntegrationFailureKind.conflict,
        ),
      ),
    );
    expect(hooksFile.readAsStringSync(), before);
    expect(
      File(
        path.join(project.path, '.codex', '.dingdong-hook-receipts.json'),
      ).existsSync(),
      isFalse,
    );
  });

  test('a changed owned hook is drift and disable fails closed', () async {
    final Directory project = Directory.systemTemp.createTempSync(
      'dingdong-codex-project-hooks-drift-',
    );
    addTearDown(() => project.deleteSync(recursive: true));
    final CodexProjectHookIntegration integration = CodexProjectHookIntegration(
      projectRoot: project,
    );
    const HookDeployment deployment = HookDeployment(
      deploymentId: 'dep-1',
      artifactDigest: 'sha256:artifact-a',
    );
    await integration.reconcile(
      desiredState: HookDesiredState.enabled,
      deployment: deployment,
      adapter: const ImpeccableCodexHookAdapter(),
    );
    final File hooksFile = File(
      path.join(project.path, '.codex', 'hooks.json'),
    );
    final File receiptFile = File(
      path.join(project.path, '.codex', '.dingdong-hook-receipts.json'),
    );
    final Map<String, Object?> manifest = _readObject(hooksFile);
    final Map<String, Object?> hooks = Map<String, Object?>.from(
      manifest['hooks']! as Map,
    );
    final List<Object?> postToolUse = List<Object?>.from(
      hooks['PostToolUse']! as List,
    );
    final Map<String, Object?> postEntry = Map<String, Object?>.from(
      postToolUse.single! as Map,
    );
    final List<Object?> commands = List<Object?>.from(
      postEntry['hooks']! as List,
    );
    final Map<String, Object?> changedCommand = Map<String, Object?>.from(
      commands.single! as Map,
    )..['timeout'] = 7;
    postEntry['hooks'] = <Object?>[changedCommand];
    hooks['PostToolUse'] = <Object?>[postEntry];
    manifest['hooks'] = hooks;
    hooksFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );
    final String hooksBefore = hooksFile.readAsStringSync();
    final String receiptBefore = receiptFile.readAsStringSync();

    await expectLater(
      integration.reconcile(
        desiredState: HookDesiredState.disabled,
        deployment: deployment,
        adapter: const ImpeccableCodexHookAdapter(),
      ),
      throwsA(
        isA<HookIntegrationException>().having(
          (HookIntegrationException error) => error.kind,
          'kind',
          HookIntegrationFailureKind.drift,
        ),
      ),
    );
    expect(hooksFile.readAsStringSync(), hooksBefore);
    expect(receiptFile.readAsStringSync(), receiptBefore);
  });

  test('disabling removes only owned entries and leaves external hooks', () async {
    final Directory project = Directory.systemTemp.createTempSync(
      'dingdong-codex-project-hooks-disable-',
    );
    addTearDown(() => project.deleteSync(recursive: true));
    final File hooksFile = File(path.join(project.path, '.codex', 'hooks.json'))
      ..createSync(recursive: true);
    hooksFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
        'custom': <String, Object?>{'keep': true},
        'hooks': <String, Object?>{
          'PostToolUse': <Object?>[
            <String, Object?>{
              'matcher': 'Shell',
              'hooks': <Object?>[
                <String, Object?>{'type': 'command', 'command': 'echo external'},
              ],
            },
          ],
          'SessionStart': <Object?>[
            <String, Object?>{
              'hooks': <Object?>[
                <String, Object?>{'type': 'command', 'command': 'echo session'},
              ],
            },
          ],
        },
      })}\n',
    );
    final CodexProjectHookIntegration integration = CodexProjectHookIntegration(
      projectRoot: project,
    );
    const HookDeployment deployment = HookDeployment(
      deploymentId: 'dep-1',
      artifactDigest: 'sha256:artifact-a',
    );
    await integration.reconcile(
      desiredState: HookDesiredState.enabled,
      deployment: deployment,
      adapter: const ImpeccableCodexHookAdapter(),
    );

    final HookReconcileResult result = await integration.reconcile(
      desiredState: HookDesiredState.disabled,
      deployment: deployment,
      adapter: const ImpeccableCodexHookAdapter(),
    );

    expect(result.disposition, HookReconcileDisposition.removed);
    expect(_readObject(hooksFile), <String, Object?>{
      'custom': <String, Object?>{'keep': true},
      'hooks': <String, Object?>{
        'PostToolUse': <Object?>[
          <String, Object?>{
            'matcher': 'Shell',
            'hooks': <Object?>[
              <String, Object?>{'type': 'command', 'command': 'echo external'},
            ],
          },
        ],
        'SessionStart': <Object?>[
          <String, Object?>{
            'hooks': <Object?>[
              <String, Object?>{'type': 'command', 'command': 'echo session'},
            ],
          },
        ],
      },
    });
    expect(
      File(
        path.join(project.path, '.codex', '.dingdong-hook-receipts.json'),
      ).existsSync(),
      isFalse,
    );
  });

  test(
    'reconcile preserves receipts and entries owned by other deployments',
    () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'dingdong-codex-project-hooks-multiple-',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      final CodexProjectHookIntegration integration =
          CodexProjectHookIntegration(projectRoot: project);
      const HookDeployment otherDeployment = HookDeployment(
        deploymentId: 'dep-other',
        artifactDigest: 'sha256:other',
      );
      const HookDeployment impeccableDeployment = HookDeployment(
        deploymentId: 'dep-1',
        artifactDigest: 'sha256:artifact-a',
      );
      await integration.reconcile(
        desiredState: HookDesiredState.enabled,
        deployment: otherDeployment,
        adapter: const _OtherCodexHookAdapter(),
      );

      await integration.reconcile(
        desiredState: HookDesiredState.enabled,
        deployment: impeccableDeployment,
        adapter: const ImpeccableCodexHookAdapter(),
      );

      final File receiptFile = File(
        path.join(project.path, '.codex', '.dingdong-hook-receipts.json'),
      );
      Map<String, Object?> receipt = _readObject(receiptFile);
      Map<String, Object?> deployments = Map<String, Object?>.from(
        receipt['deployments']! as Map,
      );
      expect(
        deployments.keys,
        containsAll(<String>[
          'dingdong:codex-project:dep-other',
          'dingdong:codex-project:dep-1',
        ]),
      );

      await integration.reconcile(
        desiredState: HookDesiredState.disabled,
        deployment: impeccableDeployment,
        adapter: const ImpeccableCodexHookAdapter(),
      );

      receipt = _readObject(receiptFile);
      deployments = Map<String, Object?>.from(receipt['deployments']! as Map);
      expect(deployments.keys, <String>['dingdong:codex-project:dep-other']);
      final Map<String, Object?> manifest = _readObject(
        File(path.join(project.path, '.codex', 'hooks.json')),
      );
      expect((manifest['hooks']! as Map)['Stop'], <Object?>[_otherEntry]);
    },
  );

  test(
    'two integration instances concurrently preserve both deployments',
    () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'dingdong-codex-project-hooks-concurrent-',
      );
      addTearDown(() => project.deleteSync(recursive: true));

      await Future.wait(<Future<HookReconcileResult>>[
        CodexProjectHookIntegration(projectRoot: project).reconcile(
          desiredState: HookDesiredState.enabled,
          deployment: const HookDeployment(
            deploymentId: 'dep-other',
            artifactDigest: 'sha256:other',
          ),
          adapter: const _OtherCodexHookAdapter(),
        ),
        CodexProjectHookIntegration(projectRoot: project).reconcile(
          desiredState: HookDesiredState.enabled,
          deployment: const HookDeployment(
            deploymentId: 'dep-1',
            artifactDigest: 'sha256:artifact-a',
          ),
          adapter: const ImpeccableCodexHookAdapter(),
        ),
      ]);

      final Map<String, Object?> receipt = _readObject(
        File(path.join(project.path, '.codex', '.dingdong-hook-receipts.json')),
      );
      final Map<String, Object?> deployments = Map<String, Object?>.from(
        receipt['deployments']! as Map,
      );
      expect(deployments.keys.toSet(), <String>{
        'dingdong:codex-project:dep-other',
        'dingdong:codex-project:dep-1',
      });
      final Map<String, Object?> manifest = _readObject(
        File(path.join(project.path, '.codex', 'hooks.json')),
      );
      final Map<String, Object?> hooks = Map<String, Object?>.from(
        manifest['hooks']! as Map,
      );
      expect(hooks['PostToolUse'], <Object?>[_postToolUseEntry]);
      expect(hooks['Stop'], containsAll(<Object?>[_otherEntry, _stopEntry]));
    },
  );

  test(
    'artifact updates replace verified owned entries instead of appending',
    () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'dingdong-codex-project-hooks-upgrade-',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      final CodexProjectHookIntegration integration =
          CodexProjectHookIntegration(projectRoot: project);
      await integration.reconcile(
        desiredState: HookDesiredState.enabled,
        deployment: const HookDeployment(
          deploymentId: 'dep-1',
          artifactDigest: 'sha256:artifact-a',
        ),
        adapter: const ImpeccableCodexHookAdapter(),
      );

      final HookReconcileResult result = await integration.reconcile(
        desiredState: HookDesiredState.enabled,
        deployment: const HookDeployment(
          deploymentId: 'dep-1',
          artifactDigest: 'sha256:artifact-b',
        ),
        adapter: const ImpeccableCodexHookAdapter(),
      );

      expect(result.disposition, HookReconcileDisposition.updated);
      final File hooksFile = File(
        path.join(project.path, '.codex', 'hooks.json'),
      );
      final String manifestText = hooksFile.readAsStringSync();
      expect(manifestText, isNot(contains('sha256:artifact-a')));
      expect(manifestText, contains('sha256:artifact-b'));
      final Map<String, Object?> manifest = _readObject(hooksFile);
      final Map<String, Object?> hooks = Map<String, Object?>.from(
        manifest['hooks']! as Map,
      );
      expect(hooks['PostToolUse'], hasLength(1));
      expect(hooks['Stop'], hasLength(1));
      final Map<String, Object?> receipt = _readObject(
        File(path.join(project.path, '.codex', '.dingdong-hook-receipts.json')),
      );
      final Map<String, Object?> deployments = Map<String, Object?>.from(
        receipt['deployments']! as Map,
      );
      expect(
        (deployments['dingdong:codex-project:dep-1']! as Map)['artifactDigest'],
        'sha256:artifact-b',
      );
    },
  );

  test('a duplicate owned entry is drift and update fails closed', () async {
    final Directory project = Directory.systemTemp.createTempSync(
      'dingdong-codex-project-hooks-duplicate-',
    );
    addTearDown(() => project.deleteSync(recursive: true));
    final CodexProjectHookIntegration integration = CodexProjectHookIntegration(
      projectRoot: project,
    );
    await integration.reconcile(
      desiredState: HookDesiredState.enabled,
      deployment: const HookDeployment(
        deploymentId: 'dep-1',
        artifactDigest: 'sha256:artifact-a',
      ),
      adapter: const ImpeccableCodexHookAdapter(),
    );
    final File hooksFile = File(
      path.join(project.path, '.codex', 'hooks.json'),
    );
    final Map<String, Object?> manifest = _readObject(hooksFile);
    final Map<String, Object?> hooks = Map<String, Object?>.from(
      manifest['hooks']! as Map,
    );
    hooks['Stop'] = <Object?>[_stopEntry, _stopEntry];
    manifest['hooks'] = hooks;
    hooksFile.writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
    );
    final String before = hooksFile.readAsStringSync();

    await expectLater(
      integration.reconcile(
        desiredState: HookDesiredState.enabled,
        deployment: const HookDeployment(
          deploymentId: 'dep-1',
          artifactDigest: 'sha256:artifact-b',
        ),
        adapter: const ImpeccableCodexHookAdapter(),
      ),
      throwsA(
        isA<HookIntegrationException>().having(
          (HookIntegrationException error) => error.kind,
          'kind',
          HookIntegrationFailureKind.drift,
        ),
      ),
    );
    expect(hooksFile.readAsStringSync(), before);
  });

  test(
    'a partial external Impeccable definition is a logical conflict',
    () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'dingdong-codex-project-hooks-partial-',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      final File hooksFile = File(
        path.join(project.path, '.codex', 'hooks.json'),
      )..createSync(recursive: true);
      hooksFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(<String, Object?>{
          'hooks': <String, Object?>{
            'PostToolUse': <Object?>[_postToolUseEntry],
          },
        })}\n',
      );
      final String before = hooksFile.readAsStringSync();

      await expectLater(
        CodexProjectHookIntegration(projectRoot: project).reconcile(
          desiredState: HookDesiredState.enabled,
          deployment: const HookDeployment(
            deploymentId: 'dep-1',
            artifactDigest: 'sha256:artifact-a',
          ),
          adapter: const ImpeccableCodexHookAdapter(),
        ),
        throwsA(
          isA<HookIntegrationException>().having(
            (HookIntegrationException error) => error.kind,
            'kind',
            HookIntegrationFailureKind.conflict,
          ),
        ),
      );
      expect(hooksFile.readAsStringSync(), before);
    },
  );

  test(
    'hooks/list exact definitions across external sources satisfy state',
    () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'dingdong-codex-project-hooks-effective-',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      final CodexProjectHookInventory inventory =
          _Inventory(<CodexEffectiveHook>[
            _effectiveHook(
              project,
              eventName: 'post_tool_use',
              command: _command,
              sourceName: 'user-config.toml',
            ),
            _effectiveHook(
              project,
              eventName: 'stop',
              command: _command,
              sourceName: 'plugin-hooks.json',
            ),
          ]);

      final HookReconcileResult result =
          await CodexProjectHookIntegration(
            projectRoot: project,
            inventory: inventory,
          ).reconcile(
            desiredState: HookDesiredState.enabled,
            deployment: const HookDeployment(
              deploymentId: 'dep-1',
              artifactDigest: 'sha256:artifact-a',
            ),
            adapter: const ImpeccableCodexHookAdapter(),
          );

      expect(result.disposition, HookReconcileDisposition.externalSatisfied);
      expect(result.trustState, HookTrustState.unknown);
      expect(
        File(path.join(project.path, '.codex', 'hooks.json')).existsSync(),
        isFalse,
      );
      expect(
        File(
          path.join(project.path, '.codex', '.dingdong-hook-receipts.json'),
        ).existsSync(),
        isFalse,
      );
    },
  );

  test(
    'an unowned external exact set remains externally satisfied when disabled',
    () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'dingdong-codex-project-hooks-external-disable-',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      final CodexProjectHookIntegration integration =
          CodexProjectHookIntegration(
            projectRoot: project,
            inventory: _Inventory(<CodexEffectiveHook>[
              _effectiveHook(
                project,
                eventName: 'PostToolUse',
                command: _command,
                sourceName: 'user-config.toml',
              ),
              _effectiveHook(
                project,
                eventName: 'Stop',
                command: _command,
                sourceName: 'plugin-hooks.json',
              ),
            ]),
          );
      const HookDeployment deployment = HookDeployment(
        deploymentId: 'dep-1',
        artifactDigest: 'sha256:artifact-a',
      );
      final HookReconcileResult enabled = await integration.reconcile(
        desiredState: HookDesiredState.enabled,
        deployment: deployment,
        adapter: const ImpeccableCodexHookAdapter(),
      );

      final HookReconcileResult disabled = await integration.reconcile(
        desiredState: HookDesiredState.disabled,
        deployment: deployment,
        adapter: const ImpeccableCodexHookAdapter(),
      );

      expect(enabled.disposition, HookReconcileDisposition.externalSatisfied);
      expect(disabled.disposition, HookReconcileDisposition.externalSatisfied);
      expect(disabled.trustState, HookTrustState.unknown);
      expect(
        File(path.join(project.path, '.codex', 'hooks.json')).existsSync(),
        isFalse,
      );
      expect(
        File(
          path.join(project.path, '.codex', '.dingdong-hook-receipts.json'),
        ).existsSync(),
        isFalse,
      );
    },
  );

  test(
    'an unowned local exact set cannot be reported absent on disable',
    () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'dingdong-codex-project-hooks-local-disable-',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      final File hooksFile =
          File(path.join(project.path, '.codex', 'hooks.json'))
            ..createSync(recursive: true)
            ..writeAsStringSync(
              jsonEncode(<String, Object?>{
                'hooks': <String, Object?>{
                  'PostToolUse': <Object?>[_postToolUseEntry],
                  'Stop': <Object?>[_stopEntry],
                },
              }),
            );

      final HookReconcileResult result =
          await CodexProjectHookIntegration(projectRoot: project).reconcile(
            desiredState: HookDesiredState.disabled,
            deployment: const HookDeployment(
              deploymentId: 'dep-1',
              artifactDigest: 'sha256:artifact-a',
            ),
            adapter: const ImpeccableCodexHookAdapter(),
          );

      expect(result.disposition, HookReconcileDisposition.externalSatisfied);
      expect(result.trustState, HookTrustState.unknown);
      expect(hooksFile.existsSync(), isTrue);
    },
  );

  test(
    'a partial external set conflicts when disable has no receipt',
    () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'dingdong-codex-project-hooks-partial-disable-',
      );
      addTearDown(() => project.deleteSync(recursive: true));

      await expectLater(
        CodexProjectHookIntegration(
          projectRoot: project,
          inventory: _Inventory(<CodexEffectiveHook>[
            _effectiveHook(
              project,
              eventName: 'Stop',
              command: _command,
              sourceName: 'plugin-hooks.json',
            ),
          ]),
        ).reconcile(
          desiredState: HookDesiredState.disabled,
          deployment: const HookDeployment(
            deploymentId: 'dep-1',
            artifactDigest: 'sha256:artifact-a',
          ),
          adapter: const ImpeccableCodexHookAdapter(),
        ),
        throwsA(
          isA<HookIntegrationException>().having(
            (HookIntegrationException error) => error.kind,
            'kind',
            HookIntegrationFailureKind.conflict,
          ),
        ),
      );
    },
  );

  test(
    'hooks/list partial, extra, and changed external sets fail closed',
    () async {
      final List<(String, List<CodexEffectiveHook> Function(Directory))> cases =
          <(String, List<CodexEffectiveHook> Function(Directory))>[
            (
              'partial',
              (Directory project) => <CodexEffectiveHook>[
                _effectiveHook(
                  project,
                  eventName: 'PostToolUse',
                  command: _command,
                  sourceName: 'user-config.toml',
                ),
              ],
            ),
            (
              'extra',
              (Directory project) => <CodexEffectiveHook>[
                _effectiveHook(
                  project,
                  eventName: 'PostToolUse',
                  command: _command,
                  sourceName: 'user-config.toml',
                ),
                _effectiveHook(
                  project,
                  eventName: 'Stop',
                  command: _command,
                  sourceName: 'plugin-hooks.json',
                ),
                _effectiveHook(
                  project,
                  eventName: 'Stop',
                  command: _command,
                  sourceName: 'managed-hooks.json',
                ),
              ],
            ),
            (
              'changed',
              (Directory project) => <CodexEffectiveHook>[
                _effectiveHook(
                  project,
                  eventName: 'PostToolUse',
                  command: _command,
                  sourceName: 'user-config.toml',
                ),
                _effectiveHook(
                  project,
                  eventName: 'Stop',
                  command:
                      'node ".agents/skills/impeccable/scripts/hook.mjs" '
                      '--dingdong-deployment-id "dep-1" '
                      '--dingdong-artifact-digest "sha256:changed"',
                  sourceName: 'plugin-hooks.json',
                ),
              ],
            ),
          ];

      for (final (
            String name,
            List<CodexEffectiveHook> Function(Directory) hooks,
          )
          in cases) {
        final Directory project = Directory.systemTemp.createTempSync(
          'dingdong-codex-project-hooks-$name-',
        );
        addTearDown(() => project.deleteSync(recursive: true));

        await expectLater(
          CodexProjectHookIntegration(
            projectRoot: project,
            inventory: _Inventory(hooks(project)),
          ).reconcile(
            desiredState: HookDesiredState.enabled,
            deployment: const HookDeployment(
              deploymentId: 'dep-1',
              artifactDigest: 'sha256:artifact-a',
            ),
            adapter: const ImpeccableCodexHookAdapter(),
          ),
          throwsA(
            isA<HookIntegrationException>().having(
              (HookIntegrationException error) => error.kind,
              name,
              HookIntegrationFailureKind.conflict,
            ),
          ),
        );
        expect(
          File(path.join(project.path, '.codex', 'hooks.json')).existsSync(),
          isFalse,
        );
      }
    },
  );

  test(
    'project inline Hook config fails closed even for another family',
    () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'dingdong-codex-project-hooks-inline-',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      final String inlinePath = path.join(
        project.path,
        '.codex',
        'config.toml',
      );

      await expectLater(
        CodexProjectHookIntegration(
          projectRoot: project,
          inventory: _Inventory(<CodexEffectiveHook>[
            CodexEffectiveHook(
              eventName: 'Stop',
              command: 'echo project-inline',
              sourcePath: inlinePath,
            ),
          ]),
        ).reconcile(
          desiredState: HookDesiredState.enabled,
          deployment: const HookDeployment(
            deploymentId: 'dep-1',
            artifactDigest: 'sha256:artifact-a',
          ),
          adapter: const ImpeccableCodexHookAdapter(),
        ),
        throwsA(
          isA<HookIntegrationException>().having(
            (HookIntegrationException error) => error.kind,
            'kind',
            HookIntegrationFailureKind.conflict,
          ),
        ),
      );
    },
  );

  test(
    'an external exact set plus a local family entry is a conflict',
    () async {
      final Directory project = Directory.systemTemp.createTempSync(
        'dingdong-codex-project-hooks-additive-duplicate-',
      );
      addTearDown(() => project.deleteSync(recursive: true));
      final File hooksFile =
          File(path.join(project.path, '.codex', 'hooks.json'))
            ..createSync(recursive: true)
            ..writeAsStringSync(
              jsonEncode(<String, Object?>{
                'hooks': <String, Object?>{
                  'PostToolUse': <Object?>[_postToolUseEntry],
                },
              }),
            );
      final String before = hooksFile.readAsStringSync();

      await expectLater(
        CodexProjectHookIntegration(
          projectRoot: project,
          inventory: _Inventory(<CodexEffectiveHook>[
            _effectiveHook(
              project,
              eventName: 'PostToolUse',
              command: _command,
              sourceName: 'user-config.toml',
            ),
            _effectiveHook(
              project,
              eventName: 'Stop',
              command: _command,
              sourceName: 'plugin-hooks.json',
            ),
          ]),
        ).reconcile(
          desiredState: HookDesiredState.enabled,
          deployment: const HookDeployment(
            deploymentId: 'dep-1',
            artifactDigest: 'sha256:artifact-a',
          ),
          adapter: const ImpeccableCodexHookAdapter(),
        ),
        throwsA(isA<HookIntegrationException>()),
      );
      expect(hooksFile.readAsStringSync(), before);
    },
  );
}

const String _command =
    'node ".agents/skills/impeccable/scripts/hook.mjs" '
    '--dingdong-deployment-id "dep-1" '
    '--dingdong-artifact-digest "sha256:artifact-a"';

const Map<String, Object?> _postToolUseEntry = <String, Object?>{
  'matcher': 'Edit|Write|apply_patch',
  'hooks': <Object?>[
    <String, Object?>{
      'type': 'command',
      'command': _command,
      'timeout': 5,
      'statusMessage': 'Checking UI changes',
    },
  ],
};

const Map<String, Object?> _stopEntry = <String, Object?>{
  'hooks': <Object?>[
    <String, Object?>{
      'type': 'command',
      'command': _command,
      'timeout': 30,
      'statusMessage': 'Design deep pass',
    },
  ],
};

const Map<String, Object?> _otherEntry = <String, Object?>{
  'hooks': <Object?>[
    <String, Object?>{
      'type': 'command',
      'command': 'echo other --deployment dep-other --artifact sha256:other',
    },
  ],
};

final class _OtherCodexHookAdapter implements CodexProjectHookAdapter {
  const _OtherCodexHookAdapter();

  @override
  bool belongsToHookFamily(Object? entry) {
    return jsonEncode(entry).contains('echo other');
  }

  @override
  List<CodexHookDefinition> definitionsFor(HookDeployment deployment) {
    return const <CodexHookDefinition>[
      CodexHookDefinition(event: CodexHookEvent.stop, entry: _otherEntry),
    ];
  }
}

final class _Inventory implements CodexProjectHookInventory {
  const _Inventory(this.hooks);

  final List<CodexEffectiveHook> hooks;

  @override
  Future<List<CodexEffectiveHook>> list(Directory projectRoot) async => hooks;
}

CodexEffectiveHook _effectiveHook(
  Directory project, {
  required String eventName,
  required String command,
  required String sourceName,
}) => CodexEffectiveHook(
  eventName: eventName,
  command: command,
  sourcePath: path.join(project.parent.path, sourceName),
);

Map<String, Object?> _readObject(File file) {
  return Map<String, Object?>.from(jsonDecode(file.readAsStringSync())! as Map);
}
