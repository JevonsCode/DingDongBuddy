enum SettingsWindowDestination {
  top,
  version;

  static SettingsWindowDestination fromValue(Object? value) {
    return values.firstWhere(
      (SettingsWindowDestination destination) => destination.name == value,
      orElse: () => SettingsWindowDestination.top,
    );
  }
}

/// Opens the dedicated desktop settings window.
abstract interface class SettingsWindowLauncher {
  Future<void> show({
    SettingsWindowDestination destination = SettingsWindowDestination.top,
  });
}
