import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;

const String skillDeploymentReceiptFileName = '.dingdong-skill-deployment.json';
const String legacySkillDeploymentMarkerFileName = '.dingdong-managed';

enum SkillDeploymentDesiredState { present, absent }

enum SkillDeploymentOutcome {
  installed,
  updated,
  unchanged,
  removed,
  absent,
  legacyOwnershipRequired,
  ownershipConflict,
  recovered,
}

enum SkillDeploymentPresence { confirmedAbsent, possiblyPresent }

final class SkillDeploymentPlan {
  SkillDeploymentPlan.install({
    required String resourceId,
    required String agentId,
    required String workspace,
    required Directory sourceDirectory,
    required Directory destinationDirectory,
    String? expectedPackageDigest,
  }) : this._(
         resourceId: resourceId,
         agentId: agentId,
         workspace: workspace,
         sourceDirectory: sourceDirectory,
         destinationDirectory: destinationDirectory,
         expectedPackageDigest: expectedPackageDigest,
         desiredState: SkillDeploymentDesiredState.present,
       );

  SkillDeploymentPlan.remove({
    required String resourceId,
    required String agentId,
    required String workspace,
    required Directory destinationDirectory,
  }) : this._(
         resourceId: resourceId,
         agentId: agentId,
         workspace: workspace,
         destinationDirectory: destinationDirectory,
         desiredState: SkillDeploymentDesiredState.absent,
       );

  SkillDeploymentPlan._({
    required this.resourceId,
    required this.agentId,
    required this.workspace,
    required this.destinationDirectory,
    required this.desiredState,
    this.sourceDirectory,
    this.expectedPackageDigest,
  });

  final String resourceId;
  final String agentId;
  final String workspace;
  final Directory? sourceDirectory;
  final Directory destinationDirectory;
  final String? expectedPackageDigest;
  final SkillDeploymentDesiredState desiredState;

  String get destinationPath =>
      path.normalize(destinationDirectory.absolute.path);

  String get destinationKey => _stableKey(<String>[
    'destination-v1',
    _destinationIdentity(destinationPath),
  ]);

  String get deploymentKey => _stableKey(<String>[
    'deployment-v1',
    resourceId,
    agentId,
    workspace,
    destinationKey,
  ]);
}

String _destinationIdentity(String destinationPath) {
  final String normalized = canonicalSkillDeploymentPath(destinationPath);
  return Platform.isMacOS ? normalized.toLowerCase() : normalized;
}

String canonicalSkillDeploymentPath(String candidatePath) {
  final List<String> missingSegments = <String>[];
  var cursor = Directory(path.normalize(path.absolute(candidatePath)));
  while (FileSystemEntity.typeSync(cursor.path, followLinks: true) ==
      FileSystemEntityType.notFound) {
    final String parent = path.dirname(cursor.path);
    if (path.equals(parent, cursor.path)) {
      break;
    }
    missingSegments.add(path.basename(cursor.path));
    cursor = Directory(parent);
  }
  String resolved;
  try {
    resolved = cursor.resolveSymbolicLinksSync();
  } on FileSystemException {
    resolved = path.normalize(cursor.absolute.path);
  }
  for (final String segment in missingSegments.reversed) {
    resolved = path.join(resolved, segment);
  }
  return path.normalize(path.absolute(resolved));
}

final class SkillDeploymentResult {
  const SkillDeploymentResult({
    required this.outcome,
    required this.deploymentKey,
    required this.destinationKey,
  });

  final SkillDeploymentOutcome outcome;
  final String deploymentKey;
  final String destinationKey;
}

String _stableKey(List<String> components) {
  final String encoded = base64UrlEncode(
    utf8.encode(jsonEncode(components)),
  ).replaceAll('=', '');
  return 'dingdong:$encoded';
}
