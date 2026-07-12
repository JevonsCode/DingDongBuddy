import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens project links using the operating system's default browser.
final class UrlLauncherExternalLinkGateway implements ExternalLinkGateway {
  @override
  Future<void> open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      throw StateError('Could not open $uri');
    }
  }
}
