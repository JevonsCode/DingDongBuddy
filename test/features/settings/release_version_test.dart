import 'package:dingdong/features/settings/domain/release_update.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'preview notes keep their version and stable updates retain their link',
    () {
      final ReleaseMetadata oldStable = ReleaseMetadata(
        app: 'DingDong',
        latestVersion: '1.6.2',
        website: defaultWebsiteUri,
        releasePage: defaultReleasePageUri,
      );
      final ReleaseStatus preview = ReleaseStatus(
        currentVersion: '1.7.0-dev.2',
        metadata: oldStable,
      );
      expect(preview.isPreview, isTrue);
      expect(preview.releasePage.path, endsWith('/tag/v1.7.0-dev.2'));
      final ReleaseStatus stable = ReleaseStatus(
        currentVersion: '1.6.2',
        metadata: oldStable,
      );
      expect(stable.isPreview, isFalse);
      expect(stable.releasePage, defaultReleasePageUri);
    },
  );
  test('preview users are offered the corresponding stable release', () {
    expect(compareVersions('1.7.0-dev.2', '1.7.0'), lessThan(0));
    expect(compareVersions('1.7.0', '1.7.0-dev.2'), greaterThan(0));
    expect(compareVersions('1.7.0-dev.2', '1.6.2'), greaterThan(0));
  });

  test('prerelease identifiers follow numeric and lexical precedence', () {
    const List<String> versions = <String>[
      '1.0.0-alpha',
      '1.0.0-alpha.1',
      '1.0.0-alpha.beta',
      '1.0.0-beta',
      '1.0.0-beta.2',
      '1.0.0-beta.11',
      '1.0.0-rc.1',
      '1.0.0',
    ];
    for (int i = 0; i < versions.length - 1; i++) {
      expect(compareVersions(versions[i], versions[i + 1]), lessThan(0));
      expect(compareVersions(versions[i + 1], versions[i]), greaterThan(0));
    }
  });

  test(
    'build metadata does not change precedence and prefixes remain supported',
    () {
      expect(compareVersions('v1.7.0+67', '1.7.0+99'), 0);
      expect(compareVersions('1.7.0-dev.2+67', '1.7.0-dev.2+68'), 0);
      expect(compareVersions('1.7', '1.7.0'), 0);
      expect(compareVersions('1.9.0', '1.10.0'), lessThan(0));
    },
  );
}
