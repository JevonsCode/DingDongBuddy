import 'dart:convert';

import 'package:dingdong/features/device_link/ui/device_link_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('device file names remove both path separator styles', () {
    expect(
      sanitizeDeviceLinkFileName(r'C:\Users\phone\report.txt'),
      'report.txt',
    );
    expect(sanitizeDeviceLinkFileName('../../report.txt'), 'report.txt');
  });

  test('Windows reserved characters and trailing dots are removed', () {
    expect(
      sanitizeDeviceLinkFileName('  report<draft>:v1?.txt...  '),
      'report_draft__v1_.txt',
    );
    expect(sanitizeDeviceLinkFileName('name. . '), 'name');
    expect(sanitizeDeviceLinkFileName('...'), '共享文件');
  });

  test('Windows device names are prefixed even when they have extensions', () {
    for (final String reserved in <String>[
      'CON',
      'con.txt',
      'PRN.md',
      'AUX',
      'NUL.bin',
      r'CLOCK$',
      r'CONIN$',
      r'CONOUT$.txt',
      'CON .txt',
      'COM1.log',
      'com9',
      'COM¹.txt',
      'LPT1.txt',
      'lpt9',
      'LPT³.log',
    ]) {
      expect(
        sanitizeDeviceLinkFileName(reserved),
        startsWith('_'),
        reason: reserved,
      );
    }
    expect(sanitizeDeviceLinkFileName('COM10.txt'), 'COM10.txt');
    expect(sanitizeDeviceLinkFileName('LPT10.txt'), 'LPT10.txt');
  });

  test('long Unicode names are bounded without splitting their extension', () {
    final String sanitized = sanitizeDeviceLinkFileName(
      '${List<String>.filled(100, '报告').join()}.txt',
    );

    expect(utf8.encode(sanitized).length, lessThanOrEqualTo(180));
    expect(sanitized, endsWith('.txt'));
    expect(utf8.decode(utf8.encode(sanitized)), sanitized);
  });
}
