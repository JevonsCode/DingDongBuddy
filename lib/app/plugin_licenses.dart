import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// pro_image_editor notices are included by Flutter's package license bundle.
/// This entry covers the selectively adapted native selection-hook code.
void registerPluginLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'selection-hook (Windows selection core, adapted by DingDong)',
    ], await rootBundle.loadString('third_party/selection-hook/LICENSE'));
  });
}
