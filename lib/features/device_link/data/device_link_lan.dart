import 'dart:io';

/// Fail closed: an RTC channel alone can also be a cross-internet connection.
bool isVerifiedLanCandidatePair(Iterable<Map<String, Object?>> reports) {
  final byId = {for (final report in reports) report['id']: report};
  for (final transport in reports.where((r) => r['type'] == 'transport')) {
    final pair = byId[transport['selectedCandidatePairId']];
    if (pair == null || pair['state'] != 'succeeded') continue;
    final local = byId[pair['localCandidateId']];
    final remote = byId[pair['remoteCandidateId']];
    if (local == null || remote == null) continue;
    if (local['vpn'] == true || local['networkType'] == 'vpn') continue;
    if (local['candidateType'] != 'host' || remote['candidateType'] != 'host') {
      continue;
    }
    if (_privateAddress(local['address'] ?? local['ip']) &&
        _privateAddress(remote['address'] ?? remote['ip'])) {
      return true;
    }
  }
  return false;
}

bool _privateAddress(Object? value) {
  if (value is! String) return false;
  final address = InternetAddress.tryParse(value.split('%').first);
  if (address == null) return false;
  if (address.isLoopback) return true;
  final bytes = address.rawAddress;
  if (bytes.length == 4) {
    return bytes[0] == 10 ||
        (bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31) ||
        (bytes[0] == 192 && bytes[1] == 168) ||
        (bytes[0] == 169 && bytes[1] == 254);
  }
  return (bytes[0] & 0xfe) == 0xfc ||
      (bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80);
}
