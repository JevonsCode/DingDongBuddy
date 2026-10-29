import 'package:dingdong/features/settings/domain/voice_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('DEV catalog links route back to DEV without changing production', () {
    final development = voiceCatalogWebsiteUri(development: true);
    final production = voiceCatalogWebsiteUri();
    expect(development.queryParameters['app'], 'dev');
    expect(production.queryParameters, isEmpty);
    expect(development.scheme, production.scheme);
    expect(development.host, production.host);
    expect(development.path, production.path);
  });

  test('voice links accept only a bounded public issue number', () {
    expect(voiceInstallIssueNumber('dingdong://voice/24'), 24);
    expect(
      voiceInstallIssueNumber('dingdong-dev://voice/24', development: true),
      24,
    );
    expect(
      voiceInstallIssueNumber('dingdong://voice/24', development: true),
      isNull,
    );
    expect(voiceInstallIssueNumber('dingdong-dev://voice/24'), isNull);
    for (final link in [
      'dingdong://voice/0',
      'dingdong://voice/-1',
      'dingdong://voice/24?url=https://evil.test/a.wav',
      'dingdong://user@voice/24',
      'dingdong://voice/24#fragment',
      'dingdong://voice/2147483648',
      'https://voice/24',
      'dingdong://voice/24/extra',
    ]) {
      expect(voiceInstallIssueNumber(link), isNull, reason: link);
    }
  });
}
