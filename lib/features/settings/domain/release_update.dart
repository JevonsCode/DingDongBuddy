/// Release metadata published independently from the desktop binaries.
final class ReleaseMetadata {
  const ReleaseMetadata({
    required this.app,
    required this.latestVersion,
    required this.website,
    required this.releasePage,
    this.latestBuild,
    this.publishedAt,
    this.notes = const <String>[],
  });

  final String app;
  final String latestVersion;
  final String? latestBuild;
  final DateTime? publishedAt;
  final Uri website;
  final Uri releasePage;
  final List<String> notes;
}

/// Source used to resolve the latest available DingDong release.
abstract interface class ReleaseMetadataSource {
  Future<ReleaseMetadata> fetch();
}

/// Opens an external web page in the user's preferred browser.
abstract interface class ExternalLinkGateway {
  Future<void> open(Uri uri);
}

/// Immutable status displayed by the version settings section.
final class ReleaseStatus {
  const ReleaseStatus({
    this.currentVersion = currentAppVersion,
    this.currentBuild = currentAppBuild,
    this.metadata,
    this.isChecking = false,
    this.errorMessage,
    this.checkedAt,
  });

  final String currentVersion;
  final String currentBuild;
  final ReleaseMetadata? metadata;
  final bool isChecking;
  final String? errorMessage;
  final DateTime? checkedAt;

  String? get latestVersion => metadata?.latestVersion;
  List<String> get notes => metadata?.notes ?? const <String>[];
  Uri get website => metadata?.website ?? defaultWebsiteUri;
  Uri get releasePage => metadata?.releasePage ?? defaultReleasePageUri;

  bool? get isUpdateAvailable {
    final String? latest = latestVersion;
    return latest == null ? null : compareVersions(currentVersion, latest) < 0;
  }

  ReleaseStatus checking() => ReleaseStatus(
    currentVersion: currentVersion,
    currentBuild: currentBuild,
    metadata: metadata,
    isChecking: true,
    checkedAt: checkedAt,
  );

  ReleaseStatus resolved(ReleaseMetadata value, DateTime now) => ReleaseStatus(
    currentVersion: currentVersion,
    currentBuild: currentBuild,
    metadata: value,
    checkedAt: now.toUtc(),
  );

  ReleaseStatus failed(String message, DateTime now) => ReleaseStatus(
    currentVersion: currentVersion,
    currentBuild: currentBuild,
    metadata: metadata,
    errorMessage: message,
    checkedAt: now.toUtc(),
  );
}

/// Compares dotted versions while tolerating `v` prefixes and suffixes.
int compareVersions(String left, String right) {
  final List<int> leftParts = _versionParts(left);
  final List<int> rightParts = _versionParts(right);
  final int length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;
  for (int index = 0; index < length; index += 1) {
    final int leftValue = index < leftParts.length ? leftParts[index] : 0;
    final int rightValue = index < rightParts.length ? rightParts[index] : 0;
    final int comparison = leftValue.compareTo(rightValue);
    if (comparison != 0) {
      return comparison;
    }
  }
  return 0;
}

List<int> _versionParts(String value) {
  return value
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('.')
      .map((String part) {
        final String digits = RegExp(r'^\d+').stringMatch(part) ?? '0';
        return int.parse(digits);
      })
      .toList(growable: false);
}

const String currentAppVersion = '0.7.7';
const String currentAppBuild = '14';
final Uri defaultWebsiteUri = Uri.parse(
  'https://xn--8ovp9s.xn--m8txu.com/DingDong/',
);
final Uri defaultReleasePageUri = Uri.parse(
  'https://github.com/JevonsCode/DingDongBuddy/releases/latest',
);
final Uri defaultBugReportUri = Uri.parse(
  'https://github.com/JevonsCode/DingDongBuddy/issues/new?template=bug-report.yml',
);
final Uri defaultFeatureRequestUri = Uri.parse(
  'https://github.com/JevonsCode/DingDongBuddy/issues/new?template=feature-request.yml',
);
