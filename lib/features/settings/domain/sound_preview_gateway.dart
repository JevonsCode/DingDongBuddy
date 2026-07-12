/// Plays a settings sound sample without creating a notification or flashing.
abstract interface class SoundPreviewGateway {
  Future<void> preview({required String sound, String? customSoundPath});
}
