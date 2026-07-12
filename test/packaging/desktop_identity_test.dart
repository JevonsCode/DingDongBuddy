import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('desktop hosts preserve DingDong product identity for upgrades', () {
    final String macConfig = File(
      'macos/Runner/Configs/AppInfo.xcconfig',
    ).readAsStringSync();
    final String windowsCmake = File(
      'windows/CMakeLists.txt',
    ).readAsStringSync();
    final String windowsResources = File(
      'windows/runner/Runner.rc',
    ).readAsStringSync();
    final String windowsMain = File(
      'windows/runner/main.cpp',
    ).readAsStringSync();

    expect(macConfig, contains('PRODUCT_NAME = DingDong'));
    expect(
      macConfig,
      contains('PRODUCT_BUNDLE_IDENTIFIER = com.dingdongbuddy.app'),
    );
    expect(windowsCmake, contains('set(BINARY_NAME "DingDong")'));
    expect(windowsResources, contains('VALUE "ProductName", "DingDong"'));
    expect(
      windowsResources,
      contains('VALUE "OriginalFilename", "DingDong.exe"'),
    );
    expect(windowsMain, contains('window.Create(L"DingDong"'));
  });

  test('macOS uses the canonical DingDongBuddy bundle id', () {
    final String macProject = File(
      'macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();

    expect(macProject, contains('com.dingdongbuddy.app.RunnerTests'));
  });

  test('desktop hosts consume Flutter version 0.7.2 from pubspec', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String macInfo = File('macos/Runner/Info.plist').readAsStringSync();
    final String windowsResources = File(
      'windows/runner/Runner.rc',
    ).readAsStringSync();

    expect(pubspec, contains('version: 0.7.2+9'));
    expect(macInfo, contains(r'$(FLUTTER_BUILD_NAME)'));
    expect(windowsResources, contains('FLUTTER_VERSION'));
  });

  test('macOS About uses the canonical DingDong logo', () {
    final File canonicalLogo = File('Assets/AgentToolIcon.png');
    final File macAppIcon = File(
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
    );

    expect(macAppIcon.readAsBytesSync(), canonicalLogo.readAsBytesSync());
  });

  test('macOS Help menu links to the DingDong website', () {
    final String mainMenu = File(
      'macos/Runner/Base.lproj/MainMenu.xib',
    ).readAsStringSync();
    final String appDelegate = File(
      'macos/Runner/AppDelegate.swift',
    ).readAsStringSync();

    expect(mainMenu, contains('DingDong Website'));
    expect(mainMenu, contains('selector="openWebsite:"'));
    expect(appDelegate, contains('@IBAction func openWebsite'));
    expect(appDelegate, contains('https://xn--8ovp9s.xn--m8txu.com/DingDong/'));
  });

  test('migration cleanup removes stale branding and website content', () {
    final String website = File('docs/index.html').readAsStringSync();
    final String readme = File('README.md').readAsStringSync();
    final String manual = File(
      'docs/product/manual-regression.md',
    ).readAsStringSync();
    final String checksum = sha1
        .convert(
          File('windows/runner/resources/app_icon.ico').readAsBytesSync(),
        )
        .toString();

    expect(File('Assets/AgentToolMenuBarDarkIcon.png').existsSync(), isFalse);
    expect(File('Assets/Symbols/close.png').existsSync(), isFalse);
    expect(File('docs/assets/sounds/ding-classic.wav').existsSync(), isFalse);
    expect(website, isNot(contains('ding-classic.wav')));
    expect(website, isNot(contains('sounds.wood')));
    expect(readme, contains('activity/'));
    expect(readme, isNot(contains('today/')));
    expect(manual, isNot(contains('open Today')));
    expect(checksum, isNot('2c6031875648498a461842f54b999f632e6d4f0e'));
  });

  test('desktop builds bundle the compiled DingDong MCP executable', () {
    final String macProject = File(
      'macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final String windowsRunner = File(
      'windows/runner/CMakeLists.txt',
    ).readAsStringSync();
    final String windowsFlutter = File(
      'windows/flutter/CMakeLists.txt',
    ).readAsStringSync();

    expect(macProject, contains('dart-sdk/bin/dart'));
    expect(macProject, contains('build cli --target=bin/dingdong_mcp.dart'));
    expect(macProject, contains('MCP'));
    expect(macProject, contains('MacOS/dingdong-mcp'));
    expect(windowsRunner, contains('dart.exe'));
    expect(windowsRunner, contains('build cli'));
    expect(windowsRunner, contains('dingdong_mcp.dart'));
    expect(
      windowsFlutter,
      contains('FLUTTER_ROOT "\${FLUTTER_ROOT}" PARENT_SCOPE'),
    );
  });

  test('desktop builds bundle every DingDong preview sound', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String macHost = File(
      'macos/Runner/AppDelegate.swift',
    ).readAsStringSync();
    final List<File> sounds = Directory('Assets/Sounds')
        .listSync()
        .whereType<File>()
        .where((File file) => file.path.endsWith('.wav'))
        .toList(growable: false);

    expect(pubspec, contains('- Assets/Sounds/'));
    expect(sounds, hasLength(5));
    expect(macHost, contains('App.framework/Resources/flutter_assets'));
  });

  test('release automation publishes Flutter macOS and Windows artifacts', () {
    final String workflow = File(
      '.github/workflows/release.yml',
    ).readAsStringSync();
    final String releaseGate = File(
      '.github/workflows/release-after-ci.yml',
    ).readAsStringSync();

    expect(workflow, contains('flutter build macos --release'));
    expect(workflow, contains('scripts/sign_macos_bundle.sh'));
    expect(File('scripts/sign_macos_bundle.sh').existsSync(), isTrue);
    expect(workflow, contains('flutter build windows --release'));
    expect(releaseGate, contains("workflow_run.conclusion == 'success'"));
    expect(releaseGate, contains('git tag "$tag" "$TESTED_SHA"'));
    expect(workflow, isNot(contains('swift test')));
    expect(
      Directory('Sources').existsSync()
          ? Directory(
              'Sources',
            ).listSync(recursive: true).whereType<File>().toList()
          : const <File>[],
      isEmpty,
    );
    expect(File('Package.swift').existsSync(), isFalse);
  });

  test('local macOS upgrades prefer a generic stable signing identity', () {
    final String signer = File(
      'scripts/sign_macos_bundle.sh',
    ).readAsStringSync();
    final File setup = File('scripts/setup_macos_codesigning.sh');

    expect(setup.existsSync(), isTrue);
    expect(
      signer,
      contains('DINGDONG_LOCAL_SIGNING_IDENTITY:-DingDong Local Development'),
    );
    expect(signer, contains('find-identity'));
    expect(signer, contains('CODE_SIGN_IDENTITY'));
  });

  test('macOS runtime preserves legacy data and loopback access', () {
    for (final String path in <String>[
      'macos/Runner/DebugProfile.entitlements',
      'macos/Runner/Release.entitlements',
    ]) {
      final String entitlements = File(
        path,
      ).readAsStringSync().replaceAll('\r\n', '\n');
      expect(
        entitlements,
        contains('<key>com.apple.security.app-sandbox</key>\n\t<false/>'),
      );
      expect(entitlements, contains('com.apple.security.network.server'));
      expect(entitlements, contains('com.apple.security.network.client'));
      expect(entitlements, contains('<true/>'));
    }
  });
}
