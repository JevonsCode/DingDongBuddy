/// Cross-platform boundary for registering DingDong at user sign-in.
abstract interface class LaunchAtStartup {
  Future<bool> isEnabled();

  Future<void> setEnabled(bool value);
}
