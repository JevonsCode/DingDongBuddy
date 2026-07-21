import 'package:dingdong/features/settings/domain/application_updater.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('native update status clamps progress and omits blank fields', () {
    final ApplicationUpdateStatus status =
        ApplicationUpdateStatus.fromJson(<Object?, Object?>{
          'phase': 'downloading',
          'progress': 1.4,
          'targetVersion': ' 0.8.0 ',
          'message': '   ',
        });

    expect(status.phase, ApplicationUpdatePhase.downloading);
    expect(status.progress, 1);
    expect(status.targetVersion, '0.8.0');
    expect(status.message, isNull);
    expect(status.isBusy, isTrue);
    expect(status.toJson(), <String, Object?>{
      'phase': 'downloading',
      'progress': 1.0,
      'targetVersion': '0.8.0',
    });
  });

  test('unknown native phase fails closed', () {
    final ApplicationUpdateStatus status = ApplicationUpdateStatus.fromJson(
      <Object?, Object?>{'phase': 'surprise'},
    );

    expect(status.phase, ApplicationUpdatePhase.failed);
    expect(status.isBusy, isFalse);
  });
}
