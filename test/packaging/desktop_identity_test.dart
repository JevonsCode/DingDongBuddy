import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dingdong/features/settings/domain/app_settings.dart';
import 'package:dingdong/features/settings/domain/mcp_setup_prompt.dart';
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
    expect(
      RegExp(r'MACOSX_DEPLOYMENT_TARGET = 13\.0;').allMatches(macProject),
      hasLength(3),
    );
  });

  test('desktop hosts consume application version 0.7.20 from pubspec', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String macInfo = File('macos/Runner/Info.plist').readAsStringSync();
    final String windowsResources = File(
      'windows/runner/Runner.rc',
    ).readAsStringSync();

    expect(pubspec, contains('version: 0.7.20+20'));
    expect(macInfo, contains(r'$(FLUTTER_BUILD_NAME)'));
    expect(windowsResources, contains('FLUTTER_VERSION'));
  });

  test('macOS About uses the canonical DingDong logo', () {
    final File canonicalLogo = File('Assets/AgentToolIcon.png');
    final File macAppIcon = File(
      'macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_1024.png',
    );

    expect(macAppIcon.readAsBytesSync(), canonicalLogo.readAsBytesSync());
    final String appDelegate = File(
      'macos/Runner/AppDelegate.swift',
    ).readAsStringSync();
    expect(appDelegate, contains('NSApp.applicationIconImage = icon'));
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
    expect(
      appDelegate,
      contains('https://xn--8ovp9s.xn--m8txu.com/DingDongBuddy/'),
    );
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

  test('English and Chinese READMEs match the in-app Agent setup flow', () {
    final String english = File('README.md').readAsStringSync();
    final String chinese = File('README.zh.md').readAsStringSync();
    const String commandPath =
        '/Applications/DingDong.app/Contents/MCP/bundle/bin/dingdong_mcp';
    final String englishPrompt = defaultMcpSetupPrompt(
      language: AppLanguagePreference.english,
      commandPath: commandPath,
    );
    final String chinesePrompt = defaultMcpSetupPrompt(
      language: AppLanguagePreference.chinese,
      commandPath: commandPath,
    );

    expect(english, contains('href="README.zh.md"'));
    expect(chinese, contains('href="README.md"'));
    for (final String readme in <String>[english, chinese]) {
      expect(readme, contains('```mermaid'));
      expect(readme, contains('dingdong_bridge'));
      expect(readme, contains('--notify-stop --source'));
      expect(readme, contains('~/.codex/config.toml'));
      expect(readme, contains('~/.claude/settings.json'));
      expect(readme, contains('~/.cursor/hooks.json'));
      expect(readme, contains('~/.gemini/settings.json'));
      expect(readme, contains('afterAgentResponse'));
      expect(readme, contains('AfterAgent'));
      expect(readme, contains('dingdong_notify'));
    }
    for (final String prompt in <String>[englishPrompt, chinesePrompt]) {
      expect(prompt, contains(commandPath));
      expect(prompt, contains('--notify-stop --source'));
      expect(prompt, contains('~/.codex/config.toml'));
      expect(prompt, contains('~/.claude/settings.json'));
      expect(prompt, contains('~/.cursor/hooks.json'));
      expect(prompt, contains('~/.gemini/settings.json'));
      expect(prompt, contains('afterAgentResponse'));
      expect(prompt, contains('AfterAgent'));
      expect(prompt, contains('dingdong_notify'));
      expect(prompt, contains('AGENTS.md'));
      expect(prompt, contains('Skill'));
      expect(prompt, contains('MCP'));
    }
    expect(english, contains('Prompt, Skill, and MCP invocation semantics'));
    expect(chinese, contains('Prompt、Skill 和 MCP 的调用逻辑'));
    expect(englishPrompt, contains('Skill summary is not an instruction'));
    expect(chinesePrompt, contains('Skill 摘要不是指令'));
  });

  test('website keeps release diagnostics behind debug mode', () {
    final String website = File('docs/index.html').readAsStringSync();
    final String releaseMetadata = File(
      'docs/dingdong-release.json',
    ).readAsStringSync();
    final String websiteStyles = File('docs/styles.css').readAsStringSync();

    expect(website, isNot(contains('A familiar macOS installer.')));
    expect(website, isNot(contains('熟悉的 macOS 拖拽安装')));
    expect(website, isNot(contains('Both native builds are tested first')));
    expect(website, isNot(contains('两种原生版本先分别测试')));
    expect(website, isNot(contains('Apple Silicon and Intel ·')));
    expect(website, isNot(contains('id="updates"')));
    expect(website, contains('id="download-stats" aria-live="polite" hidden'));
    expect(website, contains('new URLSearchParams(window.location.search)'));
    expect(website, contains('.get("debug") === "1"'));
    expect(website, contains('if (showDownloadStats) {'));
    expect(website, contains('const detectedDownloadPlatform'));
    expect(website, contains('id="macos-arm64-download"'));
    expect(website, contains('id="macos-x64-download"'));
    expect(website, contains('id="windows-x64-download"'));
    expect(website, contains('getHighEntropyValues'));
    expect(website, contains('"architecture"'));
    expect(website, contains('download.recommended'));
    expect(website, contains('download.beta'));
    expect(website, isNot(contains('Intel Mac OS X')));
    expect(website, isNot(contains('knowledge')));
    expect(website, isNot(contains('知识库')));
    expect(website, contains('activeTab: "library"'));
    expect(website, contains('./assets/symbols/refresh.png'));
    expect(website, contains('./assets/symbols/library.png'));
    expect(website, contains('createDemoSymbol(item.type'));
    expect(website, contains('createDemoStatusIcon(enabled)'));
    expect(
      website,
      isNot(contains('createDemoElement("b", "", content.labels.library)')),
    );
    expect(website, isNot(contains('content: "✦"')));
    expect(website, isNot(contains('content: "◇"')));
    expect(website, isNot(contains('content: "▣"')));
    expect(websiteStyles, contains('.demo-resource-row.type-prompt'));
    expect(websiteStyles, contains('.demo-resource-row.type-skill'));
    expect(websiteStyles, contains('.demo-resource-row.type-mcp'));
    expect(websiteStyles, contains('.demo-resource-row.is-disabled'));
    expect(
      websiteStyles,
      contains('.demo-resource-action.action-status.is-enabled'),
    );
    for (final String symbol in <String>[
      'today',
      'library',
      'clipboard',
      'refresh',
      'settings',
      'collapse',
      'manage',
      'search',
      'prompt',
      'skill',
      'mcp',
      'enabled',
      'copy',
      'edit',
      'delete',
      'filter',
    ]) {
      expect(File('docs/assets/symbols/$symbol.png').existsSync(), isTrue);
    }
    expect(releaseMetadata, contains('"latestVersion": "0.7.20"'));
    expect(releaseMetadata, contains('"latestBuild": "20"'));
    expect(releaseMetadata, contains('"arm64"'));
    expect(releaseMetadata, contains('"x86_64"'));
    expect(releaseMetadata, contains('"beta": true'));
    expect(
      releaseMetadata,
      contains('DingDong-0.7.20-windows-x64-beta-Setup.exe'),
    );
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
    final String macBuilder = File(
      'scripts/build_macos_mcp.sh',
    ).readAsStringSync();
    final String universalBuilder = File(
      'scripts/create_universal_macos_mcp.sh',
    ).readAsStringSync();
    final String macLauncher = File(
      'scripts/macos_mcp_launcher.sh',
    ).readAsStringSync();

    expect(macProject, contains('scripts/build_macos_mcp.sh'));
    expect(macBuilder, contains('dart-sdk/bin/dart'));
    expect(macBuilder, contains('build cli'));
    expect(macBuilder, contains('--target=bin/dingdong_mcp.dart'));
    expect(macBuilder, contains('--notify-stop'));
    expect(macBuilder, contains('"method":"tools/list"'));
    expect(universalBuilder, contains('native/arm64'));
    expect(universalBuilder, contains('native/x86_64'));
    expect(universalBuilder, contains('macos_mcp_launcher.sh'));
    expect(macLauncher, contains(r'$(/usr/bin/uname -m)'));
    expect(macLauncher, contains(r'native/$machine_architecture'));
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

  test('macOS notifications play sound without bouncing the Dock icon', () {
    final String macHost = File(
      'macos/Runner/AppDelegate.swift',
    ).readAsStringSync();

    expect(macHost, contains('self?.playNotificationSound(arguments)'));
    expect(macHost, isNot(contains('requestUserAttention')));
  });

  test('release automation publishes macOS installer and Windows artifacts', () {
    final String workflow = File(
      '.github/workflows/release.yml',
    ).readAsStringSync();
    final String releaseGate = File(
      '.github/workflows/release-after-ci.yml',
    ).readAsStringSync();
    final String desktopWorkflow = File(
      '.github/workflows/flutter-desktop.yml',
    ).readAsStringSync();

    expect(workflow, contains('build macos --release'));
    expect(workflow, contains('scripts/sign_macos_bundle.sh'));
    expect(workflow, contains('macos-15-intel'));
    expect(workflow, contains(r'runs-on: ${{ matrix.runner }}'));
    expect(workflow, contains('asset_arch: arm64'));
    expect(workflow, contains('asset_arch: x64'));
    expect(workflow, contains('scripts/thin_macos_app.sh'));
    expect(workflow, contains('Verify macOS application architecture'));
    expect(
      workflow,
      contains(
        r'DingDong-${VERSION}-macos-${{ matrix.asset_arch }}${{ matrix.beta_suffix }}.dmg',
      ),
    );
    expect(workflow, contains('dotnet tool install --tool-path .tools vpk'));
    expect(workflow, contains('--noPortable'));
    expect(
      workflow,
      contains(r'DingDong-${version}-windows-x64-beta-Setup.exe'),
    );
    expect(workflow, contains('mcp-macos-arm64'));
    expect(workflow, contains('mcp-macos-x86_64'));
    expect(workflow, contains("if: matrix.arch == 'x86_64'"));
    expect(workflow, contains('flutter test --exclude-tags golden'));
    expect(workflow, contains('scripts/create_universal_macos_mcp.sh'));
    expect(desktopWorkflow, contains('macos-15-intel'));
    expect(desktopWorkflow, contains(r'runs-on: ${{ matrix.runner }}'));
    expect(desktopWorkflow, contains("if: matrix.arch == 'x86_64'"));
    expect(desktopWorkflow, contains('flutter test --exclude-tags golden'));
    expect(desktopWorkflow, contains('scripts/thin_macos_app.sh'));
    expect(desktopWorkflow, contains('Verify macOS application architecture'));
    expect(desktopWorkflow, contains('scripts/create_universal_macos_mcp.sh'));
    expect(File('scripts/sign_macos_bundle.sh').existsSync(), isTrue);
    final String appThinner = File(
      'scripts/thin_macos_app.sh',
    ).readAsStringSync();
    expect(appThinner, contains(r'-thin "$target_architecture"'));
    expect(appThinner, contains('resulting_architectures'));
    expect(workflow, contains('scripts/create_macos_dmg.sh'));
    expect(workflow, contains('dist/*.dmg'));
    expect(workflow, contains('scripts/notarize_macos_artifact.sh'));
    final String dmgBuilder = File(
      'scripts/create_macos_dmg.sh',
    ).readAsStringSync();
    final String dmgSettings = File(
      'scripts/dmg_settings.py',
    ).readAsStringSync();
    expect(workflow, contains('dmgbuild==1.6.7'));
    expect(dmgBuilder, contains('Assets/AgentToolIcon.png'));
    expect(dmgBuilder, contains('安装与权限说明.txt'));
    expect(dmgBuilder, contains('dmg-background.svg'));
    expect(dmgSettings, contains('"Applications": "/Applications"'));
    expect(dmgBuilder, contains('AppIcon.icns'));
    expect(dmgBuilder, contains('com.apple.FinderInfo'));
    expect(dmgSettings, contains('background = background_path'));
    expect(dmgSettings, contains('hide_extensions = []'));
    expect(dmgBuilder, contains('codesign --verify --deep --strict'));
    expect(
      File('Assets/installer/安装与权限说明.txt').readAsStringSync(),
      contains('辅助功能'),
    );
    expect(workflow, contains('flutter build windows --release'));
    expect(workflow, isNot(contains('APTABASE_APP_KEY')));
    expect(workflow, contains('--notes-file docs/release-notes.md'));
    expect(File('docs/release-notes.md').existsSync(), isTrue);
    expect(releaseGate, contains("workflow_run.conclusion == 'success'"));
    expect(releaseGate, contains('git tag "\$tag" "\$TESTED_SHA"'));
    expect(
      releaseGate,
      contains('GITHUB_TOKEN tag pushes do not start new workflows'),
    );
    expect(releaseGate, contains('gh workflow run release.yml'));
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

  test('desktop releases provide signed one-click native updates', () {
    final String workflow = File(
      '.github/workflows/release.yml',
    ).readAsStringSync();
    final String macInfo = File('macos/Runner/Info.plist').readAsStringSync();
    final String macProject = File(
      'macos/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final String macUpdater = File(
      'macos/Runner/DingDongUpdater.swift',
    ).readAsStringSync();
    final String windowsMain = File(
      'windows/runner/main.cpp',
    ).readAsStringSync();
    final String windowsUpdater = File(
      'windows/runner/application_updater.cpp',
    ).readAsStringSync();
    final String windowsCmake = File(
      'windows/runner/CMakeLists.txt',
    ).readAsStringSync();

    expect(macInfo, contains('SUFeedURL'));
    expect(macInfo, contains('SUPublicEDKey'));
    expect(macProject, contains('version = 2.9.4;'));
    expect(macUpdater, contains('SPUUpdater'));
    expect(macUpdater, contains('showReadyToInstallAndRelaunch'));
    expect(workflow, contains('SPARKLE_PUBLIC_ED_KEY'));
    expect(workflow, contains('SPARKLE_PRIVATE_ED_KEY'));
    expect(workflow, contains('scripts/generate_sparkle_appcast.sh'));
    expect(workflow, contains(r'appcast-macos-${{ matrix.asset_arch }}.xml'));
    expect(File('scripts/setup_sparkle_keys.sh').existsSync(), isTrue);
    final String keySetup = File(
      'scripts/setup_sparkle_keys.sh',
    ).readAsStringSync();
    expect(
      keySetup.indexOf(
        r'"$temporary_root/bin/generate_keys" --account com.dingdongbuddy.app',
      ),
      lessThan(keySetup.indexOf(r'-x "$private_key_path"')),
    );

    expect(windowsMain, contains('VelopackApp::Build().Run()'));
    expect(windowsUpdater, contains('GithubSource'));
    expect(windowsUpdater, contains('DownloadUpdates'));
    expect(windowsUpdater, contains('WaitExitThenApplyUpdates'));
    expect(windowsUpdater, contains('kDingDongExitForUpdateMessage'));
    expect(windowsCmake, contains('DINGDONG_VELOPACK_VERSION "1.2.0"'));
    expect(windowsCmake, contains('velopack_libc.dll'));
    expect(workflow, contains('--channel "win"'));
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

  test('release builds contain no dormant analytics wiring', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String main = File('lib/main.dart').readAsStringSync();
    final String releaseMetadata = File(
      'docs/dingdong-release.json',
    ).readAsStringSync();
    final String manualRegression = File(
      'docs/product/manual-regression.md',
    ).readAsStringSync();
    final String workflow = File(
      '.github/workflows/release.yml',
    ).readAsStringSync();

    expect(
      File('lib/platform/privacy_preserving_telemetry.dart').existsSync(),
      isFalse,
    );
    expect(pubspec, isNot(contains('aptabase')));
    expect(main, isNot(contains('Telemetry')));
    expect(main, isNot(contains('telemetry.track')));
    expect(workflow, isNot(contains('APTABASE_APP_KEY')));
    expect(releaseMetadata.toLowerCase(), isNot(contains('aptabase')));
    expect(manualRegression.toLowerCase(), isNot(contains('aptabase')));
  });

  test('GitHub feedback forms require a privacy check', () {
    final String bugForm = File(
      '.github/ISSUE_TEMPLATE/bug-report.yml',
    ).readAsStringSync();
    final String featureForm = File(
      '.github/ISSUE_TEMPLATE/feature-request.yml',
    ).readAsStringSync();

    expect(bugForm, contains('Privacy check'));
    expect(bugForm, contains('required: true'));
    expect(featureForm, contains('Privacy check'));
    expect(featureForm, contains('required: true'));
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

  test('tray and display plugins share one multi-monitor coordinate space', () {
    final String trayPlugin = File(
      'packages/tray_manager/macos/tray_manager/Classes/TrayManagerPlugin.swift',
    ).readAsStringSync();

    expect(trayPlugin, contains('NSScreen.screens[0].frame'));
    expect(trayPlugin, isNot(contains('NSScreen.main!.frame')));
  });

  test('macOS does not reframe its already borderless main window', () {
    final String mainWindow = File(
      'macos/Runner/MainFlutterWindow.swift',
    ).readAsStringSync();
    final String gateway = File(
      'lib/platform/plugin_desktop_shell_gateway.dart',
    ).readAsStringSync();

    expect(mainWindow, contains('self.styleMask = [.borderless, .resizable]'));
    expect(gateway, isNot(contains('await windowManager.setAsFrameless();')));
  });

  test('vendored macOS window manager never force unwraps titlebar views', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    final String windowManager = File(
      'packages/window_manager/macos/window_manager/Sources/window_manager/WindowManager.swift',
    ).readAsStringSync();

    expect(pubspec, contains('path: packages/window_manager'));
    expect(windowManager, contains('?.superview?.superview'));
    expect(
      windowManager,
      isNot(contains('standardWindowButton(.closeButton)?.superview)!')),
    );
  });

  test('macOS window calls initialize the native window before dispatch', () {
    final String plugin = File(
      'packages/window_manager/macos/window_manager/Sources/window_manager/WindowManagerPlugin.swift',
    ).readAsStringSync();
    final int handle = plugin.indexOf('public func handle');
    final int initialize = plugin.indexOf('ensureInitialized()', handle);
    final int dispatch = plugin.indexOf('switch (methodName)', handle);

    expect(handle, greaterThanOrEqualTo(0));
    expect(initialize, greaterThan(handle));
    expect(dispatch, greaterThan(initialize));
  });

  test(
    'resource manager paints its first frame before the window is shown',
    () {
      final String mainSource = File('lib/main.dart').readAsStringSync();
      final int functionStart = mainSource.indexOf(
        'Future<void> _runResourceManagerWindow',
      );
      expect(functionStart, greaterThanOrEqualTo(0));
      final String resourceWindowSource = mainSource.substring(functionStart);
      final int configureWindow = resourceWindowSource.indexOf(
        'await windowManager.waitUntilReadyToShow(options);',
      );
      final int mountFlutter = resourceWindowSource.indexOf('runApp(');
      final int waitForFirstFrame = resourceWindowSource.indexOf(
        'await WidgetsBinding.instance.endOfFrame;',
      );
      final int showWindow = resourceWindowSource.indexOf(
        'await windowManager.show();',
      );
      final int focusWindow = resourceWindowSource.indexOf(
        'await windowManager.focus();',
      );

      expect(configureWindow, greaterThanOrEqualTo(0));
      expect(mountFlutter, greaterThan(configureWindow));
      expect(waitForFirstFrame, greaterThan(mountFlutter));
      expect(showWindow, greaterThan(waitForFirstFrame));
      expect(focusWindow, greaterThan(showWindow));
    },
  );
}
