import 'package:dingdong/features/settings/data/reminder_audio_importer.dart';
import 'package:dingdong/features/settings/data/settings_repository.dart';

/// Serializes Agent edits so two concurrent tool calls cannot lose profiles.
final class ReminderSettingsService {
  ReminderSettingsService(this.repository, this.importer, {this.onChanged});
  final SettingsRepository repository;
  final ReminderAudioImporter importer;
  final Future<void> Function()? onChanged;
  Future<void> _tail = Future.value();
  Future<Map<String, Object?>> call(Map<String, Object?> command) {
    final result = _tail.then((_) => _execute(command));
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<Map<String, Object?>> _execute(Map<String, Object?> command) async {
    var settings = await repository.load();
    final action = command['action'] ?? 'list';
    bool? consumed;
    switch (action) {
      case 'list':
        break;
      case 'upsert':
        final id = command['id'];
        final existing = id is String ? settings.reminderProfile(id) : null;
        final profile = ReminderProfile.fromJson({
          ...?existing?.toJson(),
          ...command,
        });
        if (profile.builtIn && profile.temporary) {
          throw const FormatException(
            'Built-in reminders cannot be temporary.',
          );
        }
        if (profile.builtIn && profile.kind.apiValue != profile.id) {
          throw const FormatException('Built-in reminder kind cannot change.');
        }
        if (profile.sound == 'custom' &&
            ![
              ...settings.notificationRules.audioLibrary.map((x) => x.path),
              ...settings.reminderProfiles.map((x) => x.customSoundPath),
            ].contains(profile.customSoundPath)) {
          throw const FormatException(
            'Import this sound with dingdong_import_reminder_sound first.',
          );
        }
        if (profile.sound == 'custom' && profile.customSoundPath == null) {
          throw const FormatException('Select an imported customSoundPath.');
        }
        settings = settings.withReminderProfile(profile);
      case 'consume':
        // Compare the captured definition so an in-flight notification cannot
        // remove a newer edit. The queue makes one-use claims atomic.
        final id = command['id'];
        final profile = id is String ? settings.reminderProfile(id) : null;
        final expected = command['expected'];
        consumed =
            profile != null &&
            profile.temporary &&
            profile.enabled &&
            expected is Map &&
            profile ==
                ReminderProfile.fromJson(Map<String, Object?>.from(expected));
        if (consumed) settings = settings.withoutReminderProfile(profile.id);
      case 'delete':
        final id = command['id'];
        if (id is! String || settings.reminderProfile(id) == null) {
          throw const FormatException('Unknown reminder ID.');
        }
        settings = settings.withoutReminderProfile(id);
      case 'importSound':
        if (command['path'] is! String || command['name'] is! String) {
          throw const FormatException('Provide path and name.');
        }
        if (settings.notificationRules.audioLibrary.length >= 64) {
          throw const FormatException('Maximum 64 imported sounds.');
        }
        final audio = await importer.import(
          command['path'] as String,
          command['name'] as String,
        );
        settings = settings.copyWith(
          notificationRules: settings.notificationRules.copyWith(
            audioLibrary: [
              ...settings.notificationRules.audioLibrary.where(
                (x) => x.path != audio.path,
              ),
              audio,
            ],
          ),
        );
      default:
        throw const FormatException('Unknown reminder action.');
    }
    if (action != 'list' && (action != 'consume' || consumed == true)) {
      await repository.save(settings);
      await onChanged?.call();
    }
    return {
      'status': 'ok',
      'consumed': ?consumed,
      'reminders': settings.reminderProfiles.map((x) => x.toJson()).toList(),
      'sounds': settings.notificationRules.audioLibrary
          .map((x) => x.toJson())
          .toList(),
    };
  }
}
