import 'package:dingdong/features/settings/data/preferences_backend.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('loads legacy preference keys and sanitizes unsafe limits', () async {
    final MemoryPreferencesBackend backend =
        MemoryPreferencesBackend(<String, Object>{
          'dingdong.clipboard.monitoring': true,
          'dingdong.language': 'zh',
          'dingdong.panel.themeMode': 'dark',
          'dingdong.telemetry.anonymous': true,
          'dingdong.panel.backgroundOpacity': 0.75,
          'dingdong.panel.density': 'compact',
          'dingdong.panel.defaultTab': 'clipboard',
          'dingdong.clipboard.maxItems': 9000,
          'dingdong.clipboard.maxAgeDays': 0,
          'dingdong.selectedSound': 'dingBright',
          'dingdong.customSoundPath': '/tmp/chime.wav',
          'dingdong.mcpSetupPromptOverride': '  custom setup  ',
          'dingdong.onboarding.mcpAccessSeen': true,
          'dingdong.api.port': 70000,
        });

    final settings = await SettingsRepository(backend).load();

    expect(settings.clipboardMonitoring, isTrue);
    expect(settings.language, AppLanguagePreference.chinese);
    expect(settings.themeMode, AppThemePreference.dark);
    expect(settings.backgroundOpacity, 0.82);
    expect(settings.density, PanelDensityPreference.compact);
    expect(settings.defaultWorkspace, DefaultWorkspace.clipboard);
    expect(settings.clipboardMaxItems, 5000);
    expect(settings.clipboardMaxAgeDays, 1);
    expect(settings.selectedSound, 'dingBright');
    expect(settings.customSoundPath, '/tmp/chime.wav');
    expect(settings.mcpAccessSeen, isTrue);
    expect(settings.apiPort, 2333);
  });

  test('saves settings with the native app preference contract', () async {
    final MemoryPreferencesBackend backend = MemoryPreferencesBackend();
    final SettingsRepository repository = SettingsRepository(backend);
    const AppSettings settings = AppSettings(
      clipboardMonitoring: true,
      language: AppLanguagePreference.english,
      themeMode: AppThemePreference.system,
      backgroundOpacity: 0.88,
      density: PanelDensityPreference.compact,
      defaultWorkspace: DefaultWorkspace.library,
      clipboardMaxItems: 600,
      clipboardMaxAgeDays: 30,
      selectedSound: 'muted',
      customSoundPath: '/tmp/quiet.wav',
      mcpAccessSeen: true,
      apiPort: 2444,
    );

    await repository.save(settings);

    expect(backend.values['dingdong.clipboard.monitoring'], isTrue);
    expect(backend.values['dingdong.language'], 'en');
    expect(backend.values['dingdong.panel.themeMode'], 'system');
    expect(backend.values, isNot(contains('dingdong.telemetry.anonymous')));
    expect(backend.values['dingdong.panel.backgroundOpacity'], 0.88);
    expect(backend.values['dingdong.panel.density'], 'compact');
    expect(backend.values['dingdong.panel.defaultTab'], 'library');
    expect(backend.values['dingdong.clipboard.maxItems'], 600);
    expect(backend.values['dingdong.clipboard.maxAgeDays'], 30);
    expect(backend.values['dingdong.selectedSound'], 'muted');
    expect(backend.values['dingdong.customSoundPath'], '/tmp/quiet.wav');
    expect(backend.values, isNot(contains('dingdong.mcpSetupPromptOverride')));
    expect(backend.values['dingdong.onboarding.mcpAccessSeen'], isTrue);
    expect(backend.values['dingdong.api.port'], 2444);
  });

  test(
    'legacy novelty sound preference migrates to classic DingDong',
    () async {
      final SettingsRepository repository = SettingsRepository(
        MemoryPreferencesBackend(<String, Object>{
          'dingdong.selectedSound': 'candy',
        }),
      );

      final AppSettings settings = await repository.load();

      expect(settings.selectedSound, 'default');
    },
  );

  test('legacy wood preference becomes the new classic default', () async {
    final SettingsRepository repository = SettingsRepository(
      MemoryPreferencesBackend(<String, Object>{
        'dingdong.selectedSound': 'dingWood',
      }),
    );

    final AppSettings settings = await repository.load();

    expect(settings.selectedSound, 'default');
  });
}
