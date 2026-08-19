import 'package:dingdong/app/app_localizations.dart';
import 'package:dingdong/features/settings/domain/sound_file_gateway.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/widgets.dart';

/// Flutter-official desktop file chooser for custom notification audio.
final class FileSelectorSoundGateway implements SoundFileGateway {
  FileSelectorSoundGateway([this._localizations]);

  final DingDongLocalizations Function()? _localizations;

  @override
  Future<String?> chooseSoundFile() async {
    final DingDongLocalizations strings =
        _localizations?.call() ??
        lookupDingDongLocalizations(const Locale('en'));
    final XTypeGroup audio = XTypeGroup(
      label: strings.audioFiles,
      extensions: const <String>['wav', 'aiff', 'aif', 'mp3', 'm4a', 'caf'],
      mimeTypes: const <String>['audio/*'],
    );
    final XFile? file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[audio],
      confirmButtonText: strings.chooseSoundFile,
    );
    return file?.path;
  }
}
