/// Produces one comparison identity for common Git remote URL spellings.
///
/// For example, `git@github.com:acme/app.git` and
/// `https://github.com/acme/app` both become `github.com/acme/app`.
String canonicalRepositoryIdentity(String value) {
  final String candidate = value.trim();
  if (candidate.isEmpty) {
    return '';
  }

  String host = '';
  String repositoryPath = '';
  final RegExpMatch? scp = RegExp(
    r'^(?:[^@/\s]+@)?([^:/\s]+):(.+)$',
  ).firstMatch(candidate);
  if (scp != null && !candidate.contains('://')) {
    host = scp.group(1)!;
    repositoryPath = scp.group(2)!;
  } else {
    final Uri? uri = Uri.tryParse(candidate);
    if (uri != null && uri.hasScheme) {
      host = uri.host;
      repositoryPath = uri.path;
    } else {
      repositoryPath = candidate;
    }
  }

  host = host.toLowerCase();
  repositoryPath = repositoryPath
      .replaceAll(r'\', '/')
      .replaceFirst(RegExp(r'^/+'), '')
      .replaceFirst(RegExp(r'/+$'), '')
      .replaceFirst(RegExp(r'\.git$', caseSensitive: false), '')
      .toLowerCase();
  if (host.isEmpty) {
    return repositoryPath;
  }
  return repositoryPath.isEmpty ? host : '$host/$repositoryPath';
}
