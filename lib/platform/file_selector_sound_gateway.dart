import 'package:dingdong/features/settings/domain/sound_file_gateway.dart';
import 'package:file_selector/file_selector.dart';

/// Flutter-official desktop file chooser for custom notification audio.
final class FileSelectorSoundGateway implements SoundFileGateway {
  static const XTypeGroup _audio = XTypeGroup(
    label: 'Audio',
    extensions: <String>['wav', 'aiff', 'aif', 'mp3', 'm4a', 'caf'],
    mimeTypes: <String>['audio/*'],
  );

  @override
  Future<String?> chooseSoundFile() async {
    final XFile? file = await openFile(
      acceptedTypeGroups: const <XTypeGroup>[_audio],
      confirmButtonText: 'Choose sound',
    );
    return file?.path;
  }
}
