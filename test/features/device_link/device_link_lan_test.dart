import 'package:dingdong/features/device_link/data/device_link_lan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<Map<String, Object?>> reports(
    String local,
    String remote, {
    String type = 'host',
  }) => [
    {'id': 'transport', 'type': 'transport', 'selectedCandidatePairId': 'pair'},
    {
      'id': 'pair',
      'type': 'candidate-pair',
      'state': 'succeeded',
      'localCandidateId': 'local',
      'remoteCandidateId': 'remote',
    },
    {
      'id': 'local',
      'type': 'local-candidate',
      'candidateType': type,
      'address': local,
    },
    {
      'id': 'remote',
      'type': 'remote-candidate',
      'candidateType': 'host',
      'address': remote,
    },
  ];
  test('only the selected private host pair qualifies as LAN', () {
    expect(
      isVerifiedLanCandidatePair(reports('192.168.1.5', '192.168.1.6')),
      isTrue,
    );
    expect(isVerifiedLanCandidatePair(reports('10.0.0.5', '10.0.0.6')), isTrue);
    expect(isVerifiedLanCandidatePair(reports('fd00::5', 'fd00::6')), isTrue);
    expect(
      isVerifiedLanCandidatePair(reports('192.168.1.5', '127.0.0.1')),
      isTrue,
    );
    final vpn = reports('10.0.0.5', '10.0.0.6');
    vpn[2]['vpn'] = true;
    expect(isVerifiedLanCandidatePair(vpn), isFalse);
    for (final address in ['8.8.8.8', '100.64.0.1', 'abc.local', '']) {
      expect(
        isVerifiedLanCandidatePair(reports(address, '192.168.1.6')),
        isFalse,
      );
    }
    expect(
      isVerifiedLanCandidatePair(
        reports('192.168.1.5', '192.168.1.6', type: 'srflx'),
      ),
      isFalse,
    );
    expect(
      isVerifiedLanCandidatePair(
        reports('192.168.1.5', '192.168.1.6', type: 'relay'),
      ),
      isFalse,
    );
    expect(
      isVerifiedLanCandidatePair(
        reports('192.168.1.5', '192.168.1.6')..removeAt(0),
      ),
      isFalse,
    );
  });
}
