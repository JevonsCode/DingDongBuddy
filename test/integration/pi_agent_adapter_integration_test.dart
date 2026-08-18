import 'dart:convert';
import 'dart:io';

import 'package:dingdong/core/models/resource.dart';
import 'package:dingdong/features/agent_adapters/domain/agent_adapter.dart';
import 'package:dingdong/features/library/data/agent_resource_synchronizer.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;

void main() {
  final String? piExecutable = Platform.environment['PI_EXECUTABLE'];

  test(
    'bundled Pi Adapter deploys a project-native Skill that Pi discovers',
    () async {
      final Directory temp = await Directory.systemTemp.createTemp(
        'dingdong-pi-integration-',
      );
      addTearDown(() => temp.delete(recursive: true));
      await Directory(
        path.join(temp.path, '.pi', 'agent'),
      ).create(recursive: true);
      final Directory project = Directory(path.join(temp.path, 'project'));
      await project.create();
      final Directory package = Directory(path.join(temp.path, 'package'));
      await Directory(
        path.join(package.path, 'references'),
      ).create(recursive: true);
      const String skillDocument = '''
---
name: pi-reviewer
description: Verify DingDong project-native delivery in Pi.
---

# Pi reviewer

Read `references/checklist.md` before reviewing.
''';
      await File(
        path.join(package.path, 'SKILL.md'),
      ).writeAsString(skillDocument);
      await File(
        path.join(package.path, 'references', 'checklist.md'),
      ).writeAsString('Check the deployed package tree.\n');
      final String adapterDocument = await File(
        path.join('Assets', 'Agent Adapters', 'pi.yaml'),
      ).readAsString();
      final AgentResourceSynchronizer synchronizer =
          await AgentResourceSynchronizer.currentUser(
            Directory(path.join(temp.path, 'packages')),
            loadAdapters: () async => <AgentAdapter>[
              AgentAdapter.parse(adapterDocument),
            ],
            homeDirectory: temp.path,
          );
      final DateTime now = DateTime.utc(2026, 8, 18);
      final Resource resource = Resource(
        id: 'PI-REVIEWER',
        type: ResourceType.skill,
        title: 'pi-reviewer',
        content: skillDocument,
        packagePath: package.path,
        enabled: true,
        activation: ResourceActivation.always,
        strictProjectSkill: true,
        skillProjectPaths: <String>[project.path],
        skillDeliveryByAgent: const <String, SkillDeliveryMode>{
          'pi': SkillDeliveryMode.nativeProject,
        },
        createdAt: now,
        updatedAt: now,
      );

      await synchronizer.sync(<Resource>[resource]);

      final File deployed = File(
        path.join(project.path, '.pi', 'skills', 'pi-reviewer', 'SKILL.md'),
      );
      expect(await deployed.readAsString(), skillDocument);
      expect(
        await File(
          path.join(
            project.path,
            '.pi',
            'skills',
            'pi-reviewer',
            'references',
            'checklist.md',
          ),
        ).readAsString(),
        'Check the deployed package tree.\n',
      );

      final Process process = await Process.start(
        piExecutable!,
        <String>[
          '--mode',
          'rpc',
          '--approve',
          '--no-session',
          '--offline',
          '--no-extensions',
          '--no-prompt-templates',
          '--no-themes',
          '--no-context-files',
        ],
        workingDirectory: project.path,
        environment: <String, String>{
          'HOME': temp.path,
          'PI_CODING_AGENT_DIR': path.join(temp.path, 'pi-agent'),
          'PI_CODING_AGENT_SESSION_DIR': path.join(temp.path, 'pi-sessions'),
          'PI_OFFLINE': '1',
          'PI_TELEMETRY': '0',
        },
        includeParentEnvironment: true,
      );
      process.stdin.writeln(
        jsonEncode(<String, String>{'type': 'get_commands'}),
      );
      await process.stdin.close();
      final String stdout = await utf8.decodeStream(process.stdout);
      final String stderr = await utf8.decodeStream(process.stderr);
      final int exitCode = await process.exitCode;

      expect(exitCode, 0, reason: stderr);
      final Map<String, Object?> response = Map<String, Object?>.from(
        jsonDecode(
              stdout
                  .split('\n')
                  .firstWhere((String line) => line.trim().isNotEmpty),
            )
            as Map,
      );
      expect(response['success'], isTrue, reason: response.toString());
      final Map<String, Object?> data = Map<String, Object?>.from(
        response['data']! as Map,
      );
      final List<Map<String, Object?>> commands = (data['commands']! as List)
          .map((Object? item) => Map<String, Object?>.from(item! as Map))
          .toList(growable: false);
      final Map<String, Object?> discovered = commands.singleWhere(
        (Map<String, Object?> command) =>
            command['name'] == 'skill:pi-reviewer',
      );
      expect(discovered['source'], 'skill');
      final Map<String, Object?> sourceInfo = Map<String, Object?>.from(
        discovered['sourceInfo']! as Map,
      );
      expect(sourceInfo['scope'], 'project');
      expect(
        await File(sourceInfo['path']! as String).resolveSymbolicLinks(),
        await deployed.resolveSymbolicLinks(),
      );

      await synchronizer.sync(<Resource>[resource.copyWith(enabled: false)]);
      expect(await deployed.exists(), isFalse);
    },
    skip: piExecutable == null
        ? 'Set PI_EXECUTABLE to run the real Pi client integration test.'
        : false,
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
