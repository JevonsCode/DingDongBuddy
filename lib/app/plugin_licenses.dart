import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Covers the selectively adapted native selection-hook code.
void registerPluginLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'selection-hook (Windows selection core, adapted by DingDong)',
    ], await rootBundle.loadString('third_party/selection-hook/LICENSE'));
  });
}
