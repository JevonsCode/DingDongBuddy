/// Native file-dialog boundary for choosing a custom notification sound.
abstract interface class SoundFileGateway {
  Future<String?> chooseSoundFile();
}
