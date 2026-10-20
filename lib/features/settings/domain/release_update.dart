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
    this.notesByLanguage = const <String, List<String>>{},
    this.beta,
  });

  final String app;
  final String latestVersion;
  final String? latestBuild;
  final DateTime? publishedAt;
  final Uri website;
  final Uri releasePage;

  /// Legacy English-only notes kept for clients that require the array schema.
  final List<String> notes;
  final Map<String, List<String>> notesByLanguage;

  /// Newest published beta, offered only to people who opted into beta
  /// updates. Stable fields above always describe the latest stable release.
  final ReleaseMetadata? beta;

  List<String> notesFor(String languageCode) {
    final String normalized = languageCode.trim().toLowerCase();
    final String base = normalized.split(RegExp('[-_]')).first;
    final List<String>? localized =
        notesByLanguage[normalized] ?? notesByLanguage[base];
    if (localized != null && localized.isNotEmpty) {
      return localized;
    }
    if (notes.isNotEmpty) {
      return notes;
    }
    final List<String>? english = notesByLanguage['en'];
    if (english != null && english.isNotEmpty) {
      return english;
    }
    for (final List<String> fallback in notesByLanguage.values) {
      if (fallback.isNotEmpty) return fallback;
    }
    return const <String>[];
  }
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
    this.allowBeta = false,
  });

  final String currentVersion;
  final String currentBuild;
  final ReleaseMetadata? metadata;
  final bool isChecking;
  final String? errorMessage;
  final DateTime? checkedAt;

  /// Whether the user allowed updating to beta releases.
  final bool allowBeta;

  /// The release this installation should move to: the beta when the user
  /// allowed betas and it is newer than the latest stable release.
  ReleaseMetadata? get target {
    final ReleaseMetadata? stable = metadata;
    final ReleaseMetadata? beta = stable?.beta;
    if (!allowBeta || stable == null || beta == null) return stable;
    return compareVersions(stable.latestVersion, beta.latestVersion) < 0
        ? beta
        : stable;
  }

  bool get targetIsBeta =>
      metadata != null && target != null && !identical(target, metadata);

  String? get latestVersion => target?.latestVersion;
  List<String> get notes => target?.notes ?? const <String>[];
  List<String> notesFor(String languageCode) =>
      target?.notesFor(languageCode) ?? const <String>[];
  Uri get website => metadata?.website ?? defaultWebsiteUri;
  bool get isPreview => _releaseParts(currentVersion).$2.isNotEmpty;
  Uri get releasePage => isPreview && isUpdateAvailable != true
      ? Uri.https(
          'github.com',
          '/JevonsCode/DingDongBuddy/releases/tag/v${currentVersion.split('+').first}',
        )
      : target?.releasePage ?? defaultReleasePageUri;

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
    allowBeta: allowBeta,
  );

  ReleaseStatus resolved(ReleaseMetadata value, DateTime now) => ReleaseStatus(
    currentVersion: currentVersion,
    currentBuild: currentBuild,
    metadata: value,
    checkedAt: now.toUtc(),
    allowBeta: allowBeta,
  );

  ReleaseStatus failed(String message, DateTime now) => ReleaseStatus(
    currentVersion: currentVersion,
    currentBuild: currentBuild,
    metadata: metadata,
    errorMessage: message,
    checkedAt: now.toUtc(),
    allowBeta: allowBeta,
  );

  ReleaseStatus withAllowBeta(bool value) => ReleaseStatus(
    currentVersion: currentVersion,
    currentBuild: currentBuild,
    metadata: metadata,
    isChecking: isChecking,
    errorMessage: errorMessage,
    checkedAt: checkedAt,
    allowBeta: value,
  );
}

/// SemVer precedence, retaining support for v prefixes and short dotted versions.
int compareVersions(String left, String right) {
  final (List<int> leftParts, List<String> leftPreview) = _releaseParts(left);
  final (List<int> rightParts, List<String> rightPreview) = _releaseParts(
    right,
  );
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
  if (leftPreview.isEmpty || rightPreview.isEmpty) {
    return leftPreview.isEmpty == rightPreview.isEmpty
        ? 0
        : leftPreview.isEmpty
        ? 1
        : -1;
  }
  for (int i = 0; i < leftPreview.length && i < rightPreview.length; i++) {
    final String a = leftPreview[i];
    final String b = rightPreview[i];
    final BigInt? aNumber = RegExp(r'^\d+$').hasMatch(a)
        ? BigInt.parse(a)
        : null;
    final BigInt? bNumber = RegExp(r'^\d+$').hasMatch(b)
        ? BigInt.parse(b)
        : null;
    final int comparison;
    if (aNumber != null && bNumber != null) {
      comparison = aNumber.compareTo(bNumber);
    } else if (aNumber != null || bNumber != null) {
      comparison = aNumber != null ? -1 : 1;
    } else {
      comparison = a.compareTo(b);
    }
    if (comparison != 0) return comparison;
  }
  return leftPreview.length.compareTo(rightPreview.length);
}

(List<int>, List<String>) _releaseParts(String value) {
  final String version = value
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split('+')
      .first;
  final int separator = version.indexOf('-');
  final String core = separator < 0 ? version : version.substring(0, separator);
  final List<String> preview = separator < 0
      ? const <String>[]
      : version.substring(separator + 1).split('.');
  final List<int> parts = core
      .split('.')
      .map((String part) {
        final String digits = RegExp(r'^\d+').stringMatch(part) ?? '0';
        return int.parse(digits);
      })
      .toList(growable: false);
  return (parts, preview);
}

const String currentAppVersion = '1.8.0';
const String currentAppBuild = '70';
const Duration backgroundReleaseUpdateCheckInterval = Duration(hours: 7);
final Uri defaultWebsiteUri = Uri.parse(
  'https://xn--8ovp9s.xn--m8txu.com/DingDongBuddy/',
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
